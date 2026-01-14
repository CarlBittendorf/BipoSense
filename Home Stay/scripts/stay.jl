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

    # only use days where at least 1/3 of the minutes are not missing
    function filter_missing(f, x)
        if mean(ismissing.(x)) < 1 / 3
            return f(skipmissing(x))
        else
            return missing
        end
    end

    df = @chain var"data#BipoSense Mobile Sensing" begin
        gather(MovisensXSLocation; callback = correct_timestamps)
        transform(:MovisensXSParticipantID => ByRow(x -> parse(Int, x)); renamecols = false)
        leftjoin(var"data#BipoSense Assignments"; on = :MovisensXSParticipantID)
        dropmissing(:Participant)
        sort([:Participant, :DateTime])

        filter_locations(; max_velocity, groupcols = [:Participant])

        # fill missing timestamps
        select(:Participant, :DateTime, :Latitude, :Longitude, :LocationConfidence)
        fill_periods(Day(1), Minute(1); groupcols = [:Participant])
        groupby(:Participant)
        transform(
            [:Latitude, :Longitude, :LocationConfidence] .=> fill_down;
            renamecols = false
        )

        leftjoin(df_home; on = :Participant)
        dropmissing([:HomeLatitude, :HomeLongitude])
        transform(
            [:Latitude, :Longitude, :HomeLatitude, :HomeLongitude] => ByRow(distance) => :Distance,
            :LocationConfidence => ByRow(x -> x <= 0 ? 0.0 : x) => :LocationConfidence,
            :DateTime => ByRow(Time) => :Time
        )

        # remove points where its unclear if they are at home or not due to poor accuracy
        transform(
            [:Distance, :LocationConfidence] => ByRow((d, c) -> (d <= radius || c <= 100 ||
                                                                 d > c + radius) ? [d, c] :
                                                                [missing missing]);
            renamecols = false
        )

        groupby_period(Day(1); groupcols = [:Participant])
        combine(
            :Distance => (x -> filter_missing(mean, x)) => :MeanDistanceFromHome,
            :Distance => (x -> filter_missing(maximum, x)) => :MaxDistanceFromHome,
            :Distance => (x -> filter_missing(mean, x .<= radius)) => :FractionAtHome,
            [:Distance, :Time] => ((x, t) -> filter_missing(mean, filter_day(x, t))) => :MeanDistanceFromHomeDay,
            [:Distance, :Time] => ((x, t) -> filter_missing(maximum, filter_day(x, t))) => :MaxDistanceFromHomeDay,
            [:Distance, :Time] => ((x, t) -> filter_missing(mean, filter_day(x, t) .<= radius)) => :FractionAtHomeDay,
            [:Distance, :Time] => ((x, t) -> filter_missing(mean, filter_night(x, t))) => :MeanDistanceFromHomeNight,
            [:Distance, :Time] => ((x, t) -> filter_missing(maximum, filter_night(x, t))) => :MaxDistanceFromHomeNight,
            [:Distance, :Time] => ((x, t) -> filter_missing(mean, filter_night(x, t) .<= radius)) => :FractionAtHomeNight,
            :LocationConfidence => (x -> filter_missing(median, x)) => :MedianLocationConfidence
        )
        transform(
            [:MeanDistanceFromHome, :MaxDistanceFromHome,
                :MeanDistanceFromHomeDay, :MaxDistanceFromHomeDay,
                :MeanDistanceFromHomeNight, :MaxDistanceFromHomeNight] .=> (x -> x ./ 1000),
            [:FractionAtHome, :FractionAtHomeDay, :FractionAtHomeNight] .=> (x -> x .* 100);
            renamecols = false
        )

        transform(:DateTime => ByRow(Date) => :Date)
        select(Not(:DateTime))
        leftjoin(var"data#BipoSense Ground Truth", _; on = [:Participant, :Date])
        subset(:Participant => ByRow(!isequal(4289)))
        transform(
            :State => (x -> replace(x, "Hypomania" => "Mania", "Mixed" => missing));
            renamecols = false
        )
        sort([:Participant, :Date])
    end

    names_avg7 = add_suffixes(VARIABLES, ["AVG7"])
    names_var = add_suffixes(VARIABLES, ["VAR"])

    df_dst = @chain df begin
        dynamical_systems_theory(VARIABLES)
        transform(
            VARIABLES .=> (x -> rolling(mean, x; n = 7, min_n = 4)) .=> names_avg7,
            VARIABLES .=> (x -> rolling(var, x; n = 14, min_n = 7)) .=> names_var
        )
    end

    @chain df begin
        subset(:Participant => ByRow(!isequal(2869)))

        statistical_process_control(VARIABLES; λ, L)

        select(Not([:State, :MedianLocationConfidence, VARIABLES...]))

        rightjoin(df_dst; on = [:Participant, :Date])

        sort([:Participant, :Date])
    end
end