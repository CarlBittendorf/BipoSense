function (;
        var"data#BipoSense Mobile Sensing",
        var"data#BipoSense Assignments",
        var"data#BipoSense Ground Truth",
        var"data#Zensus 2011",
        max_velocity = 300,
        λ = 0.15,
        L = 2.536435
)
    germany = NaturalEarth.countries() |>
              Filter(row -> row.NAME == "Germany") |>
              Select(168) # geometry

    geometries_retail = load_geometries("/Users/carlbittendorf/Documents/Projects/AmbulatoryAssessmentDatasets/BipoSense/raw/retail.geojson")
    geometries_railway = load_geometries("/Users/carlbittendorf/Documents/Projects/AmbulatoryAssessmentDatasets/BipoSense/raw/railway.geojson")
    geometries_pedestrian = load_geometries("/Users/carlbittendorf/Documents/Projects/AmbulatoryAssessmentDatasets/BipoSense/raw/pedestrian.geojson")
    geometries_mall = load_geometries("/Users/carlbittendorf/Documents/Projects/AmbulatoryAssessmentDatasets/BipoSense/raw/mall.geojson")
    geometries_department_store = load_geometries("/Users/carlbittendorf/Documents/Projects/AmbulatoryAssessmentDatasets/BipoSense/raw/department_store.geojson")

    df_zensus = var"data#Zensus 2011"
    zensus_min_lat = minimum(df_zensus.EPSG3035Latitude)
    zensus_min_lon = minimum(df_zensus.EPSG3035Longitude)

    zensus_grid = @chain df_zensus begin
        transform(
            :EPSG3035Latitude => (x -> round.(Int, (x .- minimum(x)) ./ 1000 .+ 1)) => :RowIndex,
            :EPSG3035Longitude => (x -> round.(Int, (x .- minimum(x)) ./ 1000 .+ 1)) => :ColIndex
        )
        make_grid(_.RowIndex, _.ColIndex, _.Inhabitants)
    end

    imperviousness_min_lat = 900000
    imperviousness_min_lon = 900000

    imperviousness_grid = @chain "/Users/carlbittendorf/Documents/Projects/AmbulatoryAssessmentDatasets/BipoSense/raw/IMD_2015_100m_eu_03035_d03_Full/IMD_2015_100m_eu_03035_d03_full.tif" begin
        gmtread(; img = true)
        getproperty(:image)
        transpose
    end

    @chain var"data#BipoSense Mobile Sensing" begin
        gather(MovisensXSLocation; callback = correct_timestamps)
        transform(:MovisensXSParticipantID => ByRow(x -> parse(Int, x)); renamecols = false)
        leftjoin(var"data#BipoSense Assignments"; on = :MovisensXSParticipantID)
        dropmissing(:Participant)

        filter_locations(; max_velocity, groupcols = [:Participant])
        select(:Participant, :DateTime, :Latitude, :Longitude)
        georef((:Longitude, :Latitude))
        geojoin(germany; pred = ∈, kind = :inner)

        DataFrame
        transform(:geometry => ByRow(x -> ustrip.([x.coords.lat, x.coords.lon]))
        => [:Latitude, :Longitude])
        transform([:Latitude, :Longitude] => ByRow(project(EPSG{3035}))
        => [:EPSG3035Longitude, :EPSG3035Latitude])
        transform([:EPSG3035Longitude, :EPSG3035Latitude] => ByRow(Point) => :Point)

        # OpenStreetMap
        transform(
            :Point => isexposed(geometries_retail) => :RetailExposure,
            :Point => isexposed(geometries_railway) => :RailwayExposure,
            :Point => isexposed(geometries_pedestrian) => :PedestrianExposure,
            :Point => isexposed(geometries_mall) => :MallExposure,
            :Point => isexposed(geometries_department_store) => :DepartmentStoreExposure
        )

        # Zensus 2011
        transform(
            :EPSG3035Latitude => (x -> round.(Int, (x .- zensus_min_lat) ./ 1000 .+ 1)) => :RowIndex,
            :EPSG3035Longitude => (x -> round.(Int, (x .- zensus_min_lon) ./ 1000 .+ 1)) => :ColIndex
        )
        transform([:RowIndex, :ColIndex] => get_grid_values(zensus_grid) => :Inhabitants)

        # High Resolution Layer Imperviousness 2015
        transform(
            :EPSG3035Latitude => (x -> round.(Int, (x .- imperviousness_min_lat) ./ 100 .+ 1)) => :RowIndex,
            :EPSG3035Longitude => (x -> round.(Int, (x .- imperviousness_min_lon) ./ 100 .+ 1)) => :ColIndex
        )
        transform([:RowIndex, :ColIndex] => get_grid_values(imperviousness_grid) => :Imperviousness)
        transform(:Imperviousness => ByRow(x -> x > 100 ? missing : x); renamecols = false)

        # fill missing timestamps
        select(
            :Participant, :DateTime, :RetailExposure, :RailwayExposure, :PedestrianExposure,
            :MallExposure, :DepartmentStoreExposure, :Inhabitants, :Imperviousness)
        fill_periods(Day(1), Minute(1); groupcols = [:Participant])
        groupby(:Participant)
        transform(
            [:RetailExposure, :RailwayExposure, :PedestrianExposure, :MallExposure,
                :DepartmentStoreExposure, :Inhabitants, :Imperviousness] .=> fill_down;
            renamecols = false
        )

        transform([:RetailExposure, :RailwayExposure, :PedestrianExposure,
        :MallExposure, :DepartmentStoreExposure] => ByRow((x...) -> any(x)) => :CrowdExposure)

        groupby_period(Day(1); groupcols = [:Participant])
        combine(
            :RetailExposure => count => :MinutesRetailExposure,
            :RailwayExposure => count => :MinutesRailwayExposure,
            :PedestrianExposure => count => :MinutesPedestrianExposure,
            :MallExposure => count => :MinutesMallExposure,
            :DepartmentStoreExposure => count => :MinutesDepartmentStoreExposure,
            :CrowdExposure => count => :MinutesCrowdExposure,
            :Inhabitants => (x -> mean(skipmissing(x))) => :MeanPopulationDensity,
            :Imperviousness => (x -> mean(skipmissing(x))) => :MeanImperviousness
        )

        transform(:DateTime => ByRow(Date) => :Date)
        select(Not(:DateTime))
        leftjoin(var"data#BipoSense Ground Truth", _; on = [:Participant, :Date])
        subset(:Participant => ByRow(!isequal(2869)))
        transform(
            :State => (x -> replace(x, "Hypomania" => "Mania", "Mixed" => missing));
            renamecols = false
        )
        sort([:Participant, :Date])

        statistical_process_control(VARIABLES; λ, L)
        dynamical_systems_theory(VARIABLES)
    end
end