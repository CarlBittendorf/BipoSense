include("../src/plot.jl")


df = d"biposense (ewma)"
participant = "7969"


# a single variable for a single participant
df_participant = subset(df, :Participant => (x -> x .== participant))

# construct column names
variable = :KilometersFast
ewma, lcl, ucl, outside = (Symbol(string(variable) * suffix) for suffix in ["_EWMA", "_LCL", "_UCL", "_OUTSIDE"])

figure = draw_spc(df_participant, variable, ewma, lcl, ucl, outside, layout=[(1, 1)])

save("plots/" * string(variable) * "_" * participant * ".png", figure, px_per_unit=3)


# multiple variables for a single participant
variables = [VARIABLES..., :MoodFixedLimits, :MoodFixedLimitsNoEWMA]

df_participant = @chain df begin
    subset(:Participant => (x -> x .== participant))
    transform(
        :Mood => identity => :MoodFixedLimitsNoEWMA,
        [:Mood, :IsBaseline] => ((x, b) -> replace(x, missing => mean(skipmissing(x[b])))) => :MoodFixedLimitsNoEWMA_EWMA,
        :MoodFixedLimits_LCL => identity => :MoodFixedLimitsNoEWMA_LCL,
        :MoodFixedLimits_UCL => identity => :MoodFixedLimitsNoEWMA_UCL
    )
end

# the plot is facetted by variable, so we need to stack the raw data, EWMAs, limits etc.
df_raw = @chain df_participant begin
    stack(variables)
    rename(:variable => :Variable, :value => :Raw)
    select(:Date, :Day, :IsBaseline, :State, :Variable, :Raw)
end

df_ewma, df_lcl, df_ucl, df_outside = (
    (@chain df_participant begin
        stack([string(x) * "_" * string(col) for x in variables])
        rename(:variable => :Variable, :value => col)
        transform(:Variable => ByRow(x -> first(split(x, "_"))); renamecols=false)
        select(:Day, :Variable, col)
    end) for col in [:EWMA, :UCL, :LCL, :OUTSIDE]
)

df_stacked = outerjoin(df_raw, df_ewma, df_lcl, df_ucl, df_outside; on=[:Variable, :Day])

layout_sorter = sorter([string.(VARIABLES)..., "MoodFixedLimits", "MoodFixedLimitsNoEWMA"])

figure = draw_spc(
    df_stacked, :Raw, :EWMA, :LCL, :UCL, :OUTSIDE;
    layout=reshape([(y, x) for x in 1:4, y in 1:5], :), facet=:Variable, layout_sorter, ylabel=""
)

save("plots/" * participant * ".png", figure, px_per_unit=3)