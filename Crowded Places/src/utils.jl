
buffer_point(point, radius) = Ball(point, radius)

function buffer_line(line, radius)
    offset = @chain begin
        line.b - line.a
        Rotate(pi / 2)(_)
        normalize
        radius .* _
    end

    x = line |> Translate(offset...)
    y = line |> Translate(-offset...)

    return PolyArea(x.a, x.b, y.b, y.a)
end

function buffer_rope(rope, radius)
    balls = map(x -> buffer_point(x, radius), rope.vertices)
    polys = map(i -> buffer_line(Line(rope.vertices[i:(i + 1)]...), radius),
        1:(length(rope.vertices) - 1))

    return GeometrySet(vcat(balls, polys))
end

function load_geometries(filename)
    json = @chain filename begin
        read(String)
        JSON.parse
    end

    # remove tags, which would cause unnecessary columns in the dataframe
    for i in eachindex(json["features"])
        for key in keys(json["features"][i]["properties"])
            delete!(json["features"][i]["properties"], key)
        end
    end

    tempdir = mktempdir()
    tempfile = joinpath(tempdir, "data.geojson")

    write(tempfile, JSON.json(json))

    @chain tempfile begin
        GeoIO.load
        Proj(EPSG{3035})(_)
        DataFrame
        getproperty(:geometry)
        map(
            x -> begin
                if x isa Ring
                    return PolyArea(x)
                elseif x isa Rope
                    return buffer_rope(x, 10)
                elseif x isa GeoStats.Point
                    return buffer_point(x, 50)
                else
                    return x
                end
            end,
            _
        )
    end
end

function iswithin(box, point)
    (point.coords.x >= box.min.coords.x && point.coords.x <= box.max.coords.x &&
     point.coords.y >= box.min.coords.y && point.coords.y <= box.max.coords.y)
end

function isexposed(points, polygons)
    boxes = GeoStats.boundingbox.(polygons)
    hits = map(x -> findall(box -> iswithin(box, x), boxes), points)

    return map((point, indices) -> any(polygon -> point in polygon, polygons[indices]),
        points, hits)
end

isexposed(polygons) = x -> isexposed(x, polygons)

function make_grid(rowindices, colindices, values)
    grid = repeat(
        Union{eltype(values), Missing}[missing], maximum(rowindices), maximum(colindices))

    for (i, j, value) in zip(rowindices, colindices, values)
        grid[i, j] = value
    end

    return grid
end

function get_grid_values(rowindices, colindices, grid)
    map((i, j) -> i in axes(grid, 1) && j in axes(grid, 2) ? grid[i, j] : missing,
        rowindices, colindices)
end

function get_grid_values(grid)
    (rowindices, colindices) -> get_grid_values(rowindices, colindices, grid)
end