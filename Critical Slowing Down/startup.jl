using DataToolkit, DataFrames, Chain, AmbulatoryAssessmentAnalysis, MixedModels, StatsModels
using Dates, Statistics
using Common

const VARIABLES = [
    :IncomingMissedCalls, :OutgoingCalls, :OutgoingNotReachedCalls,
    :MinutesCallDuration, :UniqueConversationPartners, :CountDisplayOn,
    :MinutesDisplayOn, :KilometersTotal, :KilometersSlow, :KilometersFast,
    :MinutesInVehicle, :MinutesOnFoot, :MinutesStill, :Steps, :MinutesPhoneInactive,
    :HoursAsleep, :WakeUp, :LatentCommunication, :LatentActive, :LatentSleep]