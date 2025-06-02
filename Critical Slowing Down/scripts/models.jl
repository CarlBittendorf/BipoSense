include("../startup.jl")

using AlgebraOfGraphics, CairoMakie

set_aog_theme!()

df = @chain d"BipoSense Critical Slowing Down" begin
    groupby(:Participant)
    transform(:Date => enumerate_days => :Day)

    subset(:Day => ByRow(x -> x > 14))
end

variables = add_suffixes(VARIABLES, ["AR", "LNVAR", "AVG"])
phases = ["DepressionEarlyProdromal", "DepressionLateProdromal",
    "ManiaEarlyProdromal", "ManiaLateProdromal"]

models = fit_logit_models(df, variables; phases)

# adjust p values for depression and mania, as well as for autocorrelation, variance and average separately
subsets = [[1:20, 1:2], [1:20, 3:4], [21:40, 1:2], [21:40, 3:4], [41:60, 1:2], [41:60, 3:4]]

analyze_models("models/Models.pdf", models; subsets)

draw_roc("figures/roc", df, models)

aucs = map(x -> ismissing(x) ? x : auc(df, x), models)
header = ["", phases...]

save_table("models/Models AUC.pdf", header, hcat(variables, aucs), "AUCs")

df_roc = vcat((
    begin
        false_positive_rate, true_positive_rate, _ = roc_curve(df, model)

        DataFrame(
            :Phase => phase,
            :Variable => variable,
            :Measure => measure,
            :FalsePositiveRate => false_positive_rate,
            :TruePositiveRate => true_positive_rate
        )
    end
for (model, phase, variable, measure) in zip(
    vec(models[[18:20..., 38:40..., 58:60...], :]),
    vec(repeat(
        ["Early Pre-Episode Depression", "Late Pre-Episode Depression",
            "Early Pre-Episode (Hypo)Mania", "Late Pre-Episode (Hypo)Mania"];
        inner = 9)),
    vec(repeat(["Communication", "Active", "Sleep"], 3, 4)),
    vec(repeat(["AR", "VAR", "AVG"]; inner = (3, 4)))
)
)...)

figure = draw(
    data(df_roc) *
    mapping(
        :FalsePositiveRate => "False Positive Rate",
        :TruePositiveRate => "True Positive Rate";
        color = :Variable => presorted, linestyle = :Measure => presorted, layout = :Phase => presorted) *
    visual(Lines) +
    data((; Polygon = [rectangle(0, 0.05, 0.5, 1)])) * mapping(:Polygon) *
    visual(Poly; color = (GREEN, 0.2)),
    scales(Color = (; palette = [BLUE, ORANGE, RED]));
    axis = (width = 200, height = 200)
)

save("figures/paper/ROC Latent Variables.png", figure; px_per_unit = 3)

# sensitivity analysis using dimensional outcomes
df_dimensional = @chain df begin
    leftjoin(d"BipoSense Dimensional Ratings"; on = [:Participant, :Date])
    sort([:Participant, :Date])
    transform(:Participant => ByRow(string); renamecols = false)

    groupby(:Participant)
    transform(:State => label_phases => :Phase)

    groupby(:Participant)
    transform(
        # use MADRS and YMRS scores for the previous 13 days
        [:YMRSTotalScore, :MADRSTotalScore] .=>
            (x -> [coalesce(x[i:min(i + 13, length(x))]...) for i in eachindex(x)]);
        renamecols = false
    )
end

scores = [:YMRSTotalScore, :MADRSTotalScore]

models = repeat(
    Union{LinearMixedModel{Float64}, Missing}[missing],
    length(variables),
    length(scores)
)

for (i, variable) in enumerate(variables)
    df_variable = @chain df_dimensional begin
        select(:Participant, scores..., variable)
        dropmissing
    end

    for (j, score) in enumerate(scores)
        formula = (term(score) ~ term(1) + term(variable) +
                                 (term(1) | term(:Participant)))

        try
            models[i, j] = fit(MixedModel, formula, df_variable)
        catch e
            @warn "Error for $variable:" e
        end
    end
end

analyze_models("models/Dimensional Models.pdf", models)

# sensitivity analysis using a 7-day moving average (instead of 14 days)
variables = add_suffixes(VARIABLES, ["AVG7"])
models = fit_logit_models(df, variables; phases)

analyze_models("models/Models 7-day Average.pdf", models)

# sensitivity analysis using absolute autocorrelation
variables = add_suffixes(VARIABLES, ["ABSAR"])
df_abs = transform(df, add_suffixes(VARIABLES, ["AR"]) .=> ByRow(abs) .=> variables)

models = fit_logit_models(df_abs, variables; phases)

analyze_models("models/Models Absolute Autocorrelation.pdf", models)

# sensitivity analysis using only symptom-free euthymic days
df_super_euthymic = d"BipoSense Critical Slowing Down (super-euthymic)"
variables = add_suffixes(VARIABLES, ["AR", "LNVAR", "AVG"])

models = fit_logit_models(df, variables; phases)

analyze_models("models/Super-Euthymic Models.pdf", models; subsets)