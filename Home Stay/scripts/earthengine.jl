include("../startup.jl")

using CSV

df_locations = @chain d"BipoSense Mobile Sensing::Dict{String,IO}" begin
    gather(MovisensXSLocation; callback = correct_timestamps)
    transform(:MovisensXSParticipantID => ByRow(x -> parse(Int, x)); renamecols = false)
    leftjoin(d"BipoSense Assignments"; on = :MovisensXSParticipantID)
    dropmissing(:Participant)
    sort([:Participant, :DateTime])

    filter_locations(; max_velocity = 300, groupcols = [:Participant])
end

for participant in unique(df_locations.Participant)
    @chain df_locations begin
        subset(:Participant => ByRow(isequal(participant)))
        select([:Latitude, :Longitude])

        CSV.write("data/" * string(participant) * ".csv", _)
    end
end