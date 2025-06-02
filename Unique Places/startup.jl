using DataToolkit, DataFrames, Chain, AmbulatoryAssessmentAnalysis, GeoStats
using Dates
using Common

const VARIABLES = [:UniqueClusters, :ClusterChanges, :MedianTimeAtCluster]