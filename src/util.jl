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
        f(model, merge(base, properties))
    end

    return nothing
end

function prep_basic_df!(df)
    df[!, "year"] = [2030, 2040, 2050]
    df = stack(df, Not(:year); variable_name=:mode, value_name=:value)
    sort!(df, [:year, :mode], rev=[false, true])
    return df
end

function academic_layout(f, title::String, xaxis_title::String, yaxis_title::String)
    l = Layout(
        title=attr(
            text=title,
            font=attr(
                family="JetBrains Mono, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace",
                size=30,
                color="black",
            ),
        ),
        xaxis=attr(
            title=attr(
                text=xaxis_title,
                font=attr(
                    family="JetBrains Mono, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace",
                    size=18,
                    color="black",
                ),
            ),
            tickfont=attr(
                family="JetBrains Mono, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace",
                size=14,
                color="black",
            ),
            showgrid=true,
            zeroline=true,
            gridcolor="lightgray",
            gridwidth=0.5,
            linecolor="black",
            linewidth=1,
            mirror=true,
        ),
        yaxis=attr(
            title=attr(
                text=yaxis_title,
                font=attr(
                    family="JetBrains Mono, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace",
                    size=18,
                    color="black",
                ),
            ),
            tickfont=attr(
                family="JetBrains Mono, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace",
                size=14,
                color="black",
            ),
            showgrid=true,
            zeroline=true,
            gridcolor="lightgray",
            gridwidth=0.5,
            linecolor="black",
            linewidth=1,
            mirror=true,
        ),
        legend=attr(
            font=attr(
                family="JetBrains Mono, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace",
                size=14,
                color="black",
            ),
            x=0.0,
            y=1.2,
            yanchor="top",
            xanchor="left",
            orientation="h",
        ),
        plot_bgcolor="white",
        paper_bgcolor="white",
        margin=attr(l=50, r=50, b=50, t=50),
    )
    f(l)
    return l
end
