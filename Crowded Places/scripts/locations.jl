function (;
        var"data#BipoSense Mobile Sensing",
        var"data#BipoSense Assignments",
        max_velocity = 300
)
    germany = NaturalEarth.countries() |>
              Filter(row -> row.NAME == "Germany") |>
              Select(168) # geometry

    @chain var"data#BipoSense Mobile Sensing" begin
        gather(MovisensXSLocation; callback = correct_timestamps)
        transform(:MovisensXSParticipantID => ByRow(x -> parse(Int, x)); renamecols = false)
        leftjoin(var"data#BipoSense Assignments"; on = :MovisensXSParticipantID)
        dropmissing(:Participant)

        filter_locations(; max_velocity, groupcols = [:Participant])
        select(:Participant, :DateTime, :Latitude, :Longitude)
        georef((:Longitude, :Latitude))
        geojoin(germany; pred = ∈, kind = :inner)

        DataFrame
        transform(:geometry => ByRow(x -> ustrip.([x.coords.lat, x.coords.lon]))
        => [:Latitude, :Longitude])

        select(:Participant, :DateTime, :Latitude, :Longitude)
        sort([:Participant, :DateTime])
    end
end