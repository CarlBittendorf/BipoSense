include("../startup.jl")

using AlgebraOfGraphics, CairoMakie

set_aog_theme!()

df = d"BipoSense Home Stay"

draw_spc("figures/spc", df, VARIABLES)

draw_timeseries("figures/timeseries", df,
    add_suffixes(VARIABLES, ["AR", "LNVAR", "AVG", "AVG7"]))

draw_timeseries("figures/timeseries", df, [:MedianLocationConfidence])

variables = add_suffixes(VARIABLES, ["LNVAR", "VAR", "AVG"])

for variable in variables
    df_variable = dropmissing(df, variable)

    figure = draw(
        data(df_variable) * mapping(variable => "") * visual(Hist);
        axis = (; title = string(variable), ylabel = "Count")
    )

    save("figures/histograms/" * string(variable) * ".png", figure; px_per_unit = 3)
end