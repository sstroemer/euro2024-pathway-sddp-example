_parse_time(x) = Tuple{Int, Int}(parse.(Int, strip.(split(x[2:(end - 1)], ','))))

function load_data(file, value; t1, t2)
    df = CSV.read(normpath("data", "$file.csv"), DataFrame)
    df.time = _parse_time.(df.time)
    return df[(df.time .>= [t1]) .& (df.time .<= [t2]), value]::Vector{Float64}
end

function parse_config!(model, filename; time, can_invest)
    config = YAML.load_file("config.yaml"; dicttype=OrderedDict{Symbol, Any})

    for (asset, properties) in config[:assets]
        base = Dict(:name => string(asset), :T => time, :can_invest => can_invest)

        f = getfield(@__MODULE__, Symbol("add_$(pop!(properties, :type))!"))
        f(model, nothing, merge(base, properties))
    end

    return nothing
end
