function (; var"data#mobile sensing::Dict{String, IO}")
    # in some cases, a server error resulted in wrong (too early) start timestamps in the xml file
    # the timestamps in the csv files take this offset into account
    # but there are other errors like time jumps and duplicate entries that need to be removed
    function correct_server_errors(df::DataFrame, id::String)
        start = 0

        if id == "4"
            start = 91604320
        elseif id == "12"
            start = 98984931
        elseif id == "20"
            start = 169395450
        elseif id == "25"
            start = 108673460
        elseif id == "60"
            start = 159633430
        end

        # remove wrong timestamps
        subset(df, :SecondsSinceStart => x -> filter_timestamps(x, start))
    end


    function process_folder(dict, id)
        reader = ZipFile.Reader(dict[id*".zip"])
        start = get_unisens_start(reader)

        df_phone_call_activity, df_display_on, df_location, df_traffic_rx, df_traffic_tx, df_steps, df_activity_log =
            (correct_server_errors(f(reader), id) for f in (read_phone_call_activity, read_display_on, read_location, read_traffic_rx, read_traffic_tx, read_steps, read_activity_log))

        close(reader)

        @chain begin
            outerjoin(
                aggregate_phone_call_activity(df_phone_call_activity, start),
                aggregate_display_on(df_display_on, start),
                aggregate_location(df_location, start),
                aggregate_traffic_rx(df_traffic_rx, start),
                aggregate_traffic_tx(df_traffic_tx, start),
                aggregate_steps(df_steps, start),
                aggregate_activity_log(df_activity_log, start),
                aggregate_inactive(df_display_on, df_activity_log, df_traffic_rx, df_traffic_tx, start);
                on=:Date
            )
            transform(All() => ((x...) -> id) => :ID)
        end
    end


    function process_participant(dict, participant, ids)
        @chain begin
            vcat((process_folder(dict, id) for id in ids)...)

            # remove duplicate days
            groupby(:Date)
            combine(All() .=> (x -> coalesce(x...)); renamecols=false)

            # add a column with the participant id
            transform(All() => ((x...) -> participant) => :Participant)
        end
    end


    vcat((process_participant(
        var"data#mobile sensing::Dict{String, IO}",
        participant,
        string.(ids)
    ) for (participant, ids) in MAPPINGS)...)
end