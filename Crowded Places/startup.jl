using DataToolkit, AmbulatoryAssessmentAnalysis, Chain, DataFrames, GeoStats,
      CoordRefSystems, GeoArtifacts, Distances, ShiftedArrays, JSON, GeoIO
using GMT: gmtread
using Dates, LinearAlgebra
using Common

include("src/utils.jl")

VARIABLES = [
    :MinutesRetailExposure, :MinutesRailwayExposure, :MinutesPedestrianExposure,
    :MinutesMallExposure, :MinutesDepartmentStoreExposure,
    :MinutesCrowdExposure, :MeanPopulationDensity, :MeanImperviousness]