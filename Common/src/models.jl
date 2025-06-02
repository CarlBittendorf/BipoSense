
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

_predictor(model) = ismissing(model) ? missing : string(model.formula.rhs[1].terms[2])

function _predictors(models)
    variables = repeat([""], size(models, 1))

    for i in axes(models, 1)
        for j in axes(models, 2)
            if !ismissing(models[i, j])
                variables[i] = _predictor(models[i, j])

                break
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

_get_beta(model) = ismissing(model) ? missing : last(coef(model))

_get_betas(models) = map(_get_beta, models)

_get_odds_ratio(model) = ismissing(model) ? missing : exp(last(coef(model)))

_get_odds_ratios(models) = map(_get_odds_ratio, models)

_get_p_value(model) = ismissing(model) ? missing : last(_p_values(model))

_get_p_values(models) = map(_get_p_value, models)

function _get_adjusted_p_values(models, adjustment, subsets = [axes(models)])
    p_values = _get_p_values(models)
    println(size(p_values))
    for subset in subsets
        p_values[subset...] = @chain p_values[subset...] begin
            replace(missing => 1.0)
            reshape(:)
            PValues
            adjust(adjustment)
            reshape(size(p_values[subset...]))
            map((x, y) -> ismissing(x) ? missing : y, p_values[subset...], _)
        end
    end

    return p_values
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
        df::DataFrame, variables::AbstractVector{Symbol};
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
        df_variable = @chain df_model begin
            select(:Participant, :Phase, variable)
            dropmissing
        end

        for (j, phase) in enumerate(phases)
            df_phase = @chain df_variable begin
                subset(:Phase => ByRow(x -> x in ["Euthymia", phase]))
                transform(:Phase => (x -> x .== phase) => phase)
            end

            formula = (term(phase) ~ term(1) + term(variable) +
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
    save_tables(filename) do io
        print_table(io, header, cells, pvalues)
        println(io, "\n: " * caption * "\n")
    end
end

function analyze_models(
        filename::AbstractString, models;
        adjustment = Holm(),
        subsets = [[axes(models, 1), axes(models, 2)]],
        variables = _predictors(models),
        header = ["", _outcomes(models)...],
        odds_ratios = true
)
    save_tables(filename) do io
        print_table(io, header, hcat(variables, _get_p_values(models)), true)
        println(io, "\n: " * "p values" * "\n")

        print_table(io, header,
            hcat(variables, _get_adjusted_p_values(models, adjustment, subsets)), true)
        println(io, "\n: " * "Bonferroni-Holm adjusted p values" * "\n")

        if odds_ratios
            print_table(io, header, hcat(variables, _get_odds_ratios(models)))
            println(io, "\n: " * "Odds ratios" * "\n")
        end

        print_table(io, header, hcat(variables, _get_betas(models)))
        println(io, "\n: " * "Coefficients" * "\n")
    end
end