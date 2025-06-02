include("../startup.jl")

df = @chain d"BipoSense Passive Sensing" begin
    groupby(:Participant)
    transform(:State => determine_baseline => :Baseline)

    # remove the baseline as the algorithm was "trained" on it
    subset(:Baseline => ByRow(!))
end

variables = add_suffixes(VARIABLES, ["OUT"])
header = ["", "DEP", "DLP", "DFW", "DSW", "DOW", "MEP", "MLP", "MFW", "MSW"]

models = fit_logit_models(df, variables)

analyze_models("models/Models.pdf", models; header)