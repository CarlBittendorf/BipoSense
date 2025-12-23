include("../startup.jl")

dst_variables = add_suffixes(VARIABLES, ["AR", "LNVAR", "AVG"])

df = @chain d"BipoSense Home Stay" begin
    groupby(:Participant)
    transform(:Date => enumerate_days => :Day)

    transform(map(x -> [x, :Day], dst_variables) .=>
        ByRow((x, d) -> d <= 14 ? missing : x) .=> dst_variables)
end

variables = add_suffixes(VARIABLES, ["AR", "LNVAR", "AVG"])
header = ["", "DEP", "DLP", "DFW", "DSW", "DOW", "MEP", "MLP", "MFW", "MSW"]

models = fit_logit_models(df, variables)

subsets = [[1:9, 1:5], [1:9, 6:9], [10:18, 1:5], [10:18, 6:9],
    [19:27, 1:5], [19:27, 6:9]]

analyze_models("models/Models.pdf", models; subsets, header)
analyze_models("models/Models.csv", models; subsets, header)

subsets = [[1:9, 1:2], [1:9, 3:5], [1:9, 6:7], [1:9, 8:9], [10:18, 1:2], [10:18, 3:5],
    [10:18, 6:7], [10:18, 8:9], [19:27, 1:2], [19:27, 3:5], [19:27, 6:7], [19:27, 8:9]]

analyze_models("models/Models Soft Correction.pdf", models; subsets, header)
analyze_models("models/Models Soft Correction.csv", models; subsets, header)

draw_roc("figures/roc", df, models)

aucs = map(x -> ismissing(x) ? x : auc(df, x), models)

save_table("models/Models AUC.pdf", header, hcat(variables, aucs), "AUCs")

models = vcat((
    fit_logit_models(subset(df, variable => ByRow(!isequal(0))), [variable])
for variable in [:FractionAtHomeAVG, :FractionAtHomeDayAVG, :FractionAtHomeNightAVG]
)...)

analyze_models("models/Never-Home Models.pdf", models; header)

models = fit_logit_models(
    df,
    [
        [:FractionAtHomeAVG, :FractionAtHomeLNVAR],
        [:FractionAtHomeDayAVG, :FractionAtHomeDayLNVAR],
        [:FractionAtHomeNightAVG, :FractionAtHomeNightLNVAR]
    ]
)

analyze_models("models/Double Models.pdf", models; header)

avg_variables = add_suffixes(VARIABLES, ["AVG"])

for variable in avg_variables
    df_model = @chain df begin
        transform(:Participant => ByRow(string); renamecols = false)

        groupby(:Participant)
        transform(:State => label_phases => :Phase)

        subset(:Phase => ByRow(!isequal("ManiaOngoingWeeks")))
    end

    df_variable = @chain df_model begin
        select(:Participant, :Phase, variable)
        dropmissing
    end

    formula = (term(variable) ~ term(0) + term(:Phase) + (term(1) | term(:Participant)))

    model = fit(
        MixedModel, formula, df_variable;
        contrasts = Dict(:Phase => EffectsCoding(; base = "Euthymia"))
    )

    df_means = emmeans(model)

    df_p_values = @chain model begin
        empairs(; dof = dof_residual)
        subset(:Phase => ByRow(contains("Euthymia")))
        transform(
            :Phase => ByRow(x -> replace(x, "Euthymia" => "", " > " => ""));
            renamecols = false
        )
        select("Phase", "Pr(>|t|)")
    end

    df_summary = leftjoin(df_means, df_p_values; on = :Phase)

    save_table("models/Reverse Models " * string(variable) * ".pdf",
        ["Phase", "Mean", "SE", "Pr(>|t|)"], Matrix(df_summary), string(variable))
end