using DataToolkit, DataFrames, Chain, AmbulatoryAssessmentAnalysis, Distances
using Dates, Statistics
using Common

const VARIABLES = [:MeanDistanceFromHome, :MaxDistanceFromHome, :FractionAtHome,
    :MeanDistanceFromHomeNight, :MaxDistanceFromHomeNight, :FractionAtHomeNight]