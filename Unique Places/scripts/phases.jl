include("../startup.jl")

using CSV

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
    transform(
        :State => label_phases => :Phase,
        :State => determine_baseline => :Baseline
    )

    dropmissing

    leftjoin(
        transform(d"BipoSense Forms", :FormTrigger => ByRow(Date) => :Date);
        on = [:Participant, :Date]
    )
end

variables = [:YMRSTotalScore, :BRMRSTotalScore, :MADRSTotalScore,
    :CGISeverityBipolar, :ManicDepressiveMood]
variables_mean = map(x -> Symbol(string(x) * "Mean"), variables)
variables_sd = map(x -> Symbol(string(x) * "SD"), variables)

df_phases = @chain df begin
    transform([:Phase, :Baseline] => ByRow((p, b) -> b ? "Baseline" : p) => :Phase)

    groupby(:Phase)
    combine(
        variables .=> (x -> mean(skipmissing(x))) .=> variables_mean,
        variables .=> (x -> std(skipmissing(x))) .=> variables_sd
    )
end

CSV.write("data/Phases.csv", df_phases)