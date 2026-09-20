include("../startup.jl")

using CSV

df = d"BipoSense Hidden Markov"

CSV.write(joinpath("data", "BipoSense Hidden Markov.csv"), df)