#!/bin/bash

# Source environment variables
source /home/ortega/Github/WDPA_geometric_attributes/.env

# Export the necessary variables before running parallel
export PGPASSWORD

# Change to the working directory
if [ -d /home/ortega/Github/WDPA_geometric_attributes/edge_bck ]; then
  mv /home/ortega/Github/WDPA_geometric_attributes/edge_bck /home/ortega/Github/WDPA_geometric_attributes/edge_bck_old_$(date +%Y%m%d_%H%M%S)
fi
mkdir -p /home/ortega/Github/WDPA_geometric_attributes/edge_bck
cd /home/ortega/Github/WDPA_geometric_attributes/edge_bck

# Step 1: Export distinct wdpaid list as CSV
ogr2ogr -f "CSV" wdpaid.csv \
  PG:"dbname='World_Protected_Areas' host='localhost' port='5432' user='atlasadmin' password='$PGPASSWORD'" \
  -sql "SELECT DISTINCT wdpaid FROM wdpaid_fid_dissolved_overlaps"

# Remove CSV header
tail -n +2 wdpaid.csv > wdpaid_tmp.csv && mv wdpaid_tmp.csv wdpaid.csv

# Step 2: Export one GeoPackage per wdpaid in parallel (50 jobs max)
cat wdpaid.csv | xargs -I {} -P 50 --verbose \
  ogr2ogr -f GPKG -a_srs "EPSG:4326" wdpa_wdpaid_{}.gpkg \
  PG:"dbname='World_Protected_Areas' host='localhost' port='5432' user='atlasadmin' password='$PGPASSWORD'" \
  -sql "SELECT wdpaid, geometry FROM wdpaid_fid_dissolved_overlaps WHERE wdpaid = {}"

# Step 3: Run the R buffering script in parallel on each GeoPackage with a timeout of 900 seconds (100 jobs max)
parallel -a wdpaid.csv -j 50 --joblog parallel_buffer.log --timeout 900 Rscript /home/ortega/Github/WDPA_geometric_attributes/scripts/edge_script.R {}

# Step 4: Add geometric attributes in parallel to each GeoPackage with a timeout of 900 seconds (50 jobs max)
parallel -a wdpaid.csv -j 50 --joblog parallel_add_attributes.log --timeout 900 Rscript /home/ortega/Github/WDPA_geometric_attributes/scripts/add_geometric_attributes.R {}

# Step 5: Get elevation
parallel -a wdpaid.csv -j 10 --joblog parallel_add_attributes.log --timeout 900 --memfree 102400M Rscript /home/ortega/Github/WDPA_geometric_attributes/scripts/extract_elevation.R {}

# Step 6: Get climate
parallel -a wdpaid.csv -j 50 --joblog parallel_add_attributes.log --timeout 900 --memfree 102400M Rscript /home/ortega/Github/WDPA_geometric_attributes/scripts/climate.R {}

# Step 7: Join the layers