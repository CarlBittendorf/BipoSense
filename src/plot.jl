using AlgebraOfGraphics, CairoMakie, GeometryBasics, Colors


set_aog_theme!()

const PALETTE = AlgebraOfGraphics.aog_theme().palette.color;
const GRAY = parse(RGB{Float64}, "gray25");
const BLUE, ORANGE, GREEN, PURPLE, LIGHTBLUE, RED, YELLOW = PALETTE;


make_points(xs, ys) = [GeometryBasics.Point(x, y) for (x, y) in zip(xs, ys)]


make_polygon(xs, ys1, ys2) =
    GeometryBasics.Polygon([make_points(xs, ys1)..., reverse(make_points(xs, ys2))...])


function make_geometries(df, col, isphase::Function)
    geometries = GeometryBasics.Polygon[]
    labels = String[]

    for label in unique(df[:, col])
        df_label = subset(df, col => ByRow(isequal(label)))

        mins = repeat([first(df_label.Min)], 2)
        maxs = repeat([first(df_label.Max)], 2)

        phases = df_label.Day[isphase(df_label)]
        polygons = [make_polygon([day - 0.5, day + 0.5], mins, maxs) for day in phases]
        push!(geometries, polygons...)
        push!(labels, repeat([label], length(phases))...)
    end

    df = DataFrame(:Geometries => geometries, col => labels)

    return df
end


function draw_spc(
    df, raw, ewma, lcl, ucl, outside;
    layout=reshape([(y, x) for x in 1:2, y in 1:5], :), facet=:Participant, layout_sorter=sorter(unique(df[:, facet])), ylabel=string(raw)
)

    df_points = @chain df begin
        select(facet, :Day, raw)
        dropmissing
    end

    df_plot = @chain df begin
        select(facet, :Day, :IsBaseline, :State, raw, ewma, lcl, ucl, outside)
        filter(ewma => (x -> !ismissing.(x)), _)
        transform(outside => :Color)
        groupby(facet)
        transform(:State => determine_phases => :Phase; ungroup=false)
        transform(
            raw => (x -> minimum(skipmissing(x))) => :Min,
            raw => (x -> maximum(skipmissing(x))) => :Max,
            :Color => (x -> all(isequal(0), x) ? [1, x[2:end]...] : x) => :Color,
            :Phase => ByRow(x -> x in ["DepressionEarlyProdromal", "DepressionLateProdromal"]) => :IsDepressionProdromal,
            :Phase => ByRow(x -> x in ["ManiaEarlyProdromal", "ManiaLateProdromal"]) => :IsManiaProdromal,
            :Phase => ByRow(x -> x in ["DepressionFirstWeek", "DepressionSecondWeek", "DepressionOngoingWeeks"]) => :IsDepressionEpisode,
            :Phase => ByRow(x -> x in ["ManiaFirstWeek", "ManiaSecondWeek", "ManiaOngoingWeeks"]) => :IsManiaEpisode
        )
        select(Not(raw))
        dropmissing(:IsBaseline)
    end

    df_baseline, df_depression_prodromal, df_mania_prodromal, df_depression_episode, df_mania_episode =
        (make_geometries(df_plot, facet, x -> getindex(x, :, col))
         for col in [:IsBaseline, :IsDepressionProdromal, :IsManiaProdromal, :IsDepressionEpisode, :IsManiaEpisode])

    figure = draw(
        mapping(; layout=facet => layout_sorter) * (
            mapping(:Geometries) * visual(Poly; alpha=0.2) * (
                data(df_baseline) * visual(; color=GREEN) +
                data(df_depression_prodromal) * visual(; color=LIGHTBLUE) +
                data(df_mania_prodromal) * visual(; color=YELLOW) +
                data(df_depression_episode) * visual(; color=BLUE) +
                data(df_mania_episode) * visual(; color=ORANGE)
            ) +
            data(df_points) * visual(Scatter; markersize=1.5) * mapping(:Day, raw) +
            data(df_plot) *
            (
                visual(Lines, linestyle=:dash, linewidth=0.8) * (mapping(:Day, lcl) + mapping(:Day, ucl)) +
                visual(ScatterLines; markersize=2.5, linewidth=0.8, colormap=[:black, RED]) * mapping(:Day, ewma; color=:Color => verbatim)
            )
        );
        facet=(; linkxaxes=:none, linkyaxes=:none),
        axis=(width=325, height=165, ylabel),
        palettes=(layout=layout,)
    )

    return figure
end