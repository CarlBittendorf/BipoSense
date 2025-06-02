
# 1. Exports
# 2. Implementations

####################################################################################################
# EXPORTS
####################################################################################################

export rolling, dynamical_systems_theory

####################################################################################################
# IMPLEMENTATIONS
####################################################################################################

function rolling(f, x; n, min_n = n, drop_missings = true)
    values = repeat(Union{Missing, Float64}[missing], length(x))

    for i in min_n:length(x)
        start = max(1, i - n + 1)

        if drop_missings
            y = collect(skipmissing(x[start:i]))

            if length(y) >= min_n
                values[i] = f(y)
            end
        else
            values[i] = f(x[start:i])
        end
    end

    return values
end

function auto_correlation(data)
    # remove missings and convert indices and values to a common type
    x, y = @chain begin
        skipmissings(eachindex(data), data)
        collect.(_)
        convert.(Vector{Float64}, _)
    end

    # detrend the data using local polynomial regression
    N = length(data)
    grid = LocalPoly.GridData((1.0:N,), zeros(N), zeros(N))
    linear_binning!(grid, x, y)
    trend = first.(lpreg(grid; h = 10))
    detrended = data .- trend

    rolling(detrended; n = 15, min_n = 8, drop_missings = false) do values
        # the current and previous days cannot be missing
        if all(!ismissing, values[(end - 1):end])
            x, y = collect.(skipmissings(values, ShiftedArrays.lag(values)))

            # at least 7 non-missing pairs are needed
            if length(x) >= 7 && var(x) > 0 && var(y) > 0
                return cor(x, y)
            end
        end

        return missing
    end
end

log_variance(data) = rolling(x -> log(1 + var(x)), data; n = 14, min_n = 7)

average(data) = rolling(mean, data; n = 14, min_n = 7)

function dynamical_systems_theory(x)
    [auto_correlation(x) log_variance(x) average(x)]
end

function dynamical_systems_theory(df::DataFrame, variables::AbstractVector{Symbol})
    outputs = map(x -> Symbol.([x * suffix for suffix in ["AR", "LNVAR", "AVG"]]),
        string.(variables))

    @chain df begin
        groupby(:Participant)
        transform(variables .=> dynamical_systems_theory .=> outputs)
    end
end