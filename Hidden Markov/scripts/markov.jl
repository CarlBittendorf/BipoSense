function (;
        var"data#BipoSense Mobile Sensing",
        var"data#BipoSense Assignments",
        var"data#BipoSense Residential Locations",
        var"data#BipoSense Forms",
        var"data#BipoSense Ground Truth",
        var"data#BipoSense Dimensional Ratings",
        max_velocity = 300,
        radius = 100
)
    function preprocess_sensing(T, sensing)
        @chain sensing begin
            deepcopy
            gather(T; callback = correct_timestamps)
            transform(
                :MovisensXSParticipantID => ByRow(x -> parse(Int, x));
                renamecols = false
            )
        end
    end

    function aggregate_sensing(df, T)
        @chain df begin
            aggregate(T, Hour(1))
            leftjoin(var"data#BipoSense Assignments"; on = :MovisensXSParticipantID)
            dropmissing(:Participant)
            select(Not(:MovisensXSParticipantID, :MovisensXSStudyID))

            groupby([:Participant, :DateTime])
            combine(All() .=> (x -> coalesce(x...)); renamecols = false)
        end
    end

    function replace_missings(x)
        i = findlast(!ismissing, x)
        clean = replace(x[1:i], missing => 0)

        return vcat(clean, repeat([missing], length(x) - i))
    end

    function is_dst(dt)
        year = Dates.year(dt)

        # find last Sunday of March
        march_last_day = Date(year, 3, 31)
        last_sunday_march = march_last_day - Day(dayofweek(march_last_day) % 7)

        # find last Sunday of October
        october_last_day = Date(year, 10, 31)
        last_sunday_october = october_last_day - Day(dayofweek(october_last_day) % 7)

        # DST is active from last Sunday in March (inclusive) until last Sunday in October (exclusive)
        return last_sunday_march <= dt < last_sunday_october
    end

    distance(x, y, u, v) = haversine([x, y], [u, v])

    # only use hours where at least 1/3 of the minutes are not missing
    function filter_missing(f, x)
        if mean(ismissing.(x)) < 1 / 3
            return f(skipmissing(x))
        else
            return missing
        end
    end

    function transfer_minutes(x)
        y = copy(x)

        for i in eachindex(x)
            i == 1 && continue

            if !ismissing(y[i - 1]) && !ismissing(y[i]) && y[i - 1] > 60
                y[i] += y[i - 1] - 60
                y[i - 1] = min(y[i - 1], 60)
            end
        end

        if !ismissing(y[end])
            y[end] = min(y[end], 60)
        end

        return y
    end

    df_calls, df_display, df_location, df_physical_activity, df_steps = map(
        T -> preprocess_sensing(T, var"data#BipoSense Mobile Sensing"),
        [MovisensXSCalls, MovisensXSDisplay, MovisensXSLocation,
            MovisensXSPhysicalActivity, MovisensXSSteps]
    )

    df_calls = @chain df_calls begin
        aggregate_sensing(MovisensXSCalls)
        transform(:SecondsCallDuration => ByRow(x -> x / 60) => :MinutesCallDuration)
    end

    df_display = @chain df_display begin
        fill_periods(
            Day(1), Hour(1); groupcols = [:MovisensXSParticipantID, :MovisensXSStudyID])

        groupby([:MovisensXSParticipantID, :MovisensXSStudyID])
        transform(
            :DisplayOn => fill_down,
            :DateTime => duration_to_next(Hour(1)) => :DisplayDuration;
            renamecols = false
        )

        groupby_period(Hour(1); groupcols = [:MovisensXSParticipantID, :MovisensXSStudyID])
        combine(
            :DisplayOn => count => :CountDisplayOn,
            [:DisplayOn, :DisplayDuration] => ((o, d) -> sum(d[.!o])) => :SecondsDisplayOff,
            [:DisplayOn, :DisplayDuration] => ((o, d) -> sum(d[o])) => :SecondsDisplayOn
        )

        leftjoin(var"data#BipoSense Assignments"; on = :MovisensXSParticipantID)
        dropmissing(:Participant)
        select(Not(:MovisensXSParticipantID, :MovisensXSStudyID))

        groupby([:Participant, :DateTime])
        combine(All() .=> (x -> coalesce(x...)); renamecols = false)

        transform(:SecondsDisplayOn => ByRow(x -> x / 60) => :MinutesDisplayOn)
    end

    df_travelled = aggregate_sensing(df_location, MovisensXSLocation)

    df_physical_activity = @chain df_physical_activity begin
        aggregate_sensing(MovisensXSPhysicalActivity)
        transform([:SecondsInVehicle, :SecondsOnFoot, :SecondsStill] .=>
            ByRow(x -> x / 60) .=> [:MinutesInVehicle, :MinutesOnFoot, :MinutesStill])
    end

    df_steps = aggregate_sensing(df_steps, MovisensXSSteps)

    df_sleep = @chain var"data#BipoSense Forms" begin
        flatten(:HourlyStates)

        groupby([:Participant, :FormTrigger])
        transform(:FormTrigger => (x -> [floor(first(x), Day) + Hour(i) for i in 0:23]) => :DateTime)

        rename(:HourlyStates => :HourlyState)
        select(:Participant, :DateTime, :HourlyState)
    end

    df_home = @chain df_location begin
        leftjoin(var"data#BipoSense Assignments"; on = :MovisensXSParticipantID)
        dropmissing(:Participant)
        select(Not(:MovisensXSParticipantID, :MovisensXSStudyID))

        groupby([:Participant, :DateTime])
        combine(All() .=> (x -> coalesce(x...)); renamecols = false)
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

        leftjoin(
            rename(
                var"data#BipoSense Residential Locations",
                :Latitude => :HomeLatitude,
                :Longitude => :HomeLongitude
            );
            on = :Participant
        )
        dropmissing([:HomeLatitude, :HomeLongitude])
        transform(
            [:Latitude, :Longitude, :HomeLatitude, :HomeLongitude] => ByRow((x...) -> any(ismissing, x) ? missing : distance(x...)) => :Distance,
            :LocationConfidence => ByRow(x -> ismissing(x) ? x : x <= 0 ? 0.0 : x) => :LocationConfidence,
            :DateTime => ByRow(Time) => :Time
        )

        # remove points where its unclear if they are at home or not due to poor accuracy
        transform(
            [:Distance, :LocationConfidence] => ByRow((d, c) -> !ismissing(d) &&
                (d <= radius || c <= 100 ||
                 d > c + radius) ? [d, c] : [missing missing]);
            renamecols = false
        )

        groupby_period(Hour(1); groupcols = [:Participant])
        combine(
            :Distance => (x -> filter_missing(mean, x)) => :MeanDistanceFromHome,
            :Distance => (x -> filter_missing(maximum, x)) => :MaxDistanceFromHome,
            :Distance => (x -> filter_missing(mean, x .<= radius)) => :FractionAtHome,
            :LocationConfidence => (x -> filter_missing(median, x)) => :MedianLocationConfidence
        )

        transform(
            [:MeanDistanceFromHome, :MaxDistanceFromHome] .=> (x -> x ./ 1000),
            :FractionAtHome => (x -> x .* 100);
            renamecols = false
        )
    end

    df_ground_truth = @chain var"data#BipoSense Ground Truth" begin
        transform(
            :State => (x -> replace(x, "Hypomania" => "Mania", "Mixed" => missing));
            renamecols = false
        )

        groupby(:Participant)
        transform(:State => label_phases => :Phase)

        leftjoin(var"data#BipoSense Dimensional Ratings"; on = [:Participant, :Date])
        sort([:Participant, :Date])

        groupby(:Participant)
        transform(
            names(var"data#BipoSense Dimensional Ratings")[3:end] .=>
                (x -> [coalesce(x[min(i + 1, length(x)):min(i + 3, length(x))]...)
                       for i in eachindex(x)]);
            renamecols = false
        )
    end

    @chain begin
        outerjoin(
            df_calls, df_display, df_travelled,
            df_physical_activity, df_steps, df_sleep, df_home;
            on = [:Participant, :DateTime]
        )

        groupby(:Participant)
        transform(:DateTime => (x -> is_dst(minimum(x)) ? 2 : 1) => :OffsetUTC)
        transform([:DateTime, :OffsetUTC] => ByRow((dt, o) -> dt - Hour(o)) => :DateTime)

        transform(:DateTime => ByRow(Date) => :Date)

        rightjoin(df_ground_truth; on = [:Participant, :Date])
        select(:Participant, :Date, :DateTime, :OffsetUTC, :State, :Phase,
            VARIABLES..., names(var"data#BipoSense Dimensional Ratings")[3:end]...)
        sort([:Participant, :Date, :DateTime])

        transform(
            [:TotalCalls, :IncomingCalls, :IncomingMissedCalls,
                :OutgoingCalls, :OutgoingNotReachedCalls,
                :MinutesCallDuration, :UniqueConversationPartners] .=> replace_missings;
            renamecols = false
        )

        groupby(:Participant)
        transform(
            :MinutesCallDuration => transfer_minutes;
            renamecols = false
        )

        transform([:Date, :DateTime] => ByRow((d, dt) -> ismissing(dt) ? DateTime(d) : dt) => :DateTime)

        fill_periods(Day(1), Hour(1); groupcols = [:Participant])

        transform([:Date, :DateTime] => ByRow((d, dt) -> ismissing(d) ? Date(dt) : d) => :Date)

        groupby([:Participant, :Date])
        transform(
            [:State, :Phase] .=> (x -> coalesce(x...)),
            names(var"data#BipoSense Dimensional Ratings")[3:end] .=> (x -> coalesce(x...));
            renamecols = false
        )
    end
end