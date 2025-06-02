include("../startup.jl")

using CSV

df = d"BipoSense Crowded Places"

CSV.write(joinpath("data", "BipoSense Crowded Places.csv"), df)