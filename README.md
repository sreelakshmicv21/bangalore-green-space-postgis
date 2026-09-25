# Bangalore Green Space Gap: Park Coverage by Ward

A PostGIS spatial analysis mapping park coverage across Bangalore's 225 BBMP wards, built to identify green-space-rich and green-space-poor areas of the city.

## Overview

This project overlays real park data from OpenStreetMap onto official BBMP ward boundaries to calculate what percentage of each ward's area is covered by parks. The result highlights a stark disparity: a small number of wards have significant green cover, while the majority have very little to none.

## Key findings

- **Vishveshwara Puram** has the highest park coverage at **31.17%**
- Most wards fall under **3% coverage**
- Dozens of wards show **0% mapped coverage** — though this likely reflects gaps in OpenStreetMap tagging (especially in older, denser core-city wards like Malleswaram and Chickpete) rather than a true absence of green space
- Total mapped park area across the city: **~14.47 km²**

## Data sources

| Dataset | Source | Format |
|---|---|---|
| Parks | OpenStreetMap (via [Overpass Turbo](https://overpass-turbo.eu/)) | GeoJSON |
| Ward boundaries | [OpenCity — BBMP Ward Information](https://data.opencity.in/dataset/bbmp-ward-information) (2023 delimitation, 225 wards) | KML |

Both sources are free and openly licensed.

## Tech stack

- **PostgreSQL + PostGIS** — spatial database and analysis
- **QGIS** — data import, styling, and map export
- **Overpass API** — OSM data extraction

## Methodology

1. Queried OpenStreetMap for all `leisure=park` features within Bangalore's bounding box
2. Loaded park polygons and BBMP ward polygons into PostGIS
3. For each ward, used `ST_Intersects` and `ST_Intersection` to find and measure the exact park area overlapping that ward
4. Cast geometries to `::geography` for accurate real-world measurements in square meters/km² (rather than the degree-based units of raw geometry math)
5. Calculated coverage as `(park area in ward / total ward area) * 100`
6. Stored results back into the database and visualized as a choropleth map in QGIS

See [`queries.sql`](queries.sql) for the full, commented SQL used at every stage.

## Repository contents

- `queries.sql` — all SQL used, from database setup through final analysis
- `map.png` — final exported choropleth map
- `README.md` — this file

## Limitations

- Coverage figures are based on OpenStreetMap's park tagging, which is community-maintained and not exhaustive — some real parks, especially in older parts of the city, may be missing or incompletely mapped
- "Park" here follows OSM's `leisure=park` tag, which may not perfectly match every locally understood definition of a park or green space
- Ward boundaries reflect the 2023 BBMP delimitation (225 wards) and may not match other commonly cited ward counts (198 or 243)

## Possible extensions

- Add lakes/water bodies for a combined "green-blue infrastructure" score
- Incorporate ward population data (already present in the source dataset) to calculate green space **per capita**, not just per unit area
- Compare against a second city for a benchmark analysis
