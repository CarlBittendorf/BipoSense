function (; var"data#biposense (merged)")

    function ar(variable, day)
        # remove missings and convert to a common type
        data = @chain begin
            skipmissings(day, variable)
            collect.(_)
            convert.(Vector{Float64}, _)
        end

        # local polynomial regression
        n = maximum(day)
        grid = LocalPoly.GridData((1.0:n,), zeros(n), zeros(n))
        linear_binning!(grid, data...)
        #grid = linear_binning(data...; nbins=maximum(day))
        trend = first.(lpreg(grid; h=10))

        # detrend the data
        detrended = variable - trend

        lagged = [detrended[2:end]..., missing]
        values = repeat(Union{Missing,Float64}[missing], length(detrended))

        for i in 7:length(detrended)
            # the current and previous days cannot be missing
            if !any(ismissing, detrended[i-1:i])
                start = max(1, i - 13)
                x, y = collect.(skipmissings(detrended[start:i], lagged[start:i]))

                # at least 7 non-missings are needed
                if length(x) >= 7
                    values[i] = cor(x, y)
                end
            end
        end

        return values
    end


    pairs_ar = map(x -> [x, :Day], VARIABLES)
    names_ar = map(x -> Symbol(string(x) * "_AR"), VARIABLES)

    @chain var"data#biposense (merged)" begin
        sort([:Participant, :Day])
        groupby(:Participant)
        transform(PHONECALL_VARIABLES .=> replace_phonecall_missings; renamecols=false, ungroup=false)
        transform(pairs_ar .=> ar .=> names_ar)
    end
end