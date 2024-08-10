
# calculate the distance between two GPS data points
# adopted from https://github.com/JuliaStats/Distances.jl/blob/master/src/haversine.jl
function haversine_distance(x, y; radius=6371000)
    λ₁, φ₁ = x
    λ₂, φ₂ = y

    Δλ = λ₂ - λ₁  # longitudes
    Δφ = φ₂ - φ₁  # latitudes

    # haversine formula
    a = sind(Δφ / 2)^2 + cosd(φ₁) * cosd(φ₂) * sind(Δλ / 2)^2

    # distance on the sphere
    return 2 * (radius * asin(min(√a, one(a)))) # take care of floating point errors
end


# calculate the distances between consecutive positions
function distance_from_previous(latitudes, longitudes)
    N = length(latitudes)
    distances = zeros(N)

    for i in 2:N
        distances[i] = haversine_distance([longitudes[i-1], latitudes[i-1]], [longitudes[i], latitudes[i]])
    end

    return distances
end


# remove wrong/implausible timestamps
function filter_timestamps(timestamps, start)
    keep = trues(length(timestamps))

    # entries are first deleted at the beginning that are more than 10 weeks after the actual start time...
    for (index, timestamp) in enumerate(timestamps)
        if timestamp > start + 60 * 60 * 24 * 70 # 10 weeks
            keep[index] = false
        else
            break
        end
    end

    previous = start

    # ...and then all for which there is at least one previous entry that is at least as old
    for (index, timestamp) in enumerate(timestamps)
        !keep[index] && continue

        if timestamp <= previous
            keep[index] = false
        else
            previous = timestamp
        end
    end

    return keep
end


# calculate the time differences from start to dates in seconds
differences_in_seconds(dates, start) = round.(Int, Dates.value.(Dates.DateTime.(dates) .- start) ./ 1000)


# replace missings with the previous non-missing value
filldown(x) = accumulate((a, b) -> coalesce(b, a), x; init=coalesce(x...))


# return the first element of `a` that satisfies condition `f`
getfirst(f::Function, a) = first(Iterators.filter(f, a))


# obtain a more detailed description of the state, termed "disorder status" in the paper
# for example "DepressionEarlyProdromal" or "ManiaSecondWeek"
function determine_phase(episode, index)
    type = episode[index]

    if type in ["Depression", "Mania"]
        # the index of the last previous day that was not part of the current episode
        last_day = findprev(x -> x == "Euthymic", episode, index)

        # the index of the first day of the current episode
        if last_day === nothing
            first_day = 1
        else
            first_day = last_day + 1
        end

        if index - first_day < 7
            return type * "FirstWeek"
        elseif index - first_day < 14
            return type * "SecondWeek"
        else
            return type * "OngoingWeeks"
        end

    else
        # the index of the next day that is part of an episode
        next_day = findnext(x -> x in ["Depression", "Mania"], episode, index)

        if next_day !== nothing
            type = episode[next_day]

            if next_day - index <= 7
                return type * "LateProdromal"
            elseif next_day - index <= 14
                return type * "EarlyProdromal"
            end
        end

        return "Euthymic"
    end
end


determine_phases(episode) = [determine_phase(episode, i) for i in eachindex(episode)]


# create a unique label for the rows of each different episode
# this is needed to be able to group by episode
function enumerate_phases(phase)
    labels = ["" for _ in phase]
    phase_index = 0
    in_phase = false

    for i in eachindex(phase)
        if phase[i] != "Euthymic"
            if !in_phase
                in_phase = true
                phase_index += 1
            end

            labels[i] = "Phase_" * string(phase_index)
        else
            if in_phase
                in_phase = false
            end
        end
    end

    return labels
end


function replace_phonecall_missings(variable)
    # index of the last non-missing
    # missings at the end occur when the app's permissions have been revoked
    index = findlast(x -> !ismissing(x), variable)

    # replace missings with zeros
    cleaned = replace(variable[1:index], missing => 0)

    return vcat(cleaned, repeat([missing], length(variable) - index))
end