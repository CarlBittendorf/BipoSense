include("../startup.jl")

using AlgebraOfGraphics

set_aog_theme!()

spc_variables = add_suffixes(VARIABLES, ["OUT"])
dst_variables = add_suffixes(VARIABLES, ["AR", "LNVAR", "AVG"])

df = @chain d"BipoSense Crowded Places" begin
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

analyze_models("models/Models.pdf", models; header)

draw_roc("figures/roc", df, models[11:40, :])

aucs = map(x -> ismissing(x) ? x : auc(df, x), models[11:40, :])

save_table("models/Models AUC.pdf", header, hcat(variables[11:40], aucs), "AUCs")