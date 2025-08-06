function (;
        var"data#BipoSense Mobile Sensing",
        var"data#BipoSense Assignments",
        var"data#BipoSense Residential Locations",
        var"data#BipoSense Ground Truth",
        max_velocity = 300,
        radius = 100,
        λ = 0.15,
        L = 2.536435
)
    df_home = rename(
        var"data#BipoSense Residential Locations",
        :Latitude => :HomeLatitude,
        :Longitude => :HomeLongitude
    )

    # select values between 07:00 and 22:00
    filter_day(x, t) = x[(t .>= Time(7)) .& (t .<= Time(22))]

    # select values between 22:00 and 05:00
    filter_night(x, t) = x[(t .<= Time(5)) .| (t .>= Time(22))]

    distance(x, y, u, v) = haversine([x, y], [u, v])

    names_avg7 = add_suffixes(VARIABLES, ["AVG7"])
    names_var = add_suffixes(VARIABLES, ["VAR"])

    @chain var"data#BipoSense Mobile Sensing" begin
        gather(MovisensXSLocation; callback = correct_timestamps)
        transform(:MovisensXSParticipantID => ByRow(x -> parse(Int, x)); renamecols = false)
        leftjoin(var"data#BipoSense Assignments"; on = :MovisensXSParticipantID)
        dropmissing(:Participant)
        sort([:Participant, :DateTime])

        filter_locations(; max_velocity, groupcols = [:Participant])

        # fill missing timestamps
        select(:Participant, :DateTime, :Latitude, :Longitude)
        fill_periods(Day(1), Minute(1); groupcols = [:Participant])
        groupby(:Participant)
        transform([:Latitude, :Longitude] .=> fill_down; renamecols = false)

        leftjoin(df_home; on = :Participant)
        dropmissing([:HomeLatitude, :HomeLongitude])
        transform(
            [:Latitude, :Longitude, :HomeLatitude, :HomeLongitude] => ByRow(distance) => :Distance,
            :DateTime => ByRow(Time) => :Time
        )

        groupby_period(Day(1); groupcols = [:Participant])
        combine(
            :Distance => mean => :MeanDistanceFromHome,
            :Distance => maximum => :MaxDistanceFromHome,
            :Distance => (x -> mean(x .<= radius)) => :FractionAtHome,
            [:Distance, :Time] => ((x, t) -> mean(filter_day(x, t) .<= radius)) => :FractionAtHomeDay,
            [:Distance, :Time] => ((x, t) -> mean(filter_night(x, t))) => :MeanDistanceFromHomeNight,
            [:Distance, :Time] => ((x, t) -> maximum(filter_night(x, t))) => :MaxDistanceFromHomeNight,
            [:Distance, :Time] => ((x, t) -> mean(filter_night(x, t) .<= radius)) => :FractionAtHomeNight
        )
        transform(
            [:MeanDistanceFromHome, :MaxDistanceFromHome,
                :MeanDistanceFromHomeNight, :MaxDistanceFromHomeNight] .=> (x -> x ./ 1000),
            [:FractionAtHome, :FractionAtHomeDay, :FractionAtHomeNight] .=> (x -> x .* 100);
            renamecols = false
        )

        transform(:DateTime => ByRow(Date) => :Date)
        select(Not(:DateTime))
        leftjoin(var"data#BipoSense Ground Truth", _; on = [:Participant, :Date])
        subset(:Participant => ByRow(x -> !(x in [2869, 4289])))
        transform(
            :State => (x -> replace(x, "Hypomania" => "Mania", "Mixed" => missing));
            renamecols = false
        )
        sort([:Participant, :Date])

        statistical_process_control(VARIABLES; λ, L)
        dynamical_systems_theory(VARIABLES)
        transform(
            VARIABLES .=> (x -> rolling(mean, x; n = 7, min_n = 4)) .=> names_avg7,
            VARIABLES .=> (x -> rolling(var, x; n = 14, min_n = 7)) .=> names_var
        )
    end
end