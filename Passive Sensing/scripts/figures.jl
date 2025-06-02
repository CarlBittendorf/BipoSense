include("../startup.jl")

using AlgebraOfGraphics

set_aog_theme!()

df = d"BipoSense Passive Sensing"

draw_spc("figures/spc", df, VARIABLES)
draw_spc("figures/paper", df, 7969, :KilometersFast)
draw_spc("figures/paper", df, 7969, VARIABLES)