function (; var"data#xs")
    @chain var"data#xs" begin
        transform(
            :Participant => ByRow(x -> string(round(Int, x))) => :ID,
            :Form_start_time => ByRow(Dates.Date) => :Date,
            :stimmung => ByRow(x -> x isa Real ? round(Int, x) : missing) => :Mood
        )
        select(:ID, :Date, :Mood)

        # remove duplicate days
        groupby([:ID, :Date])
        combine(All() .=> (x -> coalesce(x...)); renamecols=false)
    end
end