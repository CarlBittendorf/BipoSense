using DataToolkit, DataFrames, Chain, ZipFile, ShiftedArrays, CSV, XML, LocalPoly
using Dates, Statistics


include("src/utils.jl")
include("src/movisens.jl")
include("src/ewma.jl")
include("src/metrics.jl")


const PHONECALL_VARIABLES = [
    :OutgoingCalls, :IncomingMissedCalls, :OutgoingNotReachedCalls,
    :MinutesCallDuration, :UniqueConversationPartners
]
const VARIABLES = [
    :Steps,
    :MinutesInVehicle, :MinutesOnFoot, :MinutesStill,
    :KilometersTotal, :KilometersSlow, :KilometersFast,
    PHONECALL_VARIABLES...,
    :CountDisplayOn, :MinutesDisplayOn,
    :MinutesPhoneInactive,
    :HoursAsleep, :TimeGotUp,
    :Mood
]

# map participant ids to movisens ids
const MAPPINGS = Dict(
    "2438" => [6],
    "2869" => [39],
    "2988" => [34, 53],
    "3767" => [14, 52],
    "3777" => [23],
    "4278" => [26, 38],
    "4289" => [5],
    "4352" => [12],
    "4458" => [15],
    "4534" => [10],
    "4652" => [27],
    "5325" => [48],
    "5768" => [25],
    "6233" => [18],
    "6557" => [9, 41],
    "6676" => [22],
    "7296" => [54, 55, 60],
    "7374" => [35],
    "7587" => [4],
    "7848" => [1],
    "7969" => [17],
    "8439" => [32],
    "8477" => [20, 33],
    "8632" => [8, 11],
    "8663" => [47, 57],
    "8745" => [24, 46],
    "9695" => [21, 29],
    "9735" => [50, 58, 59],
    "9787" => [7]
)