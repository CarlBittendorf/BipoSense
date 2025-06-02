include("../startup.jl")

using CSV

df = d"BipoSense Critical Slowing Down"

CSV.write(joinpath("data", "BipoSense Critical Slowing Down.csv"), df)