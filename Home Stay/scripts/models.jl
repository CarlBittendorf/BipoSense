include("../startup.jl")

spc_variables = add_suffixes(VARIABLES, ["OUT"])
dst_variables = add_suffixes(VARIABLES, ["AR", "LNVAR", "AVG"])

df = @chain d"BipoSense Home Stay" begin
    groupby(:Participant)
    transform(
        :State => determine_baseline => :Baseline,
        :Date => enumerate_days => :Day
    )

    # remove the baseline as the algorithm was "trained" on it
    transform(
        map(x -> [x, :Baseline], spc_variables) .=>
            ByRow((x, b) -> b ? missing : x) .=> spc_variables,
        map(x -> [x, :Day], dst_variables) .=>
            ByRow((x, d) -> d <= 14 ? missing : x) .=> dst_variables
    )
end

variables = add_suffixes(VARIABLES, ["OUT", "AR", "LNVAR", "AVG", "AVG7"])
header = ["", "DEP", "DLP", "DFW", "DSW", "DOW", "MEP", "MLP", "MFW", "MSW"]

models = fit_logit_models(df, variables)

subsets = [[1:7, 1:5], [1:7, 6:9], [8:14, 1:5], [8:14, 6:9], [15:21, 1:5],
    [15:21, 6:9], [22:28, 1:5], [22:28, 6:9], [29:35, 1:5], [29:35, 6:9]]

analyze_models("models/Models.pdf", models; subsets, header)
analyze_models("models/Models.csv", models; subsets, header)

draw_roc("figures/roc", df, models[8:35, :])

aucs = map(x -> ismissing(x) ? x : auc(df, x), models[8:35, :])

save_table("models/Models AUC.pdf", header, hcat(variables[8:35, :], aucs), "AUCs")