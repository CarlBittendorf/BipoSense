include("../src/plot.jl")


df = d"biposense (ewma)"
participants = unique(df.Participant)
groups = [participants[1:10], participants[11:19], participants[20:28]]


for (i, group) in enumerate(groups)
    df_group = subset(df, :Participant => ByRow(x -> x in group))

    for variable in [VARIABLES..., :MoodFixedLimits]
        # construct column names
        ewma, lcl, ucl, outside = (Symbol(string(variable) * suffix) for suffix in ["_EWMA", "_LCL", "_UCL", "_OUTSIDE"])

        figure = draw_spc(df_group, variable, ewma, lcl, ucl, outside)

        save("plots/" * string(variable) * "_" * string(i) * ".png", figure, px_per_unit=3)
    end

    figure = draw_spc(df_group, :Mood, :MoodFixedLimitsNoEWMA, :MoodFixedLimits_LCL, :MoodFixedLimits_UCL, :MoodFixedLimitsNoEWMA_OUTSIDE)

    save("plots/MoodFixedLimitsNoEWMA_" * string(i) * ".png", figure, px_per_unit=3)
end