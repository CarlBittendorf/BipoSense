# functions to read and aggregate mobile sensing data on a daily level

getfile(reader::ZipFile.Reader, filename) = getfirst(x -> x.name == filename, reader.files)


read_unisens(source) = XML.read(source, XML.Node)


# extract the start timestamp from the unisens.xml file
get_unisens_start(source) = Dates.DateTime(read_unisens(source)[2]["timestampStart"])


function read_phone_call_activity(source)
    @chain source begin
        read(String)
        replace("=" => ",", "|" => ",")
        IOBuffer
        CSV.read(DataFrame; select=[1, 4, 6, 8], header=0)
        rename(["SecondsSinceStart", "CallType", "PartnerHash", "CallDuration"])

        # rows with missing CallType are ignored
        dropmissing
    end
end


read_display_on(source) = CSV.read(source, DataFrame; header=["SecondsSinceStart", "DisplayOn"])


read_location(source) = CSV.read(
    source,
    DataFrame;
    header=["SecondsSinceStart", "Latitude", "Longitude", "Altitude", "Accuracy"]
)


read_traffic_rx(source) = CSV.read(
    source,
    DataFrame;
    header=["SecondsSinceStart", "AppTraffic", "MobileTraffic", "TotalTraffic"]
)


read_traffic_tx(source) = CSV.read(
    source,
    DataFrame;
    header=["SecondsSinceStart", "AppTraffic", "MobileTraffic", "TotalTraffic"]
)


read_steps(source) = CSV.read(source, DataFrame; header=["SecondsSinceStart", "Steps"])


read_activity_log(source) = CSV.read(
    source,
    DataFrame;
    header=["SecondsSinceStart", "ActivityType", "ActivityConfidence"]
)


# define methods for zip files via metaprogramming to avoid repetitive code
for (f, filename) in (
    :read_unisens => "unisens.xml",
    :read_phone_call_activity => "PhoneCallActivity.csv",
    :read_display_on => "DiplayOn.csv",
    :read_location => "Location.csv",
    :read_traffic_rx => "TrafficRx.csv",
    :read_traffic_tx => "TrafficTx.csv",
    :read_steps => "Steps.csv",
    :read_activity_log => "ActivityLog.csv"
)
    eval(
        quote
            $f(reader::ZipFile.Reader) = getfile(reader, $filename) |> $f
        end
    )
end


function aggregate_phone_call_activity(df::DataFrame, start::Dates.DateTime)
    @chain df begin
        transform(:SecondsSinceStart => ByRow(x -> Dates.Date(start + Dates.Second(x))) => :Date)
        groupby(:Date)
        combine(
            nrow => :TotalCalls,
            :CallType => (x -> count(x .== "Incoming")) => :IncomingCalls,
            :CallType => (x -> count(x .== "Outgoing")) => :OutgoingCalls,
            :CallType => (x -> count(x .== "IncomingMissed")) => :IncomingMissedCalls,
            :CallType => (x -> count(x .== "OutgoingNotReached")) => :OutgoingNotReachedCalls,
            :CallDuration => (x -> sum(x) / 60) => :MinutesCallDuration,
            :PartnerHash => (x -> length(unique(x))) => :UniqueConversationPartners
        )
    end
end


function aggregate_display_on(df::DataFrame, start::Dates.DateTime)
    df_display = transform(df, :SecondsSinceStart => ByRow(x -> Dates.Date(start + Dates.Second(x))) => :Date)

    # add extra timestamps at 00:00 to calculate durations per day
    dates = unique(df_display.Date)[1:end-1]
    seconds = differences_in_seconds(dates, start)
    df_extra = DataFrame(SecondsSinceStart=seconds, Date=dates, DisplayOn=missing)

    @chain df_display begin
        vcat(df_extra)
        sort(:SecondsSinceStart)

        # replace missing with previous value
        transform(:DisplayOn => filldown; renamecols=false)

        # calculate the difference to the next on/off event or day, which ever comes first
        transform([:SecondsSinceStart, :Date] => ((s, d) -> (min.(
            ShiftedArrays.lead(s; default=last(s)),
            differences_in_seconds(d .+ Dates.Day(1), start)
        ) .- s) ./ 60) => :DisplayDuration)

        groupby(:Date)
        combine(
            :DisplayOn => (x -> count(x .== 1)) => :CountDisplayOn,
            [:DisplayOn, :DisplayDuration] => ((o, d) -> sum(d[o.==0])) => :MinutesDisplayOff,
            [:DisplayOn, :DisplayDuration] => ((o, d) -> sum(d[o.==1])) => :MinutesDisplayOn
        )
    end
end


# adopted from an R script by Marvin Guth
function aggregate_location(df::DataFrame, start::Dates.DateTime)
    @chain df begin
        transform(:SecondsSinceStart => ByRow(x -> floor(Dates.DateTime(start + Dates.Second(x)), Dates.Minute)) => :FlooredDateTime)
        transform(:FlooredDateTime => ByRow(Dates.Date) => :Date)

        # use only the first value in each minute
        groupby(:FlooredDateTime)
        combine(All() .=> first; renamecols=false)

        transform([:Latitude, :Longitude] => distance_from_previous => :Distance)

        # remove values > 300 km/h
        transform(:Distance => ByRow(x -> x * 60 / 1000) => :Velocity)
        subset(:Velocity => (x -> x .<= 300))

        groupby(:Date)
        combine(
            :Distance => (x -> sum(x) / 1000) => :KilometersTotal,
            [:Distance, :Velocity] => ((d, v) -> sum(d[v.<20]) / 1000) => :KilometersSlow, # < 20 km/h
            [:Distance, :Velocity] => ((d, v) -> sum(d[v.>=20]) / 1000) => :KilometersFast # >= 20 km/h
        )
    end
end


function aggregate_traffic(df::DataFrame, start::Dates.DateTime)
    @chain df begin
        transform(:SecondsSinceStart => ByRow(x -> Dates.Date(start + Dates.Second(x))) => :Date)

        # TotalTraffic contains bytes accumulated over several days, so calculate the increment
        transform(:TotalTraffic => (x -> ifelse.(
                x .>= ShiftedArrays.lag(x; default=0),
                x .- ShiftedArrays.lag(x; default=0),
                x
            )); renamecols=false)

        groupby(:Date)
        combine(:TotalTraffic => sum => :BytesTraffic)
    end
end

aggregate_traffic_rx(df::DataFrame, start::Dates.DateTime) =
    rename(aggregate_traffic(df, start), :BytesTraffic => :BytesReceivedTraffic)

aggregate_traffic_tx(df::DataFrame, start::Dates.DateTime) =
    rename(aggregate_traffic(df, start), :BytesTraffic => :BytesTransmittedTraffic)


function aggregate_steps(df::DataFrame, start::Dates.DateTime)
    @chain df begin
        subset(:Steps => x -> x .>= 0)
        transform(:SecondsSinceStart => ByRow(x -> Dates.Date(start + Dates.Second(x))) => :Date)
        groupby(:Date)
        combine(:Steps => sum; renamecols=false)
    end
end


function aggregate_activity_log(df::DataFrame, start::Dates.DateTime)
    @chain df begin
        transform(:SecondsSinceStart => ByRow(x -> Dates.Date(start + Dates.Second(x))) => :Date)

        # the difference to the previous entry or 60 seconds, which ever is smaller
        transform(:SecondsSinceStart => (x -> min.(x - ShiftedArrays.lag(x; default=0), 60) ./ 60) => :ActivityDuration)

        groupby(:Date)
        combine(
            [:ActivityDuration, :ActivityType] => ((d, t) -> sum(d[t.==0])) => :MinutesInVehicle,
            [:ActivityDuration, :ActivityType] => ((d, t) -> sum(d[t.==1])) => :MinutesOnBicycle,
            [:ActivityDuration, :ActivityType] => ((d, t) -> sum(d[t.==2])) => :MinutesOnFoot,
            [:ActivityDuration, :ActivityType] => ((d, t) -> min.(sum(d[t.==3]), 1440)) => :MinutesStill,
            [:ActivityDuration, :ActivityType] => ((d, t) -> sum(d[t.==5])) => :MinutesTilting
        )

        # all remaining time is treated as unknown
        transform(Not(:Date) => ((x...) -> max.(1440 .- sum(x), 0)) => :MinutesUnknown)
    end
end


function aggregate_inactive(
    df_display_on::DataFrame,
    df_activity_log::DataFrame,
    df_traffic_rx::DataFrame,
    df_traffic_tx::DataFrame,
    start::Dates.DateTime
)

    df_display = transform(df_display_on, :SecondsSinceStart => ByRow(x -> Dates.Date(start + Dates.Second(x))) => :Date)

    # add extra timestamps at 00:00 to calculate durations per day
    dates = unique(df_display.Date)[1:end-1]
    seconds = differences_in_seconds(dates, start)
    df_extra = DataFrame(SecondsSinceStart=seconds, Date=dates, DisplayOn=missing)

    df_display = @chain df_display begin
        vcat(df_extra)
        sort(:SecondsSinceStart)

        # replace missing with previous value
        transform(:DisplayOn => filldown; renamecols=false)

        # calculate the difference to the next on/off event or day, which ever comes first
        transform([:SecondsSinceStart, :Date] => ((s, d) -> (min.(
            ShiftedArrays.lead(s; default=last(s)),
            differences_in_seconds(d .+ Dates.Day(1), start)
        ) .- s)) => :DisplayDuration)

        subset(:DisplayOn => (x -> x .== 0))
    end

    df_activity = @chain df_activity_log begin
        transform(:SecondsSinceStart => ByRow(x -> Dates.Date(start + Dates.Second(x))) => :Date)

        # the difference to the previous entry or 60 seconds, which ever is smaller
        transform(:SecondsSinceStart => (x -> min.(x - ShiftedArrays.lag(x; default=0), 60)) => :ActivityDuration)

        transform([:SecondsSinceStart, :ActivityDuration] => ((s, d) -> s .- d) => :SecondsSinceStart)

        filter(:ActivityType => (x -> x in [0, 1, 2, 5]), _)
    end

    display_off = vcat((row[1]:row[1]+row[4] for row in eachrow(df_display))...)
    activity = vcat((row[1]:row[1]+row[5] for row in eachrow(df_activity))...)
    rx = vcat((row[1]-30:row[1]+30 for row in eachrow(df_traffic_rx))...)
    tx = vcat((row[1]-30:row[1]+30 for row in eachrow(df_traffic_tx))...)

    @chain begin
        setdiff(display_off, activity, rx, tx)
        DataFrame(:SecondsSinceStart => _)
        transform(:SecondsSinceStart => ByRow(x -> Dates.Date(start + Dates.Second(x))) => :Date)
        groupby(:Date)
        combine(:Date => (x -> length(x) / 60) => :MinutesPhoneInactive)
    end
end