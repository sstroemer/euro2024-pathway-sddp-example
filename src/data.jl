# 1 MWh = 1000 kWh
# 1 kg hydrogen = 33.33 kWh
# => 1 kg hydrogen = 0.03333 MWh
# => x EUR/kg hydrogen = 30*x EUR/MWh hydrogen

"""
    price_hydrogen(y::Int64; ω::Float64 = 0.5)

Return the price of hydrogen in EUR/MWh for a given year `y`. `ω` determines the optimisticity of the price, with `0.0`
being the cheapest price, and `1.0` being the most expensive price.
"""
function price_hydrogen(y::Int64; ω::Float64=0.5)
    year = (2030, 2050)
    price = ((5, 20), (3, 7))
    μ = Tuple((1.0 - ω) * price[i][1] + ω * price[i][2] for i in 1:2)

    price_per_kg = μ[1] * exp((y - year[1]) * ((log(μ[2]) - log(μ[1])) / (year[2] - year[1])))
    return price_per_kg * 30.0
end

function price_co2(y::Int64; ω::Float64=0.5)
    # https://www.enerdata.net/publications/executive-briefing/carbon-price-projections-eu-ets.html
    # 2030: 70 EUR/tCO2
    # 2040: 130 EUR/tCO2
    # 2044: 500 EUR/tCO2
    # Scale to ± 20%.
    scale = 1.0 + (0.4 * ω - 0.2)
    return scale * (70.0 + 8.436928e-5 * (y - 2030)^5.85215)
end

function price_methane(y::Int64; ω::Float64=0.5)
    # https://globallnghub.com/report-presentation/global-gas-market-outlook-2050
    # USD/mmbtu ~ (0.93 EUR) / (0.29307107 MWh)
    # --> 1 USD/mmbtu ~ 3.173292 EUR/MWh
    # Assumption from picture:
    #   > 2030 - 5 USD/mmbtu ~ 15.9 EUR/MWh
    #   > 2050 - 9 USD/mmbtu ~ 28.6 EUR/MWh

    # Assuming an uneven scale, from "-25%" to "+75%".
    scale = 1 + (ω - 0.25)
    return scale * (15.9 + (y - 2030) / 20.0 * (28.6 - 15.9))
end

price_shedding(y::Int64; ω::Float64=1e5) = ω

function _create_demand()
    url_demand(y) =
        "https://transparency.apg.at/transparency-api/api/v1/Download/AL/German/M60/$y-01-01T000000/$y-12-31T230000/618ec314-c841-4557-ae2a-2e38990c0541/out.csv?"

    df_demand = vcat(
        (CSV.File(download(url_demand(2023)); delim=';', decimal=',', types=[String, String, Float64]) |> DataFrame)[
            1:8736,
            :,
        ],
        (CSV.File(download(url_demand(2022)); delim=';', decimal=',', types=[String, String, Float64]) |> DataFrame)[
            1:8736,
            :,
        ],
        (CSV.File(download(url_demand(2019)); delim=';', decimal=',', types=[String, String, Float64]) |> DataFrame)[
            1:8736,
            :,
        ],
    )

    # based on: https://www.intereconomics.eu/contents/year/2019/number/6/article/the-eu-electricity-sector-will-need-reform-again.html
    # approx. +15% in 2030, and +30% in 2050 (a bit more than 1.5 LIFE)
    scale = [1.15 + 0.15 * (i / nrow(df_demand)) for i in 1:nrow(df_demand)]

    df_demand[!, "demand1"] = df_demand[!, "Leistung [MW]"] .* scale

    df_demand[!, "time"] = [(y, i) for y in [2030, 2040, 2050] for i in 1:8736]
    CSV.write("data/demand.csv", df_demand)

    return nothing
end

function _create_res()
    url_res(y) =
        "https://transparency.apg.at/transparency-api/api/v1/Download/AGPT/German/M60/$y-01-01T000000/$y-12-31T230000/fc7b495d-99a9-407f-92e7-e87d0267c61c/out.csv?"

    dfs = [
        (CSV.File(download(url_res(2023)); delim=';', decimal=',') |> DataFrame)[1:8736, :],
        (CSV.File(download(url_res(2022)); delim=';', decimal=',') |> DataFrame)[1:8736, :],
        (CSV.File(download(url_res(2019)); delim=';', decimal=',') |> DataFrame)[1:8736, :],
    ]

    for i in 1:3
        for c in ["Wind [MW]", "Solar [MW]", "Lauf- und Schwellwasser [MW]"]
            dfs[i][!, c] = round.(dfs[i][!, c] /= maximum(dfs[i][!, c]); digits=2)
        end
    end

    df_res = vcat(dfs...)

    df_res[!, "time"] = [(y, i) for y in [2030, 2040, 2050] for i in 1:8736]
    CSV.write("data/res.csv", df_res)

    return nothing
end

function create_input_data()
    _create_demand()
    _create_res()

    return nothing
end
