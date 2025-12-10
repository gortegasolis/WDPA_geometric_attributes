## Predictors and responses
predictors <- c(
    "area",
    "northerness",
    "elongation_rectangle",
    "num_polygons",
    "fractaldimension",
    #"ns_length",
    "reock",
    "edge_prop",
    "continent",
    "decimallongitude",
    "decimallatitude"
)

responses <- c(
    "cv_ndvi",
    "elevation_cv",
    "n_climates",
    "shannon_climates",
    #"simpson_evenness_climate",
    "n_landcover",
    #"simpson_evenness_landcover",
    "shannon_landcover"
)

print(paste("predictors: ", paste(predictors, collapse = ", ")  ))
print(paste("responses: ", paste(responses, collapse = ", ")  ))