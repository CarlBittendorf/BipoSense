function (; var"data#biposense", var"data#mobile sensing (aggregated)", var"data#xs (clean)")
    @chain var"data#biposense" begin
        transform(:Participant => ByRow(string); renamecols=false)

        leftjoin(var"data#mobile sensing (aggregated)"; on=[:Participant, :Date])
        leftjoin(var"data#xs (clean)"; on=[:ID, :Date], matchmissing=:notequal)
    end
end