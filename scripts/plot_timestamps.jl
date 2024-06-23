using AlgebraOfGraphics, CairoMakie


set_aog_theme!()

dict = read(dataset("mobile sensing"), Dict{String,IO})
ids = string.(vcat(values(MAPPINGS)...))


function prepare_dataframe(df, label)
    @chain df begin
        transform(
            :SecondsSinceStart => (x -> collect(1:length(x))) => :Row,
            All() => ByRow((x...) -> label) => :Type
        )
        select(:Row, :SecondsSinceStart, :Type)
    end
end


# plot row numbers against seconds since start
for id in ids
    reader = ZipFile.Reader(dict[id*".zip"])

    phone_call_activity = read_phone_call_activity(reader)
    diplay_on = read_display_on(reader)
    location = read_location(reader)
    traffic_rx = read_traffic_rx(reader)
    traffic_tx = read_traffic_tx(reader)
    steps = read_steps(reader)
    activity_log = read_activity_log(reader)

    close(reader)

    df_points = vcat((prepare_dataframe(df, label) for (df, label) in zip(
        [phone_call_activity, diplay_on, location, traffic_rx, traffic_tx, steps, activity_log],
        ["PhoneCallActivity", "DisplayOn", "Location", "TrafficRx", "TrafficTx", "Steps", "ActivityLog"]
    ))...)

    figure = draw(
        data(df_points) * mapping(:Row, :SecondsSinceStart; layout=:Type) * visual(Scatter; markersize=3);
        facet=(; linkxaxes=:none, linkyaxes=:none),
        axis=(width=325, height=165),
        palettes=(layout=reshape([(y, x) for x in 1:2, y in 1:4], :),)
    )

    save("timestamps/" * id * ".png", figure, px_per_unit=3)
end