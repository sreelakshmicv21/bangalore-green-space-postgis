-- ============================================================
-- Bangalore Green Space Gap: Park Coverage by Ward
-- PostGIS spatial analysis of park coverage across 225 BBMP wards
-- ============================================================

-- ------------------------------------------------------------
-- 1. DATABASE & EXTENSION SETUP
-- ------------------------------------------------------------

CREATE DATABASE bangalore_greenblue;

CREATE EXTENSION postgis;


-- ------------------------------------------------------------
-- 2. LOAD DATA
-- ------------------------------------------------------------
-- Parks and ward boundaries were loaded via QGIS (Overpass API
-- GeoJSON export for parks, OpenCity KML for wards), imported
-- using QGIS DB Manager / "Save Features As -> PostgreSQL".
--
-- Resulting tables:
--   parks_osm  - 1,794 park polygons from OpenStreetMap
--   wards      - 225 BBMP ward polygons (2023 delimitation)
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 3. POST-IMPORT CLEANUP
-- ------------------------------------------------------------
-- QGIS/GDAL default the geometry column to "wkb_geometry".
-- Renamed for clarity and consistency across tables.

ALTER TABLE parks_osm RENAME COLUMN wkb_geometry TO geom;
ALTER TABLE wards RENAME COLUMN wkb_geometry TO geom;


-- ------------------------------------------------------------
-- 4. DATA VALIDATION
-- ------------------------------------------------------------

-- Confirm coordinate reference system (expect 4326 / WGS84)
SELECT ST_SRID(geom) FROM parks_osm LIMIT 1;
SELECT ST_SRID(geom) FROM wards LIMIT 1;

-- Sample rows
SELECT ogc_fid, name, geom FROM parks_osm LIMIT 5;

-- Row counts
SELECT COUNT(*) FROM parks_osm;   -- 1,794
SELECT COUNT(*) FROM wards;       -- 225

-- Named vs unnamed parks (OSM data quality check)
SELECT
    COUNT(*) FILTER (WHERE name IS NOT NULL) AS named,
    COUNT(*) FILTER (WHERE name IS NULL) AS unnamed
FROM parks_osm;

-- Total mapped park area across the city (sanity check stat)
SELECT ROUND(
    (ST_Area(ST_Union(geom)::geography) / 1000000)::numeric, 2
) AS total_park_area_km2
FROM parks_osm;
-- Result: 14.47 km2


-- ------------------------------------------------------------
-- 5. CORE ANALYSIS: PARK COVERAGE PER WARD
-- ------------------------------------------------------------
-- For each ward, find every park that intersects it, compute
-- only the overlapping area (not the whole park), convert to
-- km2 using geography casting for accurate real-world units,
-- and express as a percentage of the ward's total area.

SELECT
    w.name_en AS ward_name,
    ROUND((ST_Area(w.geom::geography) / 1000000)::numeric, 3)
        AS ward_area_km2,
    ROUND((ST_Area(ST_Union(ST_Intersection(w.geom, p.geom))::geography)
        / 1000000)::numeric, 4) AS park_area_km2,
    ROUND((ST_Area(ST_Union(ST_Intersection(w.geom, p.geom))::geography)
        / ST_Area(w.geom::geography) * 100)::numeric, 2)
        AS park_coverage_pct
FROM wards w
LEFT JOIN parks_osm p ON ST_Intersects(w.geom, p.geom)
GROUP BY w.ogc_fid, w.name_en, w.geom
ORDER BY park_coverage_pct DESC NULLS LAST;


-- ------------------------------------------------------------
-- 6. PERSIST RESULTS FOR MAPPING
-- ------------------------------------------------------------
-- Store the coverage percentage directly on the wards table so
-- QGIS can symbolize by it. Two-step update: default every ward
-- to 0, then overwrite only wards that actually intersect a park
-- (a plain JOIN would leave zero-coverage wards as NULL, which
-- sorts before real values in a DESC query).

ALTER TABLE wards ADD COLUMN park_coverage_pct NUMERIC;

UPDATE wards SET park_coverage_pct = 0;

UPDATE wards w
SET park_coverage_pct = sub.pct
FROM (
    SELECT
        w2.ogc_fid,
        ROUND((ST_Area(ST_Union(ST_Intersection(w2.geom, p.geom))::geography)
            / ST_Area(w2.geom::geography) * 100)::numeric, 2) AS pct
    FROM wards w2
    JOIN parks_osm p ON ST_Intersects(w2.geom, p.geom)
    GROUP BY w2.ogc_fid
) sub
WHERE w.ogc_fid = sub.ogc_fid;

-- Verify
SELECT name_en, park_coverage_pct
FROM wards
ORDER BY park_coverage_pct DESC
LIMIT 10;
