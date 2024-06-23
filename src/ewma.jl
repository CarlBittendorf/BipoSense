
# exponentially weighted moving average (EWMA)
function ewma_smooth(y, λ, μ)
    N = length(y)

    # pre-allocate output vector
    z = zeros(N)

    # empty input vector
    N == 0 && return z

    z[1] = λ * first(y) + (1 - λ) * μ

    for i in 2:N
        z[i] = λ * y[i] + (1 - λ) * z[i-1]
    end

    return z
end


# calculate lower and upper control limits
function control_limits(variable, λ, L; baseline=1:28)
    μ̂ = variable[baseline] |> skipmissing |> mean
    σ̂ = variable[baseline] |> skipmissing |> std

    deviations = L * σ̂ * sqrt.(λ / (2 - λ) * [1 - (1 - λ)^(2 * i) for i in eachindex(variable)])

    lcl = μ̂ .- deviations
    ucl = μ̂ .+ deviations

    return lcl, ucl
end