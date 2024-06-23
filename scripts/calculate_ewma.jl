function (; var"data#biposense (merged)", lambda=0.15, L=2.536435)
    λ = lambda


    function replace_phonecall_missings(variable)
        # index of the last non-missing
        # missings at the end occur when the app's permissions have been revoked
        index = findlast(x -> !ismissing(x), variable)

        # replace missings with zeros
        cleaned = replace(variable[1:index], missing => 0)

        vcat(cleaned, repeat([missing], length(variable) - index))
    end


    function ewma(variable, baseline, episode)
        baseline_start = findfirst(baseline)

        # baseline mean
        average = variable[baseline] |> skipmissing |> Statistics.mean

        # index of the last non-missing
        # missings at the end occur when the app's permissions have been revoked
        index = findlast(x -> !ismissing(x), variable)

        # replace missings with baseline mean
        cleaned = replace(variable[1:index], missing => average)

        # calculate the EWMA for pre-baseline and baseline + post-baseline separately
        vcat(
            ewma_smooth(cleaned[1:baseline_start-1], λ, first(episode) == "Euthymic" ? average : first(cleaned)),
            ewma_smooth(cleaned[baseline_start:end], λ, average),
            repeat([missing], length(variable) - index)
        )
    end


    # calculate lower and upper control limits
    function limits(variable, baseline, _)
        baseline_start = findfirst(baseline)

        lcl, ucl = control_limits(variable[baseline_start:end], λ, L)

        # fill the pre-baseline with the first post-baseline limits
        lcl = vcat(repeat([lcl[29]], length(1:baseline_start-1)), lcl)
        ucl = vcat(repeat([ucl[29]], length(1:baseline_start-1)), ucl)

        return [lcl ucl]
    end


    # check if the EWMA is outside the limits
    outside(avg, lcl, ucl) = convert.(Union{Int,Missing}, (avg .< lcl) .| (avg .> ucl))


    # construct column names
    names_ewma = map(x -> Symbol(string(x) * "_EWMA"), VARIABLES)
    names_limits = map(x -> Symbol.([string(x) * "_LCL", string(x) * "_UCL"]), VARIABLES)
    names_outside = map(x -> Symbol(string(x) * "_OUTSIDE"), VARIABLES)

    # vectors of vectors of column names to calculate EWMA and control limits
    triplets_ewma = map(x -> [x, :IsBaseline, :State], VARIABLES)
    triplets_outside = vcat.(names_ewma, names_limits)

    @chain var"data#biposense (merged)" begin
        sort([:Participant, :Day])
        groupby(:Participant)
        transform(PHONECALL_VARIABLES .=> replace_phonecall_missings; renamecols=false, ungroup=false)
        transform(
            triplets_ewma .=> ewma .=> names_ewma,
            triplets_ewma .=> limits .=> names_limits,
            [:Mood, :IsBaseline] => ((m, b) -> replace(m, missing => mean(skipmissing(m[b])))) => :MoodFixedLimitsNoEWMA
        )
        transform(
            :Mood => identity => :MoodFixedLimits,
            :Mood_EWMA => identity => :MoodFixedLimits_EWMA,
            :Day => (x -> 40) => :MoodFixedLimits_LCL,
            :Day => (x -> 60) => :MoodFixedLimits_UCL
        )
        transform(
            triplets_outside .=> outside .=> names_outside,
            [:Mood_EWMA, :MoodFixedLimits_LCL, :MoodFixedLimits_UCL] => outside => :MoodFixedLimits_OUTSIDE,
            [:MoodFixedLimitsNoEWMA, :MoodFixedLimits_LCL, :MoodFixedLimits_UCL] => outside => :MoodFixedLimitsNoEWMA_OUTSIDE
        )
    end
end