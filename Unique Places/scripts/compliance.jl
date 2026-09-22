include("../startup.jl")

@chain d"BipoSense Ground Truth" begin
    subset(:Participant => ByRow(!isequal(2869)))

    groupby(:Participant)
    transform(
        :State => (x -> replace(x, "Hypomania" => "Mania", "Mixed" => missing));
        renamecols = false
    )

    leftjoin(
        transform(d"BipoSense Forms", :FormTrigger => ByRow(Date) => :Date);
        on = [:Participant, :Date]
    )

    transform(:IsMissing => ByRow(x -> ismissing(x) ? true : x); renamecols = false)

    combine(
        nrow => :Total,
        :IsMissing => (x -> count(.!skipmissing(x))) => :NonMissing,
        :IsMissing => (x -> round(100 * mean(.!skipmissing(x)); digits = 1)) => :Compliance
    )
end

df_location = @chain d"BipoSense Mobile Sensing::Dict{String,IO}" begin
    gather(MovisensXSLocation; callback = correct_timestamps)
    transform(:MovisensXSParticipantID => ByRow(x -> parse(Int, x)); renamecols = false)
    leftjoin(d"BipoSense Assignments"; on = :MovisensXSParticipantID)
    dropmissing(:Participant)

    transform(:DateTime => ByRow(Date) => :Date)

    groupby([:Participant, :Date])
    combine(All() .=> first; renamecols = false)
end

@chain d"BipoSense Ground Truth" begin
    subset(:Participant => ByRow(!isequal(2869)))

    groupby(:Participant)
    transform(
        :State => (x -> replace(x, "Hypomania" => "Mania", "Mixed" => missing));
        renamecols = false
    )

    leftjoin(df_location; on = [:Participant, :Date])

    combine(
        nrow => :Total,
        :DateTime => (x -> count(.!ismissing.(x))) => :NonMissing,
        :DateTime => (x -> round(100 * mean(.!ismissing.(x)); digits = 1)) => :Compliance
    )
end