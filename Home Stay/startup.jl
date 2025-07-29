using DataToolkit, DataFrames, Chain, AmbulatoryAssessmentAnalysis, Distances
using Dates, Statistics
using Common

const VARIABLES = [
    :MeanDistanceFromHome, :MaxDistanceFromHome, :FractionAtHome, :FractionAtHomeDay,
    :MeanDistanceFromHomeNight, :MaxDistanceFromHomeNight, :FractionAtHomeNight]