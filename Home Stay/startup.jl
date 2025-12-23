using DataToolkit, DataFrames, Chain, AmbulatoryAssessmentAnalysis, Distances, MixedModels,
      StatsModels, Effects
using Dates, Statistics
using Common

const VARIABLES = [
    :MeanDistanceFromHome, :MaxDistanceFromHome, :FractionAtHome,
    :MeanDistanceFromHomeDay, :MaxDistanceFromHomeDay, :FractionAtHomeDay,
    :MeanDistanceFromHomeNight, :MaxDistanceFromHomeNight, :FractionAtHomeNight]