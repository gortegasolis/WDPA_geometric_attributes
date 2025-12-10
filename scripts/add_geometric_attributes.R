library(pacman)
p_load(terra, sf, geosphere, tidyterra)

args <- commandArgs(trailingOnly = TRUE)
wdpaid <- args[1]

fn <- paste0('wdpa_wdpaid_', wdpaid, '.gpkg') # Input geopackage file
lname <- 'geometric_attributes' # Output layer name
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

# Intermediate objects
b <- ext(v)
pt1 <- vect(cbind(b$xmin, b$ymin), crs = crs(v))
pt2 <- vect(cbind(b$xmax, b$ymin), crs = crs(v))
pt3 <- vect(cbind(b$xmin, b$ymax), crs = crs(v))
pt4 <- vect(cbind(b$xmax, b$ymax), crs = crs(v))
hull <- hull(v, type = "convex")
centroid <- centroids(v)
mincircle <- hull(v, type = "circle")
minRectangle <- hull(v, type = "rectangle")
dims_rect <- crds(minRectangle)
dims_rect <- vect(dims_rect, crs = crs(v))
inh <- fillHoles(v, inverse = TRUE)
pols <- disagg(v)
coords <- crds(hull)

# Find the pair of most distant points
points_hull <- vect(coords, crs = crs(v))
dists_hull <- distance(points_hull, method = "geo")/1000  # Convert to kilometers
dists_hull <- as.matrix(dists_hull)
max_dist_idx <- which(dists_hull == max(dists_hull), arr.ind = TRUE)[1, ]
start_idx <- max_dist_idx[1]
end_idx <- max_dist_idx[2]
subset_hull <- points_hull[c(start_idx, end_idx), ]
# Ensure start_ll is the southernmost point
coords_subset <- crds(subset_hull)
order_idx <- order(coords_subset[, 2])  # Order by latitude (y coordinate)
start_ll <- subset_hull[order_idx[1], ]  # Point with minimum latitude
end_ll <- subset_hull[order_idx[2], ]    # Point with maximum latitude

# Geometric metrics
v$area <- expanse(v, unit = "m")/1000000 # Total area in square kilometers
v$perimeter <- perim(v)/1000 # Total perimeter length in kilometers
v$compactness <- (4 * pi * v$area) / (v$perimeter^2) # Polsby-Popper compactness (1 = perfect circle)
v$reock <- v$area / (expanse(mincircle, unit = "m")/1000000) # Reock compactness (area / minimum enclosing circle area)
v$elongation_rectangle <- {
    dists_rect <- distance(dims_rect, method = "geo")/1000  # Convert to kilometers
    dists_rect <- sort(dists_rect, decreasing = TRUE)
    major <- mean(dists_rect[1:2])
    dists_rect <- sort(dists_rect, decreasing = FALSE)
    minor <- mean(dists_rect[1:2])
    major / minor # Elongation ratio based on enclosing rectangle dimensions
}
v$num_holes <- length(inh) # Number of holes (interior rings) in the polygon
v$hole_area <- sum(expanse(inh))/1000000 # Total area of holes in square kilometers
v$hole_area_pct <- (v$hole_area / v$area) * 100 # Percentage of total area occupied by holes
v$num_polygons <- length(pols) # Number of separate polygon parts (multi-part count)
v$ew_length <- {
    mean(distance(pt1, pt2, method = "geo"), distance(pt3, pt4, method = "geo"))/1000 # Average east-west extent in kilometers
}
v$ns_length <- {
    mean(distance(pt1, pt3, method = "geo"), distance(pt2, pt4, method = "geo"))/1000 # Average north-south extent in kilometers
}
v$maxlength <- distance(start_ll, end_ll, method = "geo")/1000 # Maximum distance across convex hull in kilometers
v$bearing <- bearing(start_ll, end_ll) # Geographic bearing of maximum length line in degrees
v$northerness <- cos(pi * (v$bearing / 180)) # Northerness component of bearing (-1 to 1)
v$fractaldimension <- 2 * (log(v$perimeter) / log(v$area)) # Fractal dimension (complexity measure, typically 1-2)
v$sinuosity <- v$perimeter / v$maxlength # Sinuosity (perimeter to maximum length ratio)
v$shape_index <- v$perimeter / (2 * sqrt(pi * v$area)) # Shape index (deviation from circular shape)
v$circularity_ratio <- (4 * v$area) / (pi * v$maxlength^2) # Circularity based on maximum length
v$decimallongitude <- crds(centroid)[, 1] # Centroid longitude in decimal degrees
v$decimallatitude <- crds(centroid)[, 2] # Centroid latitude in decimal degrees

v <- st_as_sf(v)
v$wdpaid <- wdpaid
sf::st_write(v, dsn = fn, layer = lname, delete_layer = TRUE)
