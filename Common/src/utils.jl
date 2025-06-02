
# 1. Exports
# 2. Helper Functions
# 3. Implementations

####################################################################################################
# EXPORTS
####################################################################################################

export label_phases, enumerate_phases, enumerate_prodromal_days, determine_baseline,
       add_suffixes

####################################################################################################
# HELPER FUNCTIONS
####################################################################################################

function _label_phase(states, i)
    state = states[i]

    if ismissing(state)
        return missing

    elseif state != "Euthymia"
        # index of the last day that was not part of the current episode
        last_euthymia_day = findprev(x -> ismissing(x) || x == "Euthymia", states, i)

        # determine the index of the first day of the current episode
        if isnothing(last_euthymia_day)
            first_episode_day = 1
        else
            first_episode_day = last_euthymia_day + 1
        end

        if i - first_episode_day < 7
            return state * "FirstWeek"
        elseif i - first_episode_day < 14
            return state * "SecondWeek"
        else
            return state * "OngoingWeeks"
        end

    else
        # index of the next day that is part of an episode
        next_episode_day = findnext(x -> !ismissing(x) && x != "Euthymia", states, i)

        if !isnothing(next_episode_day)
            state = states[next_episode_day]

            if next_episode_day - i <= 7
                return state * "LateProdromal"
            elseif next_episode_day - i <= 14
                return state * "EarlyProdromal"
            end
        end

        return "Euthymia"
    end
end

function _make_base_dataframe(df, facet)
    @chain df begin
        groupby(facet)
        transform(
            :Date => enumerate_days => :Day,
            :State => determine_baseline => :Baseline,
            :State => label_phases => :Phase;
            ungroup = false
        )
        transform(:Phase => enumerate_phases => :PhaseIndex)

        transform([:Phase, :Baseline] => ByRow((p, b) -> b ? "Baseline" : p) => :Phase)
    end
end

####################################################################################################
# IMPLEMENTATIONS
####################################################################################################

"""
    label_phases(states) -> Vector{String}

Obtain a more detailed description of the state, for example "DepressionEarlyProdromal" or "ManiaSecondWeek".
"""
label_phases(states) = map(i -> _label_phase(states, i), eachindex(states))

"""
    enumerate_phases(phases) -> Vector{Int}

Create labels for each episode.

This is useful to be able to group by episode. "Euthymia" always receives the label 0.

# Examples

```jldoctest
julia> enumerate_phases(["Euthymia", "Depression", "Depression", "Euthymia", "Mania", "Mania", "Euthymia"])
7-element Vector{Int64}:
 0
 1
 1
 0
 2
 2
 0

julia> enumerate_phases(["Depression", "Depression", "Euthymia", "Euthymia", "Mania", "Mania", "Euthymia"])
7-element Vector{Int64}:
 1
 1
 0
 0
 2
 2
 0
```
"""
function enumerate_phases(phases)
    labels = zeros(Int, length(phases))

    for i in eachindex(phases)
        (ismissing(phases[i]) || phases[i] == "Euthymia") && continue

        p = findprev(!ismissing, phases, i - 1)

        if !isnothing(p) && phases[p] != "Euthymia" &&
           !(!endswith(phases[p], "Prodromal") && endswith(phases[i], "Prodromal"))
            labels[i] = labels[p]
        else
            labels[i] = maximum(labels) + 1
        end
    end

    return labels
end

function enumerate_prodromal_days(phases)
    map(
        i -> begin
            if !ismissing(phases[i]) && endswith(phases[i], "Prodromal")
                n = findnext(x -> !ismissing(x) && endswith(x, "FirstWeek"), phases, i)

                if !isnothing(n)
                    return 15 - (n - i)
                end
            end

            return missing
        end,
        eachindex(phases)
    )
end

"""
    determine_baseline(states; duration = 28) -> BitVector

Determine a baseline phase of length `duration` that only includes euthymic days.

# Examples

```jldoctest
julia> determine_baseline(["Euthymia", "Depression", "Euthymia", "Euthymia", "Mania"]; duration = 2)
5-element BitVector:
 0
 0
 1
 1
 0

julia> determine_baseline(["Euthymia", "Depression", "Euthymia", "Euthymia", "Mania"]; duration = 7)
5-element BitVector:
 0
 0
 0
 0
 0

julia> determine_baseline(["Euthymia", "Depression", missing, "Euthymia", "Mania"]; duration = 2)
5-element BitVector:
 0
 0
 1
 1
 0
```
"""
function determine_baseline(states; duration = 28)
    labels = falses(length(states))
    iseuthymic = states .== "Euthymia"
    index = findfirst(
        i -> all(iseuthymic[i:(i + duration - 1)]) !== false, 1:(length(states) - duration + 1))

    if !isnothing(index)
        labels[index:(index + duration - 1)] .= true
    end

    return labels
end

determine_baseline(; duration = 28) = (states) -> determine_baseline(states; duration)

function add_suffixes(variables, suffixes)
    vcat((map(x -> Symbol(string(x) * suffix), variables) for suffix in suffixes)...)
end