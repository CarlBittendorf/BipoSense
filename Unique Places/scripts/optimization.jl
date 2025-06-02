include("../startup.jl")

using AlgebraOfGraphics, CairoMakie

set_aog_theme!()

df = d"BipoSense Unique Places"

df_optimization = optimize_spc(df, VARIABLES)

save_table("models/Optimization.pdf", names(df_optimization)[1:10],
    Matrix(df_optimization)[:, 1:10], "Optimization Results")

draw_optimization("figures/paper", df_optimization)