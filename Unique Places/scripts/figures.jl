include("../startup.jl")

using AlgebraOfGraphics

set_aog_theme!()

df = d"BipoSense Unique Places"

draw_spc("figures/spc", df, VARIABLES)

draw_spc("figures/paper", df, 4289, :MedianTimeAtCluster)
draw_spc("figures/paper", df, 5768, :MedianTimeAtCluster)

draw_spc("figures/paper", df, 4289, VARIABLES)
draw_spc("figures/paper", df, 5768, VARIABLES)

variables = add_suffixes(VARIABLES, ["AR", "LNVAR", "AVG"])

draw_timeseries("figures/timeseries", df, variables)