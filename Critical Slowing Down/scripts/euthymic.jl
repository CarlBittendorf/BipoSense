function (;
        var"data#BipoSense Critical Slowing Down",
        var"data#BipoSense Dimensional Ratings"
)
    @chain var"data#BipoSense Critical Slowing Down" begin
        leftjoin(var"data#BipoSense Dimensional Ratings"; on = [:Participant, :Date])
        sort([:Participant, :Date])

        groupby(:Participant)
        transform(
            :Date => enumerate_days => :Day,
            :State => label_phases => :Phase,

            # use MADRS and YMRS scores for the previous 13 days
            [:YMRSTotalScore, :MADRSTotalScore] .=>
                (x -> [coalesce(x[i:min(i + 13, length(x))]...) for i in eachindex(x)]);
            renamecols = false
        )

        subset(:Day => ByRow(x -> x > 14))
        dropmissing(:Phase)

        # remove all euthymic days with MADRS >= 5 or YMRS >= 4
        subset(
            [:Phase, :MADRSTotalScore]
            => ByRow((p, s) -> p != "Euthymia" || (!ismissing(s) && s < 5)),
            [:Phase, :YMRSTotalScore]
            => ByRow((p, s) -> p != "Euthymia" || (!ismissing(s) && s < 4))
        )
    end
end