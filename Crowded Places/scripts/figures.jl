include("../startup.jl")

using AlgebraOfGraphics

set_aog_theme!()

df = d"BipoSense Crowded Places"

draw_spc("figures/spc", df, VARIABLES)

draw_timeseries("figures/timeseries", df,
    add_suffixes(VARIABLES, ["AR", "LNVAR", "AVG"]))