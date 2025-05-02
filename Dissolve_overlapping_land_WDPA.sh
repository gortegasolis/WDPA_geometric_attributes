#!/bin/bash

# Split overlapping polygons into non-overlapping parts
saga_cmd shapes_polygons "Polygon Self-Intersection" \
  -POLYGONS "WDPA_poly_Jan2025.shp" \
  -INTERSECT "tmp_intersected.shp" \
  -ID ""  # No ID field, so no attributes are carried over

# Dissolve overlaps while keeping non-overlapping polygons separate
saga_cmd shapes_polygons "Polygon Dissolve" \
  -POLYGONS "tmp_intersected.shp" \
  -DISSOLVED "dissolved_output.shp" \
  -BND_KEEP 0 \
  -MIN_AREA 0.000001 \
  -FIELD_1 "" \
  -MERGE_ATTRIB 0  # Ensures no attribute aggregation or retention


