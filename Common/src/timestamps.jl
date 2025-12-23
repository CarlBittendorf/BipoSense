
# 1. Exports
# 2. Helper Functions
# 3. Implementations

####################################################################################################
# EXPORTS
####################################################################################################

export correct_timestamps

####################################################################################################
# HELPER FUNCTIONS
####################################################################################################

function _filter_timestamps(timestamps, start)
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

    # ...and then all for which there is at least one previous entry that is older
    for (index, timestamp) in enumerate(timestamps)
        !keep[index] && continue

        if timestamp < previous
            keep[index] = false
        else
            previous = timestamp
        end
    end

    return keep
end

_filter_timestamps(start) = Base.Fix2(_filter_timestamps, start)

####################################################################################################
# IMPLEMENTATIONS
####################################################################################################

function correct_timestamps(df, participantid, _)
    dict = Dict(
        "4" => 91604320,
        "12" => 98984931,
        "20" => 169395450,
        "25" => 108673460,
        "60" => 159633430
    )

    if haskey(dict, participantid)
        start = dict[participantid]
    else
        start = 0
    end

    return subset(df, :SecondsSinceStart => _filter_timestamps(start))
end