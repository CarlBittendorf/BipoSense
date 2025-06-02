
# 1. Exports
# 2. Helper Functions
# 3. Implementations

####################################################################################################
# EXPORTS
####################################################################################################

export optimize_spc

####################################################################################################
# HELPER FUNCTIONS
####################################################################################################

# classify the days of each participant
function _predict_spc(df, ys, baselines, λ, L)
    df_prediction = @chain begin
        vcat((statistical_process_control(y, baseline; λ, L)[:, 4]
        for (y, baseline) in zip(ys, baselines))...)

        DataFrame(:Ŷ => _)
        hcat(df)
        dropmissing
        subset(:Phase => ByRow(!isequal("Baseline")))

        groupby([:Participant, :Phase, :PhaseIndex])
        combine(
            [:Phase, :Ŷ] => ((p, ŷ) -> first(p) == "Euthymia" ? ŷ : [any(isequal(1), ŷ) ? 1 : 0]) => :Ŷ,
            :Phase => (p -> first(p) == "Euthymia" ? p : [first(p)]) => :Phase
        )
    end

    return df_prediction.Ŷ, Int.(df_prediction.Phase .!= "Euthymia"), df_prediction.Phase
end

DEPRESSION_PRODROMAL_TYPES = ["DepressionEarlyProdromal", "DepressionLateProdromal"]
MANIA_PRODROMAL_TYPES = ["ManiaEarlyProdromal", "ManiaLateProdromal"]
PRODROMAL_TYPES = vcat(DEPRESSION_PRODROMAL_TYPES, MANIA_PRODROMAL_TYPES)
DEPRESSION_EPISODE_TYPES = [
    "DepressionFirstWeek", "DepressionSecondWeek", "DepressionOngoingWeeks"]
MANIA_EPISODE_TYPES = ["ManiaFirstWeek", "ManiaSecondWeek", "ManiaOngoingWeeks"]
EPISODE_TYPES = vcat(DEPRESSION_EPISODE_TYPES, MANIA_EPISODE_TYPES)

####################################################################################################
# IMPLEMENTATIONS
####################################################################################################

function optimize_spc(df::DataFrame, variables::AbstractVector{Symbol};
        facet = :Participant,
        losses = [
            "Accuracy" => (ŷ, y, _) -> accuracy(ŷ, y),
            "BalancedAccuracy" => (ŷ, y, _) -> balanced_accuracy(ŷ, y),
            "F1Score" => (ŷ, y, _) -> FScore(; levels = [0, 1])(ŷ, y),
            "F2Score" => (ŷ, y, _) -> FScore(; beta = 2, levels = [0, 1])(ŷ, y),
            "Correlation" => (ŷ, y, _) -> cor(ŷ, y),
            "Kappa" => (ŷ, y, _) -> kappa(ŷ, y)
        ],
        metrics = [
            "F1Score" => (ŷ, y, _) -> FScore(; levels = [0, 1])(ŷ, y),
            "Correlation" => (ŷ, y, _) -> cor(ŷ, y),
            "Kappa" => (ŷ, y, _) -> kappa(ŷ, y),
            "Sensitivity" => (ŷ, y, _) -> TruePositiveRate(; levels = [0, 1])(ŷ, y),
            "Specificity" => (ŷ, y, _) -> TrueNegativeRate(; levels = [0, 1])(ŷ, y),
            "Precision" => (ŷ, y, _) -> PositivePredictiveValue(; levels = [0, 1])(ŷ, y),
            "Accuracy" => (ŷ, y, _) -> accuracy(ŷ, y),
            "BalancedAccuracy" => (ŷ, y, _) -> balanced_accuracy(ŷ, y),
            "SensitivityProdromal" => (ŷ, y, p) -> TruePositiveRate(; levels = [0, 1])(
                ŷ[map(x -> x in PRODROMAL_TYPES, p)], y[map(x -> x in PRODROMAL_TYPES, p)]),
            "SensitivityEpisode" => (ŷ, y, p) -> TruePositiveRate(; levels = [0, 1])(
                ŷ[map(x -> x in EPISODE_TYPES, p)], y[map(x -> x in EPISODE_TYPES, p)]),
            "SensitivityDepressionProdromal" => (ŷ, y, p) -> TruePositiveRate(;
                levels = [0, 1])(
                ŷ[map(x -> x in DEPRESSION_PRODROMAL_TYPES, p)],
                y[map(x -> x in DEPRESSION_PRODROMAL_TYPES, p)]),
            "SensitivityManiaProdromal" => (ŷ, y, p) -> TruePositiveRate(; levels = [0, 1])(
                ŷ[map(x -> x in MANIA_PRODROMAL_TYPES, p)],
                y[map(x -> x in MANIA_PRODROMAL_TYPES, p)]),
            "SensitivityDepressionEpisode" => (ŷ, y, p) -> TruePositiveRate(;
                levels = [0, 1])(
                ŷ[map(x -> x in DEPRESSION_EPISODE_TYPES, p)],
                y[map(x -> x in DEPRESSION_EPISODE_TYPES, p)]),
            "SensitivityManiaEpisode" => (ŷ, y, p) -> TruePositiveRate(; levels = [0, 1])(
                ŷ[map(x -> x in MANIA_EPISODE_TYPES, p)],
                y[map(x -> x in MANIA_EPISODE_TYPES, p)])
        ],
        grid = [(λ, L) for λ in 0.01:0.01:1, L in 0.1:0.1:5]
)
    df_base = _make_base_dataframe(df, facet)
    df_phases = select(df_base, :Participant, :Phase, :PhaseIndex)

    df_grouped = @chain df_base begin
        groupby(facet)
        combine([:Baseline, :Phase, variables...] .=>
            (x -> [x]) .=> [:Baseline, :Phase, variables...])
    end

    baselines = df_grouped.Baseline

    df_results = DataFrame(
        :Variable => Symbol[],
        :Lambda => Float64[],
        :L => Float64[],
        :Loss => String[],
        (Symbol(key) => Float64[] for key in first.(metrics))...
    )

    for variable in variables
        data = getproperty(df_grouped, variable)

        for (key, loss) in losses
            # grid search
            λ, L = argmax(
                x -> loss(_predict_spc(df_phases, data, baselines, x...)...),
                grid
            )

            # the prediction of the best parameter combination
            ŷ, y, phases = _predict_spc(df_phases, data, baselines, λ, L)

            results = map(metric -> metric(ŷ, y, phases), last.(metrics))

            # add a row to the results dataframe
            push!(df_results, [variable, λ, L, key, results...])
        end
    end

    return df_results
end