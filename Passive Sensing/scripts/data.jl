include("../startup.jl")

using CSV

df = d"BipoSense Passive Sensing"

CSV.write(joinpath("data", "BipoSense Passive Sensing.csv"), df)