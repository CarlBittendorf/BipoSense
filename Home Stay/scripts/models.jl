include("../startup.jl")

using AlgebraOfGraphics, CairoMakie

set_aog_theme!()

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

subsets = [[1:9, 1:5], [1:9, 6:9], [10:18, 1:5], [10:18, 6:9], [19:27, 1:5], [19:27, 6:9]]

analyze_models("models/Models.pdf", models; subsets, header)
analyze_models("models/Models.csv", models; subsets, header)

models = vcat((
    fit_logit_models(subset(df, variable => ByRow(!isequal(0))), [variable])
for variable in [:FractionAtHomeAVG, :FractionAtHomeDayAVG, :FractionAtHomeNightAVG]
)...)

analyze_models("models/Never-Home Models.pdf", models; header)

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

df_figure = DataFrame()

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
        contrasts = Dict(:Phase => DummyCoding(; base = "Euthymia"))
    )

    df_means = @chain model begin
        emmeans

        select(:Phase, variable)
        transform(All() => ByRow((x...) -> variable) => :Variable)
        rename(variable => :EstimatedMean)
    end

    df_figure = vcat(df_figure, df_means)
end

df_bars = @chain df_figure begin
    subset(:Phase => ByRow(!isequal("Euthymia")))
    transform(:Phase => (x -> Common._determine_colors(x, POLYGON_COLORS)) => :Color)
    transform(
        :Phase => (x -> replace(x,
            "DepressionEarlyProdromal" => "DEP",
            "DepressionLateProdromal" => "DLP",
            "DepressionFirstWeek" => "DFW",
            "DepressionSecondWeek" => "DSW",
            "DepressionOngoingWeeks" => "DOW",
            "ManiaEarlyProdromal" => "MEP",
            "ManiaLateProdromal" => "MLP",
            "ManiaFirstWeek" => "MFW",
            "ManiaSecondWeek" => "MSW"
        ));
        renamecols = false
    )
    sort(
        :Phase;
        by = x -> findfirst(
            isequal(x),
            ["DEP", "DLP", "DFW", "DSW", "DOW", "MEP", "MLP", "MFW", "MSW"]
        )
    )
end

df_hlines = @chain df_figure begin
    subset(:Phase => ByRow(isequal("Euthymia")))
end

figure = draw(
    data(df_bars) *
    mapping(
        :Phase => presorted, :EstimatedMean;
        color = :Color => verbatim, row = :Variable => presorted
    ) *
    visual(BarPlot) +
    data(df_hlines) * mapping(:EstimatedMean; row = :Variable => presorted) *
    visual(HLines; linestyle = :dash, color = (GRAY, 0.5));
    facet = (; linkyaxes = :none),
    axis = (; width = 800, height = 250)
)

save("figures/paper/Estimated Means.png", figure; px_per_unit = 3)