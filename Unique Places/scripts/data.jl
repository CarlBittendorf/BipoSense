include("../startup.jl")

using CSV

df = d"BipoSense Unique Places"

CSV.write(joinpath("data", "BipoSense Unique Places.csv"), df)