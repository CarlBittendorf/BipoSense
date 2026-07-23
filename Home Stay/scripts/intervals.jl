include("../startup.jl")

using AlgebraOfGraphics, CairoMakie

set_aog_theme!()

function interval_lengths(x)
    lengths = Int[]
    current = 0

    for e in x
        if e
            current += 1
        else
            if current > 0
                push!(lengths, current)
                current = 0
            end
        end
    end

    if current > 0
        push!(lengths, current)
    end

    return lengths
end

df = @chain d"BipoSense Mobile Sensing::Dict{String,IO}" begin
    gather(MovisensXSLocation; callback = correct_timestamps)
    transform(:MovisensXSParticipantID => ByRow(x -> parse(Int, x)); renamecols = false)
    leftjoin(d"BipoSense Assignments"; on = :MovisensXSParticipantID)
    dropmissing(:Participant)
    sort([:Participant, :DateTime])

    filter_locations(; max_velocity = 300, groupcols = [:Participant])

    # fill missing timestamps
    select(:Participant, :DateTime, :Latitude, :Longitude, :LocationConfidence)
    fill_periods(Day(1), Minute(1); groupcols = [:Participant])

    transform(:Latitude => ByRow(ismissing) => :IsMissing)

    groupby(:Participant)
    combine(:IsMissing => interval_lengths => :IntervalLengths)

    transform(:IntervalLengths => ByRow(x -> x / 60); renamecols = false)
end

figure = draw(
    data(df) * mapping(:IntervalLengths => "Interval Lengths [h]") *
    visual(Hist; bins = 100);
    axis = (; ylabel = "Count")
)

save("figures/paper/Interval Lengths.png", figure; px_per_unit = 3)