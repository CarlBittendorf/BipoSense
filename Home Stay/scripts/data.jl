include("../startup.jl")

using CSV

df = d"BipoSense Home Stay"

CSV.write(joinpath("data", "BipoSense Home Stay.csv"), df)