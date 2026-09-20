using AmbulatoryAssessmentAnalysis, DataToolkit, DataFrames, Chain, Distances
using Dates, Statistics
using Common

const VARIABLES = [
    :TotalCalls, :IncomingCalls, :IncomingMissedCalls, :OutgoingCalls, :OutgoingNotReachedCalls,
    :MinutesCallDuration, :UniqueConversationPartners, :CountDisplayOn,
    :MinutesDisplayOn, :KilometersTotal, :KilometersSlow, :KilometersFast,
    :MinutesInVehicle, :MinutesOnFoot, :MinutesStill, :Steps, :HourlyState,
    :MeanDistanceFromHome, :MaxDistanceFromHome, :FractionAtHome]