using HTTP, JSON, XLSX, DataFrames


# wrapper function to make a request to the movisens API
# before you can use the API, you have to create an API key (admin rights needed):
# https://xs.movisens.com/administration/apikeys
# also note the Study ID, which is part of the URL for the API request
# movisens provide a (somewhat complicated) Kotlin implementation here:
# https://github.com/movisens/movisensxs-api
function make_movisens_request(url, key; headers=[])
    response = HTTP.get(
        url,
        [
            "Authorization" => "ApiKey " * key,
            "User-Agent" => "movisensXS Julia API",
            headers...
        ];
        status_exception=false
    )

    if response.status == 200
        return response.body
    else
        return nothing
    end
end


download_movisens_xs(id, key) =
    make_movisens_request(
        "https://xs.movisens.com/api/v2/studies/" * id * "/results",
        key;
        headers=["Accept" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]
    ) |> IOBuffer |> io -> XLSX.readtable(io, 1) |> DataFrame


download_movisens_probands(id, key) =
    make_movisens_request(
        "https://xs.movisens.com/api/v2/studies/" * id * "/probands",
        key
    ) |> String |> JSON.parse


# returns a zip file as Vector{UInt8}
download_movisens_unisens(id, key, participant) =
    make_movisens_request(
        "https://xs.movisens.com/api/v2/studies/" * id * "/probands/" * participant * "/unisens",
        key
    )