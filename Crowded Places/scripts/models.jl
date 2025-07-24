include("../startup.jl")

using AlgebraOfGraphics

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