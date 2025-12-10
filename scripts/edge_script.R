library(pacman)
p_load(terra, sf, tidyterra)

args <- commandArgs(trailingOnly = TRUE)
wdpaid <- args[1]

fn <- paste0('wdpa_wdpaid_', wdpaid, '.gpkg') # Input geopackage file
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

for (buff in c(-100, -500, -1000, -2000)) {
    v_neg_buffer <- buffer(v, width = buff)
    empty_idx <- which(is.empty(v_neg_buffer))
    if (length(empty_idx) > 0) {
        for (i in empty_idx) {
            v_neg_buffer <- centroids(v)
        }
    }
    v_neg_buffer$area <- expanse(v_neg_buffer, unit = "m")/1000000  # Convert to square kilometers
    
    lname <- paste0('buffer_neg_', abs(buff), 'm')
    v_neg_buffer <- sf::st_as_sf(v_neg_buffer)
    v_neg_buffer$wdpaid <- wdpaid
    sf::st_write(v_neg_buffer, dsn = fn, layer = lname, delete_layer = TRUE)
}
