# metrics for binary classification
# partially adopted from https://github.com/AdarshKumar712/Metrics.jl with bug fixes

function onehot_encode(y::Vector{Int})
    onehot_array = zeros(Int, 2, length(y))
    onehot_array[1, :] = y
    onehot_array[2, :] = 1 .- y

    return onehot_array
end

onehot_encode(y::Vector{Bool}) = onehot_encode(Int.(y))


function confusion_matrix(ŷ, y)
    @assert size(ŷ) == size(y)

    ŷ_onehot = onehot_encode(ŷ)
    y_onehot = onehot_encode(y)

    return ŷ_onehot * transpose(y_onehot)
end


function accuracy(ŷ, y)
    @assert size(ŷ) == size(y)

    return sum(ŷ .== y) / length(y)
end


function prevalence(ŷ, y)
    TP, FN, FP, TN = confusion_matrix(ŷ, y)

    return (TP + FN) / (TP + FN + FP + TN)
end


# true positive rate, recall, sensitivity, probability of detection, hit rate
function recall(ŷ, y)
    TP, FN, _, _ = confusion_matrix(ŷ, y)

    return TP / (TP + FN)
end

sensitivity(ŷ, y) = recall(ŷ, y)


# positive predictive value, precision
function precision(ŷ, y)
    TP, _, FP, _ = confusion_matrix(ŷ, y)

    return TP / (TP + FP)
end


# true negative rate, specificity, selectivity
function specificity(ŷ, y)
    _, _, FP, TN = confusion_matrix(ŷ, y)

    return TN / (TN + FP)
end


# false positive rate, probability of false alarm, type I error
false_alarm_rate(ŷ, y) = 1 - specificity(ŷ, y) # FP / (FP + TN)


# false negative rate, miss rate, type II error
miss_rate(ŷ, y) = 1 - sensitivity(ŷ, y) # FN / (FN + TP)


# measure of predictive performance, harmonic mean of precision and recall
# recall is considered β times as important as precision
function f_beta_score(ŷ, y; β=1)
    TPR = recall(ŷ, y)
    PPV = precision(ŷ, y)

    return (1 + β^2) * PPV * TPR / (β^2 * PPV + TPR)
end


balanced_accuracy(ŷ, y) = (sensitivity(ŷ, y) + specificity(ŷ, y)) / 2


# measures agreement, taking into account the possibility that the agreement occurred by coincidence
function cohens_kappa(ŷ, y)
    TP, FN, FP, TN = confusion_matrix(ŷ, y)

    return 2 * (TP * TN - FN * FP) / ((TP + FP) * (FP + TN) + (TP + FN) * (FN + TN))
end