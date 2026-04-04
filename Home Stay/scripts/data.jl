include("../startup.jl")

using CSV

df = @chain d"BipoSense Home Stay" begin
    groupby(:Participant)
    transform(:State => label_phases => :Phase)
end

CSV.write(joinpath("data", "BipoSense Home Stay.csv"), df)