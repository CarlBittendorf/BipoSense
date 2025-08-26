
# 1. Exports
# 2. Helper Functions
# 3. Implementations

####################################################################################################
# EXPORTS
####################################################################################################

export roc_curve, auc

####################################################################################################
# HELPER FUNCTIONS
####################################################################################################

function _preprocess_roc(df::DataFrame, model)
    variable = _predictors(model)[2]
    phase = _outcome(model)

    df_roc = @chain df begin
        groupby(:Participant)
        transform(:State => label_phases => :Phase; ungroup = false)
        transform(:Phase => enumerate_phases => :PhaseIndex)

        select(:Participant, :Phase, :PhaseIndex, variable)
        dropmissing
        subset(:Phase => ByRow(x -> x in ["Euthymia", phase]))

        transform(
            All() => ((x...) -> round.(Int, model.y)) => :Y,
            All() => ((x...) -> fitted(model)) => :Ŷ
        )

        groupby([:Participant, :Phase, :PhaseIndex])
        combine(
            [:Phase, :Y] => ((p, y) -> first(p) != phase ? y : [first(y)]) => :Y,
            [:Phase, :Ŷ] => ((p, ŷ) -> first(p) != phase ? ŷ : [minimum(ŷ)]) => :Ŷ
        )
    end

    return df_roc.Ŷ, df_roc.Y
end

####################################################################################################
# IMPLEMENTATIONS
####################################################################################################

function StatisticalMeasures.roc_curve(df::DataFrame, model)
    ŷ, y = _preprocess_roc(df, model)

    return StatisticalMeasures.Functions.roc_curve(ŷ, y, 1)
end

function StatisticalMeasures.auc(df::DataFrame, model)
    ŷ, y = _preprocess_roc(df, model)

    return StatisticalMeasures.Functions.auc(ŷ, y, 1)
end