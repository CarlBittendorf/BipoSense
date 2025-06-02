include("../startup.jl")

using AlgebraOfGraphics

set_aog_theme!()

df = d"BipoSense Passive Sensing"

df_optimization = optimize_spc(df, VARIABLES[1:18])

save_table("models/Optimization.pdf", names(df_optimization)[1:10],
    Matrix(df_optimization)[:, 1:10], "Optimization Results")

colors = [
    "KilometersFast" => BLUE,
    "IncomingMissedCalls" => ORANGE,
    "UniqueConversationPartners" => PURPLE,
    "MinutesDisplayOn" => LIGHTBLUE,
    "MinutesPhoneInactive" => RED,
    "Others" => GRAY
]

draw_optimization("figures/paper", df_optimization; colors)

# optimization allowing for λ > 1
df_optimization = optimize_spc(df, VARIABLES[1:18];
    grid = [(λ, L) for λ in [0.1:0.1:1.9..., 2.1:0.1:3...], L in 0.1:0.1:5])

save_table("models/Optimization Test.pdf", names(df_optimization)[1:10],
    Matrix(df_optimization)[:, 1:10], "Optimization Results")