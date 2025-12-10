pacman::p_load(tidyverse, sf, data.table, tidytable, parallel)

# Step 1: Retain only "cluster" field
system("rm -f /tmp/WDPA_clustered_clusteronly.gpkg")
system("ogr2ogr -f 'GPKG' /tmp/WDPA_clustered_clusteronly.gpkg '/home/ortega/Documents/GitHub/Articles/WDPA_geometric_attributes/WDPA_clustered.gpkg' -select cluster")

clusterids <- st_read("/tmp/WDPA_clustered_clusteronly.gpkg") %>%
  st_drop_geometry() %>%
  as.data.table() %>%
  pull(cluster) %>%
  unique()

# Step 2: Dissolve with disjoint handling
mclapply(clusterids, function(clusterid) {
  system(str_glue("ogr2ogr -f 'KML' '/tmp/dissolved_wdpa_files/WDPA_dissolved_cluster{clusterid}.kml' /tmp/WDPA_clustered_clusteronly.gpkg -dialect sqlite -sql 'SELECT ST_Union(geom) AS geom, cluster FROM WDPA_clustered WHERE cluster == {clusterid}' -explodecollections"))
}, mc.cores = 100)

# Step 3: Merge KML files

kml_files <- list.files("/tmp/dissolved_wdpa_files/", pattern = "WDPA_dissolved_cluster.*\\.kml$", full.names = TRUE)

system("rm -f /home/ortega/Documents/GitHub/Articles/WDPA_geometric_attributes/WDPA_dissolved.gpkg")

# Append the KML files to the GeoPackage
for (kml_file in kml_files) {
  system(str_glue(
    "ogr2ogr -f 'GPKG' ",
    "/home/ortega/Documents/GitHub/Articles/WDPA_geometric_attributes/WDPA_dissolved.gpkg ",
    "{kml_file} -update -append -nln dissolved"
  ))
}

# Upload the geopackage to Postgresql database
pass <- Sys.getenv("PGPASSWORD")
system(str_glue("ogr2ogr -f 'PostgreSQL' \"PG:host=localhost user=atlasadmin dbname=World_Protected_Areas password={pass}\" /home/ortega/Documents/GitHub/Articles/WDPA_geometric_attributes/WDPA_dissolved.gpkg -nln wdpa_dissolved -lco GEOMETRY_NAME=geom -lco OVERWRITE=YES"))

# Transform the GeoPackage into a CSV file
system("rm -f /home/ortega/Documents/GitHub/Articles/WDPA_geometric_attributes/WDPA_dissolved.csv")
# Transform the GeoPackage into a CSV file
system("ogr2ogr -f 'CSV' -lco GEOMETRY=AS_WKT -sql 'SELECT ROWID AS uniqueid, * FROM dissolved' /home/ortega/Documents/GitHub/Articles/WDPA_geometric_attributes/WDPA_dissolved.csv /home/ortega/Documents/GitHub/Articles/WDPA_geometric_attributes/WDPA_dissolved.gpkg dissolved")

# Create a bucket named earthengine_imports
system("gcloud storage buckets create gs://earthengine_imports")

# Upload the resulting CSV to Google Cloud Storage
system("gcloud storage cp /home/ortega/Documents/GitHub/Articles/WDPA_geometric_attributes/WDPA_dissolved.csv gs://earthengine_imports/WDPA_dissolved.csv")

# Import the CSV into Google Earth Engine as an asset with a limit on the number of vertices
system("earthengine upload table --asset_id=projects/gortega-research/assets/WDPA_dissolved --max_vertices=1000000 gs://earthengine_imports/WDPA_dissolved.csv")
