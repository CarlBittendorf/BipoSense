function (;
        var"data#BipoSense Mobile Sensing",
        var"data#BipoSense Assignments",
        var"data#BipoSense Ground Truth",
        max_velocity = 300,
        radius = 100,
        min_neighbors = 19,
        λ = 0.15,
        L = 2.536435
)
    @chain var"data#BipoSense Mobile Sensing" begin
        gather(MovisensXSLocation; callback = correct_timestamps)
        transform(:MovisensXSParticipantID => ByRow(x -> parse(Int, x)); renamecols = false)
        leftjoin(var"data#BipoSense Assignments"; on = :MovisensXSParticipantID)
        dropmissing(:Participant)

        aggregate(MovisensXSLocationClusters, Day(1);
            max_velocity, crs = utmnorth(32), radius, min_neighbors, groupcols = [:Participant])

        transform(:DateTime => ByRow(Date) => :Date)
        select(Not(:DateTime))
        leftjoin(var"data#BipoSense Ground Truth", _; on = [:Participant, :Date])
        subset(:Participant => ByRow(!isequal(2869)))
        transform(
            :State => (x -> replace(x, "Hypomania" => "Mania", "Mixed" => missing));
            renamecols = false
        )
        sort([:Participant, :Date])

        statistical_process_control(VARIABLES; λ, L)
        dynamical_systems_theory(VARIABLES)
    end
end