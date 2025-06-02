
# 1. Exports
# 2. Implementations

####################################################################################################
# EXPORTS
####################################################################################################

export ewma_smooth, control_limits, isoutside, statistical_process_control

####################################################################################################
# IMPLEMENTATIONS
####################################################################################################

"""
    ewma_smooth(y, λ, μ)

Exponentially Weighted Moving Average.

The current value is weighted by `λ`, the previous EWMA by 1 - `λ`.
`μ` is the starting value, usually the mean of a baseline phase.

# Examples

```jldoctest
julia> ewma_smooth([3, 3, 2, 4, 3, 9, 8, 9, -3, -2], 0.15, 3)
10-element Vector{Float64}:
 3.0
 3.0
 2.8499999999999996
 3.0224999999999995
 3.019125
 3.91625625
 4.5288178125
 5.199495140624999
 3.969570869531249
 3.0741352391015617
```
"""
function ewma_smooth(y, λ, μ)
    N = length(y)

    # pre-allocate output vector
    z = zeros(N)

    # input vector is empty
    N == 0 && return z

    z[1] = λ * first(y) + (1 - λ) * μ

    for i in 2:N
        z[i] = λ * y[i] + (1 - λ) * z[i - 1]
    end

    return z
end

"""
    control_limits(y, λ, L; baseline)

Calculate lower and upper control limits.

# Examples

```jldoctest
julia> lcl, ucl = control_limits([3, 3, 2, 4, 3, 9, 8, 9, -3, -2], 0.15, 2.54; baseline = 1:5);

julia> lcl
10-element Vector{Float64}:
 2.7305923163679253
 2.646418451768195
 2.5963821288915403
 2.5637877967124885
 2.541678513650578
 2.5263462999682207
 2.515570639403827
 2.507932037816926
 2.5024861204231987
 2.498588249421245

julia> ucl
10-element Vector{Float64}:
 3.2694076836320747
 3.353581548231805
 3.4036178711084597
 3.4362122032875115
 3.458321486349422
 3.4736537000317793
 3.484429360596173
 3.492067962183074
 3.4975138795768013
 3.501411750578755
```
"""
function control_limits(y, λ, L; baseline)
    μ̂ = @chain y[baseline] begin
        skipmissing
        mean
    end

    σ̂ = @chain y[baseline] begin
        skipmissing
        std
    end

    deviations = L * σ̂ * sqrt.(λ / (2 - λ) * [1 - (1 - λ)^(2 * i) for i in eachindex(y)])

    lcl = μ̂ .- deviations
    ucl = μ̂ .+ deviations

    return lcl, ucl
end

"""
    isoutside(x, lcl, ucl) -> Vector{Int64}

Check if the EWMA `x` is outside the control limits.

# Examples

```jldoctest
julia> isoutside([3, 3, 2, 4, 3, 9, 8, 9, -3, -2], lcl, ucl)
10-element Vector{Int64}:
 0
 0
 1
 1
 0
 1
 1
 1
 1
 1
"""
isoutside(x, lcl, ucl) = convert.(Union{Missing, Int}, (x .< lcl) .| (x .> ucl))

function statistical_process_control(y, baseline; λ, L)
    baseline_start = findfirst(baseline)

    if !isnothing(baseline_start)
        duration = count(baseline)

        # baseline mean
        μ̂ = @chain y[baseline] begin
            skipmissing
            mean
        end

        last_non_missing = findlast(!ismissing, y)

        # replace missings with baseline mean
        x = replace(y[1:last_non_missing], missing => μ̂)

        # calculate the EWMA for pre-baseline and baseline/post-baseline separately
        ewma = vcat(
            ewma_smooth(x[1:(baseline_start - 1)], λ, μ̂),
            ewma_smooth(x[baseline_start:end], λ, μ̂),
            repeat([missing], length(y) - last_non_missing)
        )

        lcl, ucl = control_limits(y[baseline_start:end], λ, L; baseline = 1:duration)

        # fill the pre-baseline with the first post-baseline limits (if available)
        first_post_baseline = min(duration + 1, duration)
        lcl = vcat(repeat([lcl[first_post_baseline]], baseline_start - 1), lcl)
        ucl = vcat(repeat([ucl[first_post_baseline]], baseline_start - 1), ucl)

        outside = isoutside(ewma, lcl, ucl)
    else
        ewma = lcl = ucl = outside = repeat([missing], length(y))
    end

    return [ewma lcl ucl outside]
end

function statistical_process_control(; λ, L)
    (y, baseline) -> statistical_process_control(y, baseline; λ, L)
end

function statistical_process_control(
        df::DataFrame, variables::AbstractVector{Symbol}; λ, L, duration = 28)
    inputs = map(x -> [x, :Baseline], variables)
    outputs = map(x -> Symbol.([x * suffix for suffix in ["EWMA", "LCL", "UCL", "OUT"]]),
        string.(variables))

    @chain df begin
        groupby(:Participant)
        transform(:State => determine_baseline(; duration) => :Baseline; ungroup = false)
        transform(inputs .=> statistical_process_control(; λ, L) .=> outputs)
    end
end