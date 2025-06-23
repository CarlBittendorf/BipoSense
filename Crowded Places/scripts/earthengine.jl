include("../startup.jl")

using CSV, PyCall

@chain d"BipoSense Locations" begin
    groupby([:Latitude, :Longitude])
    combine(All() .=> first)

    select([:Latitude, :Longitude])

    CSV.write("data/Locations.csv", _)
end

ee = pyimport("ee")

ee.Initialize(project = "biposense")

points = ee.FeatureCollection("projects/biposense/assets/locations")

# add a 100m buffer radius to each point
balls = points.map(x -> x.buffer(100))

function mask_clouds(image)
    qa = image.select("QA60")
    mask = qa.bitwiseAnd(1 << 10).eq(0).And(qa.bitwiseAnd(1 << 11).eq(0))

    return image.updateMask(mask).divide(10000)
end

stats = @chain "COPERNICUS/S2_SR_HARMONIZED" begin
    ee.ImageCollection
    _.filterDate("2022-04-01", "2022-09-30")
    _.filter(ee.Filter.lt("CLOUDY_PIXEL_PERCENTAGE", 20))
    _.map(mask_clouds)
    _.median()
    _.normalizedDifference(["B8", "B4"])
    _.clip(balls)
    _.reduceRegions(
        collection = balls,
        reducer = ee.Reducer.mean(),
        scale = 10,
        crs = "EPSG:4326",
        tileScale = 3
    )
end

task = ee.batch.Export.table.toDrive(
    collection = stats,
    description = "Mean NDVI",
    fileFormat = "CSV",
    selectors = ["mean"]
)

task.start()

stats = @chain "COPERNICUS/S2_SR_HARMONIZED" begin
    ee.ImageCollection
    _.filterDate("2022-04-01", "2022-09-30")
    _.filter(ee.Filter.lt("CLOUDY_PIXEL_PERCENTAGE", 20))
    _.map(mask_clouds)
    _.median()
    _.normalizedDifference(["B8", "B4"])
    _.gt(0.5)
    _.multiply(ee.Image.pixelArea())
    _.clip(balls)
    _.gt(0.5)
    _.multiply(ee.Image.pixelArea())
    _.reduceRegions(
        collection = balls,
        reducer = ee.Reducer.sum(),
        scale = 10,
        crs = "EPSG:4326",
        tileScale = 3
    )
end

task = ee.batch.Export.table.toDrive(
    collection = stats,
    description = "Green Area",
    fileFormat = "CSV",
    selectors = ["sum"]
)

task.start()