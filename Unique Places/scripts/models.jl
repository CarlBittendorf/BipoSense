include("../startup.jl")

using AlgebraOfGraphics

set_aog_theme!()

spc_variables = add_suffixes(VARIABLES, ["OUT"])
dst_variables = add_suffixes(VARIABLES, ["AR", "LNVAR", "AVG"])

df = @chain d"BipoSense Unique Places" begin
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

variables = add_suffixes(VARIABLES, ["OUT", "AR", "LNVAR", "AVG"])
header = ["", "DEP", "DLP", "DFW", "DSW", "DOW", "MEP", "MLP", "MFW", "MSW"]

models = fit_logit_models(df, variables)

# adjust p values for depression and mania, as well as for SPC and DST separately
subsets = [[1:3, 1:5], [1:3, 6:9], [4:12, 1:5], [4:12, 6:9]]

analyze_models("models/Models.pdf", models; header, subsets)

draw_roc("figures/roc", df, models[4:12, :])

aucs = map(x -> ismissing(x) ? x : auc(df, x), models[4:12, :])

save_table("models/Models AUC.pdf", header, hcat(variables[4:12, :], aucs), "AUCs")