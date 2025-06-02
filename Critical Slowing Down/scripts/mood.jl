include("../startup.jl")

using AlgebraOfGraphics, CairoMakie

set_aog_theme!()

df = @chain d"BipoSense Forms" begin
    transform(:FormTrigger => ByRow(Date) => :Date,)

    leftjoin(d"BipoSense Ground Truth"; on = [:Participant, :Date])
    transform(
        :State => (x -> replace(x, "Hypomania" => "Mania", "Mixed" => missing));
        renamecols = false
    )
    sort([:Participant, :Date])

    groupby(:Participant)
    transform(:State => label_phases => :Phase)

    transform(
        :Phase => enumerate_phases => :PhaseIndex,
        :Phase => enumerate_prodromal_days => :Day
    )

    dropmissing([:State, :ManicDepressiveMood])
    subset(:Phase => ByRow(endswith("Prodromal")))
    transform(:Phase => ByRow(x -> first(split(x, r"(?=[A-Z])"))) => :Type)
end

figure = draw(
    data(df) *
    mapping(:Day, :ManicDepressiveMood;
        col = :Type => sorter(["Depression", "Mania"]),
        color = :Type => sorter(["Depression", "Mania"]),
        group = :PhaseIndex => nonnumeric
    ) *
    visual(Lines),
    scales(Color = (; palette = [BLUE, ORANGE]));
    axis = (width = 500, height = 300, xticks = 1:14)
)

save("figures/mood/Prodromal Mood.png", figure; px_per_unit = 3)