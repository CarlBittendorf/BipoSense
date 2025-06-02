include("../startup.jl")

df = @chain d"BipoSense Forms" begin
    transform(:FormTrigger => ByRow(Date) => :Date)
    leftjoin(d"BipoSense Ground Truth"; on = [:Participant, :Date])
    dropmissing(:State)
    sort([:Participant, :Date])
end

models = fit_logit_models(df, [:IsMissing])

header = ["", "DEP", "DLP", "DFW", "DSW", "DOW", "MEP", "MLP", "MFW", "MSW"]

analyze_models("models/Models Missings.pdf", models; header)