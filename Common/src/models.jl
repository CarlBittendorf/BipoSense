
# 1. Exports
# 2. Helper Functions
# 3. Implementations

####################################################################################################
# EXPORTS
####################################################################################################

export fit_logit_models, print_table, save_tables, save_table, analyze_models

####################################################################################################
# HELPER FUNCTIONS
####################################################################################################

function _to_matrix(X)
    [!ismissing(X[i, j]) && length(X[i, j]) >= k ? X[i, j][k] : missing
     for i in axes(X, 1), j in axes(X, 2), k in 1:maximum(length.(X))]
end

_predictors(model) = ismissing(model) ? [] : string.(model.formula.rhs[1].terms)

function _predictors(models::Matrix)
    predictors = @chain models begin
        map(_predictors, _)
        _to_matrix
        replace("1" => "(Intercept)")
    end

    variables = [repeat([""], size(predictors, 1)) for _ in axes(predictors, 3)]

    for k in axes(predictors, 3)
        for i in axes(predictors, 1)
            for j in axes(predictors, 2)
                if !ismissing(predictors[i, j, k])
                    variables[k][i] = predictors[i, j, k]

                    break
                end
            end
        end
    end

    return variables
end

_outcome(model) = ismissing(model) ? missing : string(model.formula.lhs)

function _outcomes(models)
    phases = repeat([""], size(models, 2))

    for j in axes(models, 2)
        for i in axes(models, 1)
            if !ismissing(models[i, j])
                phases[j] = _outcome(models[i, j])

                break
            end
        end
    end

    return phases
end

function _p_values(model)
    βs = coef(model)
    ses = stderror(model)
    z = βs ./ ses

    return ccdf.(Chisq(1), abs2.(z))
end

_get_betas(model) = ismissing(model) ? [] : coef(model)

_get_betas(models::Matrix) = _to_matrix(map(_get_betas, models))

_get_odds_ratios(model) = ismissing(model) ? [] : [missing, exp.(coef(model)[2:end])...]

_get_odds_ratios(models::Matrix) = _to_matrix(map(_get_odds_ratios, models))

_get_p_values(model) = ismissing(model) ? [] : _p_values(model)

_get_p_values(models::Matrix) = _to_matrix(map(_get_p_values, models))

function _get_adjusted_p_values(
        p_values, adjustment;
        subsets = [[axes(p_values, 1), axes(p_values, 2), k] for k in axes(p_values, 3)]
)
    results = copy(p_values)

    if all(x -> length(x) == 2, subsets)
        slices = map(x -> [x..., 2], subsets)
    else
        slices = subsets
    end

    for slice in slices
        results[slice...] = @chain p_values[slice...] begin
            replace(missing => 1.0)
            reshape(:)
            PValues
            adjust(adjustment)
            reshape(size(p_values[slice...]))
            map((x, y) -> ismissing(x) ? missing : y, p_values[slice...], _)
        end
    end

    return results
end

function _process_cell(x; pvalue = false)
    (ismissing(x) || !isfinite(x)) && return Cell("")
    pvalue && x < 0.001 && return Cell("<0.001"; bold = true)

    return Cell(string(round(x; digits = 3)); bold = pvalue && x < 0.05)
end

####################################################################################################
# IMPLEMENTATIONS
####################################################################################################

function fit_logit_models(
        df::DataFrame, variables;
        phases = [
            "DepressionEarlyProdromal", "DepressionLateProdromal", "DepressionFirstWeek",
            "DepressionSecondWeek", "DepressionOngoingWeeks", "ManiaEarlyProdromal",
            "ManiaLateProdromal", "ManiaFirstWeek", "ManiaSecondWeek"]
)
    df_model = @chain df begin
        transform(:Participant => ByRow(string); renamecols = false)

        groupby(:Participant)
        transform(:State => label_phases => :Phase)
    end

    if isnothing(phases)
        phases = @chain df_model.Phase begin
            unique
            filter(x -> !ismissing(x) && x != "Euthymia", _)
        end
    end

    models = repeat(
        Union{GeneralizedLinearMixedModel{Float64, Bernoulli{Float64}}, Missing}[missing],
        length(variables),
        length(phases)
    )

    for (i, variable) in enumerate(variables)
        if variable isa Symbol
            variable = [variable]
        end

        df_variable = @chain df_model begin
            select(:Participant, :Phase, variable...)
            dropmissing
        end

        for (j, phase) in enumerate(phases)
            df_phase = @chain df_variable begin
                subset(:Phase => ByRow(x -> x in ["Euthymia", phase]))
                transform(:Phase => (x -> x .== phase) => phase)
            end

            formula = (term(phase) ~ term(1) + sum(term(x) for x in variable) +
                                     (term(1) | term(:Participant)))

            try
                models[i, j] = fit(MixedModel, formula, df_phase, Bernoulli())
            catch e
                @warn "Error for $variable ($phase):" e
            end
        end
    end

    return models
end

function process_cell(x; pvalue = false)
    ismissing(x) && return ""
    !(x isa Number) && return string(x)
    !isfinite(x) && return ""
    pvalue && x < 0.001 && return "<0.001"

    return string(round(x; digits = 3))
end

function print_table(io::IO, header, cells, pvalues = false)
    data = process_cell.(cells; pvalue = pvalues)

    p_value_highlighter = MarkdownHighlighter(
        (data, i, j) -> pvalues && (j != 1) && data[i, j] != "" &&
                            (data[i, j] == "<0.001" || parse(Float64, data[i, j]) < 0.05),
        MarkdownDecoration(; bold = true)
    )

    pretty_table(io, data;
        alignment = :l,
        backend = Val(:markdown),
        header,
        highlighters = (p_value_highlighter,)
    )
end

function save_tables(print_tables::Function, filename::AbstractString)
    mktempdir() do tmp
        quartofile = joinpath(tmp, "Tables.qmd")

        open(quartofile, "w") do io
            println(io, raw"""
            ---
            papersize: A4
            geometry:
                - left=10mm
                - right=10mm
                - top=10mm
                - bottom=10mm
            include-in-header:
                text: |
                    \usepackage{lscape}
                    \newcommand{\blandscape}{\begin{landscape}}
                    \newcommand{\elandscape}{\end{landscape}}
                    \renewcommand\arraystretch{1.5}
            ---

            \footnotesize

            \blandscape
            """)

            print_tables(io)

            println(io)
            println(io, raw"\elandscape")
        end

        run(`quarto render $(abspath(quartofile)) --to pdf`)

        cp(joinpath(tmp, "Tables.pdf"), filename; force = true)
    end

    return nothing
end

function save_table(filename::AbstractString, header, cells, caption, pvalues = false)
    if endswith(filename, ".pdf")
        save_tables(filename) do io
            print_table(io, header, cells, pvalues)
            println(io, "\n: " * caption * "\n")
        end

    elseif endswith(filename, ".csv")
        CSV.write(filename, DataFrame(process_cell.(cells; pvalue = pvalues), header))
    end
end

function analyze_models(
        filename::AbstractString, models;
        adjustment = Holm(),
        p_values = _get_p_values(models),
        subsets = [[axes(p_values, 1), axes(p_values, 2), k] for k in axes(p_values, 3)],
        variables = _predictors(models),
        header = ["", _outcomes(models)...],
        intercepts = false
)
    adjusted_p_values = _get_adjusted_p_values(_get_p_values(models), adjustment; subsets)
    odds_ratios = _get_odds_ratios(models)
    betas = _get_betas(models)

    if endswith(filename, ".pdf")
        save_tables(filename) do io
            for i in axes(p_values, 3)
                i == 1 && !intercepts && continue

                label = i == 1 ? " Intercepts " :
                        size(p_values, 3) == 2 ? " " : " Betas $(i-1) "

                print_table(io, header, hcat(variables[i], p_values[:, :, i]), true)
                println(io, "\n:" * label * "p values" * "\n")

                print_table(
                    io, header, hcat(variables[i], adjusted_p_values[:, :, i]), true)
                println(io, "\n:" * label * "Bonferroni-Holm adjusted p values" * "\n")

                if i != 1
                    print_table(io, header, hcat(variables[i], odds_ratios[:, :, i]))
                    println(io, "\n:" * label * "Odds ratios" * "\n")
                end

                print_table(io, header, hcat(variables[i], betas[:, :, i]))
                println(io, "\n:" * label * "Coefficients" * "\n")
            end
        end

    elseif endswith(filename, ".csv")
        for i in axes(p_values, 3)
            i == 1 && !intercepts && continue

            label = filename[1:(end - 4)] *
                    (i == 1 ? " Intercepts " :
                     size(p_values, 3) == 2 ? " " : " Betas $(i-1) ")

            save_table(label * "(p values).csv", header,
                hcat(variables[i], p_values[:, :, i]), nothing, true)

            save_table(label * "(Bonferroni-Holm adjusted p values).csv", header,
                hcat(variables[i], adjusted_p_values[:, :, i]), nothing, true)

            if i != 1
                save_table(label * "(Odds ratios).csv", header,
                    hcat(variables[i], odds_ratios[:, :, i]), nothing)
            end

            save_table(label * "(Coefficients).csv",
                header, hcat(variables[i], betas[:, :, i]), nothing)
        end
    end
end