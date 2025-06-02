function (;
        var"data#BipoSense Mobile Sensing",
        var"data#BipoSense Assignments",
        var"data#BipoSense Forms",
        var"data#BipoSense Sleep Variables",
        var"data#BipoSense Ground Truth",
        λ = 0.15,
        L = 2.536435
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
            aggregate(T, Day(1))
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

    df_calls, df_display, df_location, df_physical_activity, df_steps = map(
        T -> preprocess_sensing(T, var"data#BipoSense Mobile Sensing"),
        [MovisensXSCalls, MovisensXSDisplay, MovisensXSLocation,
            MovisensXSPhysicalActivity, MovisensXSSteps]
    )

    df_inactive = @chain begin
        aggregate(
            select(df_display, :MovisensXSParticipantID, :DateTime, :DisplayOn),
            select(df_physical_activity, :MovisensXSParticipantID,
                :DateTime, :PhysicalActivityType),
            MovisensXSInactive, Day(1);
            groupcols = [:MovisensXSParticipantID]
        )
        leftjoin(var"data#BipoSense Assignments"; on = :MovisensXSParticipantID)
        dropmissing(:Participant)

        groupby([:Participant, :DateTime])
        combine(All() .=> (x -> coalesce(x...)); renamecols = false)

        transform(:SecondsPhoneInactive => ByRow(x -> x / 60) => :MinutesPhoneInactive)
    end

    df_calls = @chain df_calls begin
        aggregate_sensing(MovisensXSCalls)
        transform(:SecondsCallDuration => ByRow(x -> x / 60) => :MinutesCallDuration)
    end

    df_display = @chain df_display begin
        aggregate_sensing(MovisensXSDisplay)
        transform(:SecondsDisplayOn => ByRow(x -> x / 60) => :MinutesDisplayOn)
    end

    df_location = aggregate_sensing(df_location, MovisensXSLocation)

    df_physical_activity = @chain df_physical_activity begin
        aggregate_sensing(MovisensXSPhysicalActivity)
        transform([:SecondsInVehicle, :SecondsOnFoot, :SecondsStill] .=>
            ByRow(x -> x / 60) .=> [:MinutesInVehicle, :MinutesOnFoot, :MinutesStill])
    end

    df_steps = aggregate_sensing(df_steps, MovisensXSSteps)

    df_mood = @chain var"data#BipoSense Forms" begin
        transform(:FormTrigger => ByRow(Date) => :Date)
        select(:Participant, :Date, :ManicDepressiveMood)
    end

    @chain begin
        outerjoin(df_calls, df_display, df_location,
            df_physical_activity, df_steps, df_inactive; on = [:Participant, :DateTime])

        transform(:DateTime => ByRow(Date) => :Date)
        select(Not(:DateTime))

        leftjoin(df_mood; on = [:Participant, :Date])
        leftjoin(var"data#BipoSense Sleep Variables"; on = [:Participant, :Date])

        leftjoin(var"data#BipoSense Ground Truth", _; on = [:Participant, :Date])
        subset(:Participant => ByRow(!isequal(2869)))
        transform(
            :State => (x -> replace(x, "Hypomania" => "Mania", "Mixed" => missing));
            renamecols = false
        )
        select(:Participant, :Date, :State, VARIABLES[1:18]...)
        sort([:Participant, :Date])

        groupby(:Participant)
        transform(
            [:IncomingMissedCalls, :OutgoingCalls, :OutgoingNotReachedCalls,
                :MinutesCallDuration, :UniqueConversationPartners] .=> replace_missings;
            renamecols = false
        )

        statistical_process_control(VARIABLES[1:18]; λ, L)

        groupby(:Participant)
        transform(:State => determine_baseline => :Baseline; ungroup = false)
        transform(
            :ManicDepressiveMood => identity => :MoodFixedLimits,
            :ManicDepressiveMoodEWMA => identity => :MoodFixedLimitsEWMA,
            :ManicDepressiveMood => (x -> 40) => :MoodFixedLimitsLCL,
            :ManicDepressiveMood => (x -> 60) => :MoodFixedLimitsUCL,
            :ManicDepressiveMood => identity => :MoodFixedLimitsRaw,
            [:ManicDepressiveMood, :Baseline] => ((m, b) -> replace(m, missing => mean(skipmissing(m[b])))) => :MoodFixedLimitsRawEWMA,
            :ManicDepressiveMood => (x -> 40) => :MoodFixedLimitsRawLCL,
            :ManicDepressiveMood => (x -> 60) => :MoodFixedLimitsRawUCL
        )

        transform(
            [:MoodFixedLimitsEWMA, :MoodFixedLimitsLCL, :MoodFixedLimitsUCL] => isoutside => :MoodFixedLimitsOUT,
            [:MoodFixedLimitsRawEWMA, :MoodFixedLimitsRawLCL, :MoodFixedLimitsRawUCL] => isoutside => :MoodFixedLimitsRawOUT
        )
    end
end