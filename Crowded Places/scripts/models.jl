include("../startup.jl")

using AlgebraOfGraphics, CairoMakie

set_aog_theme!()

df = @chain d"BipoSense Crowded Places" begin
    groupby(:Participant)
    transform(:Date => enumerate_days => :Day)

    subset(:Day => ByRow(x -> x > 14))
end

variables = add_suffixes(
    [:MeanPopulationDensity, :MeanImperviousness, :MeanNDVI, :MeanGreenArea],
    ["LNVAR", "AVG"]
)

header_depression = ["", "DEP", "DLP", "DFW", "DSW", "DOW"]
header_mania = ["", "MEP", "MLP", "MFW", "MSW"]

models = fit_logit_models(df, variables)

analyze_models(
    "models/Models NatureExposure Depression.pdf", models[:, 1:5]; header = header_depression)
analyze_models(
    "models/Models NatureExposure Depression.csv", models[:, 1:5]; header = header_depression)
analyze_models(
    "models/Models NatureExposure Mania.pdf", models[:, 6:9]; header = header_mania)
analyze_models(
    "models/Models NatureExposure Mania.csv", models[:, 6:9]; header = header_mania)

draw_roc("figures/roc", df, models)

aucs = map(x -> ismissing(x) ? x : auc(df, x), models)
header = ["", "DEP", "DLP", "DFW", "DSW", "DOW", "MEP", "MLP", "MFW", "MSW"]

save_table("models/Models NatureExposure AUC.pdf", header, hcat(variables, aucs), "AUCs")

df_roc = vcat((
    begin
        false_positive_rate, true_positive_rate, _ = roc_curve(df, model)

        DataFrame(
            :Phase => phase,
            :Measure => measure,
            :FalsePositiveRate => false_positive_rate,
            :TruePositiveRate => true_positive_rate
        )
    end
for (model, phase, measure) in zip(
    vec(models[[3, 7], [1:4..., 6:9...]]),
    vec(repeat(
        ["Early Pre-Episode Depression", "Late Pre-Episode Depression",
            "First Week Depression", "Second Week Depression",
            "Early Pre-Episode (Hypo)Mania", "Late Pre-Episode (Hypo)Mania",
            "First Week (Hypo)Mania", "Second Week (Hypo)Mania"];
        inner = (2, 1))),
    vec(repeat(["LNVAR", "AVG"]; inner = (1, 8)))
)
)...)

for measure in ["LNVAR", "AVG"]
    figure = @chain df_roc begin
        subset(
            :Measure => ByRow(isequal(measure)),
            :Phase => ByRow(x -> contains(x, "Mania"))
        )
        draw(
            data(_) *
            mapping(
                :FalsePositiveRate => "False Positive Rate",
                :TruePositiveRate => "True Positive Rate";
                color = :Phase => presorted
            ) *
            visual(Lines) +
            data((; Polygon = [rectangle(0, 0.05, 0.5, 1)])) * mapping(:Polygon) *
            visual(Poly; color = (GREEN, 0.2));
            axis = (; width = 400, height = 400)
        )
    end

    save("figures/paper/ROC $measure.png", figure; px_per_unit = 3)
end