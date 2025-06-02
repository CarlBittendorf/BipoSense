include("../startup.jl")

using AlgebraOfGraphics, CairoMakie

set_aog_theme!()

df = @chain d"BipoSense Ground Truth" begin
    leftjoin(d"BipoSense Dimensional Ratings"; on = [:Participant, :Date])
    sort([:Participant, :Date])
    select(:Participant, :Date, :State, :YMRSTotalScore,
        :BRMRSTotalScore, :MADRSTotalScore, :CGISeverityBipolar)

    groupby(:Participant)
    transform(
        :State => (x -> replace(x, "Hypomania" => "Mania", "Mixed" => missing)),
        [:YMRSTotalScore, :BRMRSTotalScore, :MADRSTotalScore, :CGISeverityBipolar] .=>
            (x -> [coalesce(x[i:min(i + 13, length(x))]...) for i in eachindex(x)]);
        renamecols = false, ungroup = false
    )
    transform(:State => label_phases => :Phase)

    dropmissing
end

for variable in [:YMRSTotalScore, :BRMRSTotalScore, :MADRSTotalScore, :CGISeverityBipolar]
    states = ["Euthymia", "Depression", "Mania"]
    figure = draw(
        data(df) *
        mapping(
            variable;
            color = :State => sorter(states),
            row = :State => sorter(states)
        ) *
        histogram(; normalization = :pdf),
        scales(Color = (; palette = [GREEN, BLUE, ORANGE]))
    )

    save(joinpath("figures/ratings", string(variable) * " States.png"),
        figure; px_per_unit = 3)
end

for variable in [:YMRSTotalScore, :BRMRSTotalScore, :MADRSTotalScore, :CGISeverityBipolar]
    for (phases, palette, label) in zip(
        [
            ["Euthymia", "DepressionEarlyProdromal", "DepressionLateProdromal",
                "DepressionFirstWeek", "DepressionSecondWeek", "DepressionOngoingWeeks"],
            ["Euthymia", "ManiaEarlyProdromal", "ManiaLateProdromal",
                "ManiaFirstWeek", "ManiaSecondWeek", "ManiaOngoingWeeks"]
        ],
        [
            [GREEN, LIGHTBLUE, LIGHTBLUE, BLUE, BLUE, BLUE],
            [GREEN, YELLOW, YELLOW, ORANGE, ORANGE, ORANGE]
        ],
        ["Depression", "Mania"]
    )
        figure = draw(
            data(subset(df, :Phase => ByRow(x -> x in phases))) *
            mapping(
                variable;
                color = :Phase => sorter(phases),
                row = :Phase => sorter(phases)
            ) *
            histogram(; normalization = :pdf),
            scales(Color = (; palette));
            axis = (width = 300, height = 160)
        )

        save(joinpath("figures/ratings", string(variable) * " Phases " * label * ".png"),
            figure; px_per_unit = 3)
    end
end