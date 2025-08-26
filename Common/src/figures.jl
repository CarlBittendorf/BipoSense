
# 1. Exports
# 2. Helper Functions
# 3. Implementations

####################################################################################################
# EXPORTS
####################################################################################################

export rectangle, draw_spc, draw_timeseries, draw_roc, draw_optimization, draw_histograms
export BLUE, ORANGE, GREEN, PURPLE, LIGHTBLUE, RED, YELLOW, WHITE, GRAY, BLACK,
       POLYGON_COLORS

####################################################################################################
# HELPER FUNCTIONS
####################################################################################################

function _determine_colors(phases, colors)
    @chain phases begin
        replace(colors...)
        replace(x -> x isa RGB ? (x, 0.2) : missing, _)
    end
end

function _make_polygon_dataframe(df, facet, variable, polygon_colors)
    @chain df begin
        groupby(facet)
        transform(
            variable => (x -> minimum(skipmissing(x); init = 0)) => :Min,
            variable => (x -> maximum(skipmissing(x); init = 0)) => :Max
        )

        transform(
            [:Day, :Min, :Max] => ByRow((day, min, max) -> rectangle(day - 0.5, day + 0.5, min, max)) => :Polygon,
            :Phase => (x -> _determine_colors(x, polygon_colors)) => :Color
        )
        dropmissing(:Color)
    end
end

####################################################################################################
# IMPLEMENTATIONS
####################################################################################################

const PALETTE = AlgebraOfGraphics.aog_theme().palette.color
const BLUE, ORANGE, GREEN, PURPLE, LIGHTBLUE, RED, YELLOW = PALETTE
const WHITE = parse(RGBf, "white")
const GRAY = parse(RGBf, "gray25")
const BLACK = parse(RGBf, "black")

const POLYGON_COLORS = [
    "DepressionEarlyProdromal" => LIGHTBLUE,
    "DepressionLateProdromal" => LIGHTBLUE,
    "DepressionFirstWeek" => BLUE,
    "DepressionSecondWeek" => BLUE,
    "DepressionOngoingWeeks" => BLUE,
    "ManiaEarlyProdromal" => YELLOW,
    "ManiaLateProdromal" => YELLOW,
    "ManiaFirstWeek" => ORANGE,
    "ManiaSecondWeek" => ORANGE,
    "ManiaOngoingWeeks" => ORANGE
]

function rectangle(left, right, bottom, top)
    GeometryBasics.Polygon(Point2d[
        (left, bottom), (left, top), (right, top), (right, bottom)])
end

function draw_spc(df::DataFrame, variable::Symbol;
        facet = :Participant,
        layout = reshape([(y, x) for x in 1:2, y in 1:5], :),
        layout_sorter = sorter(unique(getproperty(df, facet))),
        ylabel = string(variable),
        ewma = string(variable) * "EWMA",
        lcl = string(variable) * "LCL",
        ucl = string(variable) * "UCL",
        out = string(variable) * "OUT",
        polygon_colors = ["Baseline" => GREEN, POLYGON_COLORS...]
)
    df_base = _make_base_dataframe(df, facet)
    df_poly = _make_polygon_dataframe(df_base, facet, variable, polygon_colors)
    df_raw = dropmissing(df_base, variable)

    df_ewma = @chain df_base begin
        dropmissing(ewma)
        transform(out => ByRow(x -> x == 0 ? BLACK : RED) => :Color)
    end

    draw(
        mapping(; layout = facet => layout_sorter) * (
            data(df_poly) * mapping(:Polygon; color = :Color => verbatim) * visual(Poly) +
            data(df_raw) * mapping(:Day, variable) * visual(Scatter; markersize = 1.5) +
            data(df_ewma) * (
                (mapping(:Day, lcl) + mapping(:Day, ucl)) *
                visual(Lines; linestyle = :dash, linewidth = 0.8) +
                mapping(:Day, ewma; color = :Color => verbatim) *
                visual(ScatterLines; markersize = 2.5, linewidth = 0.8)
            )
        ),
        scales(Layout = (; palette = layout));
        facet = (; linkxaxes = :none, linkyaxes = :none),
        axis = (; width = 325, height = 165, ylabel)
    )
end

function draw_spc(dir::AbstractString, df::DataFrame, variables::Vector{Symbol})
    participants = unique(df.Participant)
    groups = map(x -> participants[x], chunk(length(participants), 10))

    for (i, group) in enumerate(groups)
        df_group = subset(df, :Participant => ByRow(x -> x in group))

        for variable in variables
            figure = draw_spc(df_group, variable)

            save(joinpath(dir, string(variable) * "SPC " * string(i) * ".png"),
                figure; px_per_unit = 3)
        end
    end
end

function draw_spc(dir::AbstractString, df::DataFrame, participant, variable::Symbol)
    df_participant = subset(df, :Participant => ByRow(isequal(participant)))

    figure = draw_spc(df_participant, variable; layout = [(1, 1)])

    save(joinpath(dir, string(variable) * "SPC " * string(participant) * ".png"),
        figure; px_per_unit = 3)
end

function draw_spc(
        dir::AbstractString, df::DataFrame, participant, variables::Vector{Symbol};
        layout = begin
            N = sqrt(length(variables))
            reshape([(y, x) for x in 1:round(Int, N), y in 1:ceil(Int, N)], :)
        end,
        layout_sorter = sorter(string.(variables))
)
    df_participant = subset(df, :Participant => ByRow(isequal(participant)))

    # the plot is facetted by variable, so we need to stack the raw data, EWMAs, limits etc.
    df_raw = @chain df_participant begin
        stack(variables)
        select(:Date, :State, :variable, :value)
    end

    df_stacked = outerjoin(
        df_raw,
        (
            @chain df_participant begin
                transform((string(x) * string(col) => string(x) for x in variables)...)
                stack(variables)
                rename(:value => col)
                select(:Date, :variable, col)
            end for col in [:EWMA, :UCL, :LCL, :OUT]
        )...;
        on = [:variable, :Date])

    figure = draw_spc(df_stacked, :value;
        facet = :variable,
        layout,
        layout_sorter,
        ylabel = "",
        ewma = :EWMA,
        ucl = :UCL,
        lcl = :LCL,
        out = :OUT
    )

    save(joinpath(dir, string(participant) * ".png"), figure; px_per_unit = 3)
end

function draw_timeseries(df::DataFrame, variable::Symbol;
        facet = :Participant,
        layout = reshape([(y, x) for x in 1:2, y in 1:5], :),
        layout_sorter = sorter(unique(getproperty(df, facet))),
        ylabel = string(variable),
        polygon_colors = POLYGON_COLORS
)
    df_base = _make_base_dataframe(df, facet)
    df_poly = _make_polygon_dataframe(df_base, facet, variable, polygon_colors)
    df_plot = dropmissing(df_base, variable)

    draw(
        mapping(; layout = facet => layout_sorter) * (
            data(df_poly) * mapping(:Polygon; color = :Color => verbatim) * visual(Poly) +
            data(df_plot) * mapping(:Day, variable) * visual(Lines; linewidth = 0.8)
        ),
        scales(Layout = (; palette = layout));
        facet = (; linkxaxes = :none, linkyaxes = :none),
        axis = (; width = 325, height = 165, ylabel)
    )
end

function draw_timeseries(dir::AbstractString, df::DataFrame, variables::Vector{Symbol})
    participants = unique(df.Participant)
    groups = map(x -> participants[x], chunk(length(participants), 10))

    for (i, group) in enumerate(groups)
        df_group = subset(df, :Participant => ByRow(x -> x in group))

        for variable in variables
            figure = draw_timeseries(df_group, variable)

            save(joinpath(dir, string(variable) * string(i) * ".png"),
                figure; px_per_unit = 3)
        end
    end
end

function draw_roc(df::DataFrame, model)
    false_positive_rates, true_positive_rates, _ = roc_curve(df, model)
    variable = _predictors(model)[2]
    outcome = _outcome(model)

    draw(
        mapping(
            false_positive_rates => "False Positive Rate",
            true_positive_rates => "True Positive Rate"
        ) * visual(Lines);
        axis = (; title = variable * " (" * outcome * ")")
    )
end

function draw_roc(dir::AbstractString, df::DataFrame, models)
    variables = _predictors(models)[2]
    phases = _outcomes(models)

    for (i, variable) in enumerate(variables)
        for (j, phase) in enumerate(phases)
            if !ismissing(models[i, j])
                figure = draw_roc(df, models[i, j])

                save(joinpath(dir, string(variable) * " (" * string(phase) * ")" * ".png"),
                    figure; px_per_unit = 3)
            end
        end
    end
end

function draw_optimization(dir::AbstractString, df::DataFrame;
        types = ["Overall", "Prodromal", "DepressionProdromal",
            "ManiaProdromal", "DepressionEpisode", "ManiaEpisode"],
        colors = [string(x) => color
                  for (x, color) in zip(unique(df.Variable), repeat(PALETTE, nrow(df)))],
        layout = reshape([(y, x) for x in 1:2, y in 1:3], :)
)
    df_figure = @chain df begin
        rename(:Sensitivity => :SensitivityOverall)
        stack("Sensitivity" .* types)
        rename(:variable => :SensitivityType, :value => :Sensitivity)
        transform(:Variable => ByRow(string); renamecols = false)

        # remove "Sensitivity" from the column name
        transform(
            :SensitivityType => ByRow(x -> x[12:end]),
            :Variable => ByRow(x -> x in first.(colors) ? x : "Others");
            renamecols = false
        )
    end

    figure = draw(
        mapping(:Sensitivity, :Specificity) *
        visual(Lines; linestyle = :dash, linewidth = 0.8) *
        (
            data((Sensitivity = [0.5, 0.5], Specificity = [0, 1])) +
            data((Sensitivity = [0, 1], Specificity = [0.95, 0.95]))
        ) +
        data((; Polygon = [rectangle(0.5, 1, 0.95, 1)])) * mapping(:Polygon) *
        visual(Poly; color = (GREEN, 0.2)) +
        data(df_figure) * mapping(
            :Sensitivity, :Specificity;
            layout = :SensitivityType => renamer(types .=>
                collect(range('a'; length = length(types))) .* ") " .* types),
            color = :Variable => sorter(first.(colors))
        ),
        scales(
            Layout = (; palette = layout),
            Color = (; palette = last.(colors))
        );
        axis = (width = 300, height = 200)
    )

    save(joinpath(dir, "Optimization.png"), figure; px_per_unit = 3)
end

function draw_histograms(df::DataFrame, variable::Symbol;
        facet = :Participant,
        xlabel = string(variable),
        colors = ["Euthymia" => GREEN, POLYGON_COLORS...]
)
    df_figure = @chain df begin
        groupby(facet)
        transform(:State => label_phases => :Phase)

        select(:Phase, variable)
        dropmissing
    end

    draw(
        data(df_figure) *
        mapping(
            variable => "";
            color = :Phase => sorter(first.(colors)),
            layout = :Phase => sorter(first.(colors))
        ) * visual(Hist; normalization = :pdf),
        scales(Color = (; palette = last.(colors)));
        axis = (; width = 200, height = 200, xlabel, ylabel = "PDF")
    )
end

function draw_histograms(dir::AbstractString, df::DataFrame, variables::Vector{Symbol})
    for variable in variables
        figure = draw_histograms(df, variable)

        save(joinpath(dir, string(variable) * ".png"), figure; px_per_unit = 3)
    end
end