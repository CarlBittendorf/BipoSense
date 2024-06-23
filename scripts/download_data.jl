include("../src/download.jl")
include("../secrets.jl") # contains the variables STUDY_ID and STUDY_KEY

using CSV, ZipFile, Chain


# download the form data from movisens and save it to a csv file
CSV.write("data/MovisensXS.csv", download_movisens_xs(STUDY_ID, STUDY_KEY))


# create a Vector{String} of the participant ids
participants = @chain begin
    download_movisens_probands(STUDY_ID, STUDY_KEY)
    map(x -> string(x["id"]), _)
end

# create a new zip file to hold the zip files of all participants
writer = ZipFile.Writer("data/MovisensMobileSensing.zip")

for participant in participants
    # get the mobile sensing data zip file as a Vector{UInt8}
    result = download_movisens_unisens(STUDY_ID, STUDY_KEY, participant)

    if result !== nothing
        # add the participant's zip file to the previously created file
        file = ZipFile.addfile(writer, participant * ".zip")
        write(file, result)
    end
end

# close the file
close(writer)