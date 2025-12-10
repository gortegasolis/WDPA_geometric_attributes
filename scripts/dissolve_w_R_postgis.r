# Load packages
pacman::p_load(DBI, RPostgres, tidyverse, dbplyr, parallel, igraph, future.apply)

# Source your connection script
source("con.r")

# Data preparation: extract and clean intersecting_ids as a list of integer vectors
clusters <- tbl(con, from = I("admin.matview_intersections_2")) %>%
  collect() %>%
  mutate(intersecting_ids = intersecting_ids %>%
           str_remove_all("[{}]") %>%
           str_split(",") %>%
           map(~ as.numeric(.x))) %>%
  pull(intersecting_ids) %>%
  unique() %>%
  .[order(map_int(., length), decreasing = TRUE)]

# Create table to store results
dbExecute(con, "CREATE TABLE IF NOT EXISTS WDPA_clean_subset (
  id SERIAL PRIMARY KEY,
  geometry GEOMETRY(Geometry, 4326)
);")

# Empty table if it already has data
dbExecute(con, "TRUNCATE TABLE WDPA_clean_subset;")

# Use a for loop to insert data sequentially
for (id in clusters) {
  id <- paste0(id, collapse = ",")
  print(id)
  res <- dbSendQuery(
    con,
    str_glue(
      "INSERT INTO WDPA_clean_subset (geometry) SELECT ST_Union(geometry)::GEOMETRY(Geometry, 4326) FROM admin.matview_ranked_polygons_1 WHERE wdpaid IN ({id});"
    )
  )
  
  # Poll until query completes
  while (!dbHasCompleted(res)) {
    Sys.sleep(0.1) # Reduce CPU load during polling
  }
  dbClearResult(res)
}
