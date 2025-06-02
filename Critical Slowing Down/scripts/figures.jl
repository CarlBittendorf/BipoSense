include("../startup.jl")

using AlgebraOfGraphics

set_aog_theme!()

df = d"BipoSense Critical Slowing Down"

variables = add_suffixes(VARIABLES, ["AR", "LNVAR", "AVG"])

draw_timeseries("figures/timeseries", df, variables)