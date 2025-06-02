
# 1. Exports
# 2. Implementations

####################################################################################################
# EXPORTS
####################################################################################################

export MovisensXSInactive, MovisensXSLocationClusters
export project, cluster_locations, filter_clusters

####################################################################################################
# IMPLEMENTATIONS
####################################################################################################

struct MovisensXSInactive <: MovisensXSMobileSensing end
struct MovisensXSLocationClusters <: MovisensXSMobileSensing end

function AmbulatoryAssessmentAnalysis.aggregate(
        df_display::DataFrame, df_physical_activity::DataFrame,
        ::Type{MovisensXSInactive}, period::Period; groupcols = []
)
    df_active = @chain df_physical_activity begin
        # use only the first entry of each second
        groupby_period(Second(1); groupcols)
        combine(All() .=> first; renamecols = false)

        groupby(groupcols)
        transform(:DateTime => duration_to_previous(period; maxduration = 60) => :PhysicalActivityDuration)

        subset(:PhysicalActivityType
        => ByRow(x -> x in ["InVehicle", "OnBicycle", "OnFoot", "Tilting"]))
        transform([:DateTime, :PhysicalActivityDuration]
        => ByRow((dt, d) -> range(round(Int, datetime2unix(dt) - d), round(Int, datetime2unix(dt)))) => :ActiveRange)
        dropmissing

        groupby(groupcols)
        combine(:ActiveRange => (x -> Ref(vcat(x...))) => :ActiveRange)
    end

    df_display_off = @chain df_display begin
        # use only the first entry of each second
        groupby_period(Second(1); groupcols)
        combine(All() .=> first; renamecols = false)

        groupby(groupcols)
        transform(:DateTime => duration_to_next(period) => :DisplayDuration)

        subset(:DisplayOn => ByRow(isequal(false)))
        transform([:DateTime, :DisplayDuration]
        => ByRow((dt, d) -> range(round(Int, datetime2unix(dt)), round(Int, datetime2unix(dt) + d))) => :DisplayOffRange)
        dropmissing

        groupby(groupcols)
        combine(:DisplayOffRange => (x -> Ref(vcat(x...))) => :DisplayOffRange)
    end

    @chain begin
        outerjoin(df_active, df_display_off; on = groupcols)
        dropmissing

        groupby(groupcols)
        combine([:ActiveRange, :DisplayOffRange] => ((a, d) -> setdiff(vcat(d...), vcat(a...))) => :Unix)

        transform(:Unix => ByRow(unix2datetime) => :DateTime)

        groupby_period(period; groupcols)
        combine(nrow => :SecondsPhoneInactive)
    end
end

function project(lat, lon, crs)
    proj = Proj(crs)

    @chain LatLon(lat, lon) begin
        GeoStats.Point
        proj
        to
        ustrip
    end
end

project(crs) = (lat, lon) -> project(lat, lon, crs)

function cluster_locations(
        df::DataFrame, period::Period; crs, radius, min_neighbors, groupcols = [])
    @chain df begin
        # project coordinates from WGS84 to another coordinate reference system
        # this allows us to use euclidian distances for DBSCAN
        transform([:Latitude, :Longitude] => ByRow(project(crs)) => [:X, :Y])

        # detect clusters using DBSCAN
        groupby_period(period; groupcols)
        transform([:X, :Y] => ((x, y) -> dbscan([x y]', radius; min_neighbors).assignments) => :ClusterIndex)
    end
end

function filter_clusters(df::DataFrame, period::Period; groupcols = [])
    @chain df begin
        # remove entries classified as noise
        subset(:ClusterIndex => ByRow(!isequal(0)))

        groupby_period(period; groupcols)
        transform(:ClusterIndex => enumerate_clusters => :ClusterEnumeration)

        # remove clusters without a continuous length of stay of at least 10 minutes
        groupby_period(period; groupcols = [groupcols..., :ClusterEnumeration])
        subset(:ClusterIndex => (x -> length(x) >= 10))
    end
end

function AmbulatoryAssessmentAnalysis.aggregate(
        df::DataFrame, ::Type{MovisensXSLocationClusters}, period::Period;
        max_velocity, crs, radius, min_neighbors, groupcols = [])
    @chain df begin
        filter_locations(; max_velocity, groupcols)

        # fill missing timestamps
        select(groupcols..., :DateTime, :Latitude, :Longitude)
        fill_periods(period, Minute(1); groupcols)
        groupby(groupcols)
        transform([:Latitude, :Longitude] .=> fill_down; renamecols = false)

        cluster_locations(period; crs, radius, min_neighbors, groupcols)
        filter_clusters(period; groupcols)

        groupby_period(period; groupcols)
        combine(
            :ClusterIndex => count_unique => :UniqueClusters,
            :ClusterIndex => count_changes => :ClusterChanges,
            :ClusterEnumeration => mean ∘ frequencies_of_occurrence => :MeanTimeAtCluster,
            :ClusterEnumeration => median ∘ frequencies_of_occurrence => :MedianTimeAtCluster
        )
    end
end