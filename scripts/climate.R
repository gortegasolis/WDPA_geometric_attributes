library(pacman)
p_load(terra, sf, geosphere, tidyterra)

args <- commandArgs(trailingOnly = TRUE)
wdpaid <- args[1]

fn <- paste0('wdpa_wdpaid_', wdpaid, '.gpkg') # Input geopackage file
lname <- 'climate' # Output layer name
v <- vect(fn, layer = "sql_statement")
# Check if CRS is valid and reproject to WGS84 if needed
if (is.na(crs(v)) || crs(v) == "") {
    stop("Vector has no CRS defined")
}
if (crs(v, describe = TRUE)$code != "4326") {
    v <- project(v, "epsg:4326") # Ensure geometries are in WGS84
}
v <- filter(v, wdpaid == wdpaid) # Filter to specific WDPA ID
v <- union(v) # Dissolve to single part if multipart
v$fixed <- ""

is_valid <- is.valid(v)
if (!is_valid) {
    v <- makeValid(v)
    v$fixed <- "makeValid"
}

is_valid <- is.valid(v)
if (!is_valid) {
    v <- buffer(v, width = 0)
    v$fixed <- "buffer_0"
}

is_valid <- is.valid(v)
if (!is_valid) {
    v <- union(v)
    v$fixed <- "union"
}

is_valid <- is.valid(v)
if (!is_valid) {
    v$fixed <- "invalid"
}

# Extract elevation data
climate_raster <- terra::rast("/home/ortega/Rasters/Koppen_climate/1991_2020/koppen_geiger_0p00833333.tif")
climate_data <- terra::extract(climate_raster, v, ID = FALSE)
climate_summary <- table(climate_data[[1]]) %>% as.data.frame() %>%
pivot_wider(names_from = Var1, values_from = Freq, values_fill = 0)
v <- cbind(v, climate_summary)
v$wdpaid <- wdpaid

v <- st_as_sf(v)
v$wdpaid <- wdpaid
sf::st_write(v, dsn = fn, layer = lname, delete_layer = TRUE)