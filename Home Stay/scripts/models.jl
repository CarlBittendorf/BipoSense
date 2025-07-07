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

subsets = [[1:6, 1:5], [1:6, 6:9], [7:12, 1:5], [7:12, 6:9], [13:18, 1:5],
    [13:18, 6:9], [19:24, 1:5], [19:24, 6:9], [25:30, 1:5], [25:30, 6:9]]

analyze_models("models/Models.pdf", models; subsets, header)

draw_roc("figures/roc", df, models[7:30, :])

aucs = map(x -> ismissing(x) ? x : auc(df, x), models[7:30, :])

save_table("models/Models AUC.pdf", header, hcat(variables[7:30, :], aucs), "AUCs")