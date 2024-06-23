
df = d"biposense (ewma)"

df_phases = @chain df begin
    groupby(:Participant)
    transform(:State => determine_phases => :Phase; ungroup=false)
    transform(:Phase => enumerate_phases => :PhaseEnumeration)
end

participants = unique(df_phases.Participant)

grid = [(λ, L) for λ in 0.01:0.01:1, L in 0.1:0.1:5]

losses = Dict(
    "Accuracy" => accuracy,
    "Balanced Accuracy" => balanced_accuracy,
    "F1 Score" => f_beta_score,
    "F2 Score" => (ŷ, y) -> f_beta_score(ŷ, y; β=2),
    "Correlation" => Statistics.cor,
    "Cohen's Kappa" => cohens_kappa
)

metrics = Dict(
    "Accuracy" => accuracy,
    "Sensitivity" => sensitivity,
    "Specificity" => specificity,
    "Precision" => precision,
    "Balanced Accuracy" => balanced_accuracy,
    "F1 Score" => f_beta_score,
    "Correlation" => Statistics.cor,
    "Cohen's Kappa" => cohens_kappa
)

phase_types = filter(x -> x != "Euthymic", unique(df_phases.Phase))
depression_types = filter(x -> contains(x, "Depression"), phase_types)
mania_types = filter(x -> contains(x, "Mania"), phase_types)
prodromal_types = filter(x -> contains(x, "Prodromal"), phase_types)
episode_types = filter(x -> !contains(x, "Prodromal"), phase_types)

metric_keys = [keys(metrics)..., "Sensitivity" .* ["Overall", "Depression", "Mania", "Prodromal", "DepressionProdromal", "ManiaProdromal", "Episode", "DepressionEpisode", "ManiaEpisode", phase_types...]...]

df_results = DataFrame(
    :Variable => Symbol[], :Lambda => Float64[], :L => Float64[], :Loss => String[],
    (key => Float64[] for key in Symbol.(metric_keys))...
)


function precompute(df, variable)
    # symbol of the corresponding EWMA column
    ewma = Symbol(string(variable) * "_EWMA")

    # remove missings from the end
    df_filtered = filter(ewma => (x -> !ismissing(x)), df)

    df_optimization = @chain df_filtered begin
        groupby(:Participant)
        transform(
            [variable, :IsBaseline] => ((data, baseline) -> data[baseline] |> skipmissing |> mean) => :Mean,
            [variable, :IsBaseline] => ((data, baseline) -> data[baseline] |> skipmissing |> std) => :Std;
            ungroup=false
        )
        combine(
            [variable, :Mean] => ((x, μ̂) -> [replace(x, missing => first(μ̂))]) => :RawData, # replace missings with baseline mean
            :IsBaseline => findfirst => :BaselineStart,
            :Mean => first => :Mean, # baseline mean
            :Std => first => :Std, # baseline standard deviation
            :Phase => (x -> [Int.(x .!= "Euthymic")]) => :Y # ground truth
        )
    end

    y = vcat(df_optimization.Y...)

    return df_filtered, df_optimization, y
end

function classify(df, λ, L)
    start, μ̂, σ̂ = df.BaselineStart, df.Mean, df.Std

    # calculate the EWMA for pre-baseline and baseline + post-baseline separately
    ewma = vcat(
        ewma_smooth(df.RawData[1:start-1], λ, first(df.RawData)),
        ewma_smooth(df.RawData[start:end], λ, μ̂)
    )

    # calculate lower and upper control limits
    deviations = L * σ̂ * sqrt.(λ / (2 - λ) * [1 - (1 - λ)^(2 * i) for i in 1:length(df.RawData)-start+1])
    lcl = μ̂ .- deviations
    ucl = μ̂ .+ deviations

    # fill the pre-baseline with the first post-baseline limits
    lcl = vcat(repeat([lcl[29]], length(1:start-1)), lcl)
    ucl = vcat(repeat([ucl[29]], length(1:start-1)), ucl)

    # check if the EWMA is outside the limits and convert the results to integers
    return Int.((ewma .< lcl) .| (ewma .> ucl))
end

function classify(df, λ, lcl, ucl)
    start, μ̂ = df.BaselineStart, df.Mean

    # calculate the EWMA for pre-baseline and baseline + post-baseline separately
    ewma = vcat(
        ewma_smooth(df.RawData[1:start-1], λ, first(df.RawData)),
        ewma_smooth(df.RawData[start:end], λ, μ̂)
    )

    # check if the EWMA is outside the limits and convert the results to integers
    return Int.((ewma .< lcl) .| (ewma .> ucl))
end

# classify the days of each participant and concatenate the resulting vectors
predict(params, df) = vcat((classify(row, params...) for row in eachrow(df))...)

prediction_dataframe(df, ŷ) = hcat(DataFrame(:Ŷ => ŷ), select(df, :Participant, :Phase, :PhaseEnumeration))

function sensitivity(df::DataFrame)
    @chain df begin
        groupby([:Participant, :PhaseEnumeration])
        combine(:Ŷ => (x -> any(isequal(1), x)) => :Detected)
        mean(_.Detected)
    end
end

function sensitivity(df::DataFrame, cols)
    @chain df begin
        filter(:Phase => (x -> x in cols), _)
        sensitivity
    end
end

sensitivity_metrics(df) = (
    sensitivity(df, cols) for cols in [
        [prodromal_types..., episode_types...],
        depression_types,
        mania_types,
        prodromal_types,
        ["DepressionEarlyProdromal", "DepressionLateProdromal"],
        ["ManiaEarlyProdromal", "ManiaLateProdromal"],
        episode_types,
        ["DepressionFirstWeek", "DepressionSecondWeek", "DepressionOngoingWeeks"],
        ["ManiaFirstWeek", "ManiaSecondWeek", "ManiaOngoingWeeks"],
        ([type] for type in phase_types)...
    ]
)

evaluate(ŷ, y, df) = (f(ŷ, y) for f in values(metrics))..., sensitivity_metrics(df)...


for variable in VARIABLES
    df_filtered, df_optimization, y = precompute(df_phases, variable)

    for (name, loss) in losses
        # grid search
        result = argmax(params -> loss(predict(params, df_optimization), y), grid)

        # prediction of the best parameter combination
        ŷ = predict(result, df_optimization)

        df_prediction = prediction_dataframe(df_filtered, ŷ)

        # add a row to the results dataframe
        push!(df_results, [variable, result..., name, evaluate(ŷ, y, df_prediction)...])
    end

    # λ = 0.15, L = 2.536435
    ŷ = df_filtered[:, string(variable)*"_OUTSIDE"] |> skipmissing |> collect

    df_prediction = prediction_dataframe(df_filtered, ŷ)

    # add a row to the results dataframe
    push!(df_results, [variable, 0.15, 2.536435, "", evaluate(ŷ, y, df_prediction)...])
end

df_filtered, df_optimization, y = precompute(df_phases, :MoodFixedLimits)

# only optimize λ for Mood with static limits
for (name, loss) in losses
    # grid search
    result = argmax(λ -> loss(predict([λ, 40, 60], df_optimization), y), collect(0.01:0.01:1))

    # prediction of the best parameter combination
    ŷ = predict([result, 40, 60], df_optimization) |> skipmissing |> collect

    df_prediction = prediction_dataframe(df_filtered, ŷ)

    # add a row to the results dataframe
    push!(df_results, [:MoodFixedLimits, result, NaN, name, evaluate(ŷ, y, df_prediction)...])
end

ŷ = df_filtered.MoodFixedLimits_OUTSIDE |> skipmissing |> collect
df_prediction = prediction_dataframe(df_filtered, ŷ)

# add a row to the results dataframe
push!(df_results, [:MoodFixedLimits, 0.15, NaN, "", evaluate(ŷ, y, df_prediction)...])

ŷ = df_filtered.MoodFixedLimitsNoEWMA_OUTSIDE |> skipmissing |> collect
df_prediction = prediction_dataframe(df_filtered, ŷ)

# add a row to the results dataframe
push!(df_results, [:MoodFixedLimitsNoEWMA, NaN, NaN, "", evaluate(ŷ, y, df_prediction)...])


CSV.write("data/BipoSense_Optimization.csv", df_results)