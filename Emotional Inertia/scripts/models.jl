include("../startup.jl")

using AlgebraOfGraphics, CairoMakie, GeometryBasics

set_aog_theme!()

df = @chain d"BipoSense Emotional Inertia" begin
    groupby(:Participant)
    transform(:Date => enumerate_days => :Day)

    subset(:Day => ByRow(x -> x > 14))
end

variables = add_suffixes(VARIABLES, ["AR", "AVG"])
phases = ["DepressionFirstWeek", "DepressionSecondWeek", "DepressionOngoingWeeks",
    "ManiaFirstWeek", "ManiaSecondWeek", "ManiaOngoingWeeks"]
header = ["", "DFW", "DSW", "DOW", "MFW", "MSW", "MOW"]

models = fit_logit_models(df, variables; phases)

# adjust p values for depression and mania, as well as for autocorrelation and average separately
subsets = [[1:20, 1:3], [1:20, 4:6], [21:40, 1:3], [21:40, 4:6]]

analyze_models("models/Models.pdf", models; subsets, header)
analyze_models("models/Models.csv", models; subsets, header)

double_variables = [[variables[i], variables[i + 20]] for i in 1:20]

models = fit_logit_models(df, double_variables; phases)

analyze_models("models/Double Models.pdf", models; header)