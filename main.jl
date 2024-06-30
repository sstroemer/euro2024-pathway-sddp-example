# rule = SDDP.DecisionRule(model; node=105)
# ogs = [
#     Symbol("state_p_nom[Hydro]"),
#     Symbol("state_p_nom[Storage]"),
#     Symbol("state_p_nom[Gas Turbine (CH4)]"),
#     Symbol("state_p_nom[Wind]"),
#     Symbol("state_e_nom[Storage]"),
#     Symbol("state_p_nom[PV]"),
#     Symbol("state_p_nom[Gas Turbine (H2)]"),
#     Symbol("state_soc[Storage]"),
# ]
# solution = SDDP.evaluate(
#     rule;
#     incoming_state=Dict(it => 0.0 for it in ogs),
#     noise=(0.5, 0.25, 0.5, 5e4),
#     controls_to_record=[Symbol("__var__demand1.shedding")],
# )

# objective_values = [sum(stage[:stage_objective] for stage in sim) for sim in simulations]

# μ = round(mean(objective_values); digits=2)
# ci = round(1.96 * std(objective_values) / sqrt(500); digits=2)

# println("Confidence interval: ", μ, " ± ", ci)
# println("Lower bound: ", round(SDDP.calculate_bound(model); digits=2))

# shedding = map(simulations[1]) do node
#     return node[Symbol("__var__demand1.shedding")]
# end
using JuMP
using DataFrames
import CSV
import HiGHS, Gurobi
import SDDP
import YAML
using OrderedCollections
using Statistics
using PlotlyJS

include("src/util.jl")
include("src/data.jl")

# Uncomment this to re-create the input data.
# create_input_data()

include("opt/opt.jl")

TRAIN_MAX_ITER = 250
SIMULATE_ITER = 2
include("src/pathway.jl")

TRAIN_MAX_ITER = 100
SIMULATE_ITER = 2
include("src/singleshot.jl")

df_e_nom = prep_basic_df!(DataFrame([ss_res_e_nom, pw_res_e_nom], ["1: Single-shot", "2: Pathways"]))

df_shedding = prep_basic_df!(DataFrame([ss_res_shedding, pw_res_shedding], ["1: Single-shot", "2: Pathways"]))
df_shedding.value .*= 1e-3

df_obj = prep_basic_df!(DataFrame([first.(ss_res_obj), first.(pw_res_obj)], ["1: Single-shot", "2: Pathways"]))
df_obj.value .*= 1e-6

df_p_nom = vcat(ss_df_p_nom, pw_df_p_nom)
df_p_nom[!, "year"] = parse.(Int, getindex.(split.(df_p_nom[!, "time"], " "), 1))
df_p_nom[!, "mode"] = ["PW", "SS"][(getindex.(split.(df_p_nom[!, "time"], " "), 2) .== "(SS)") .+ 1]
df_p_nom.value .*= 1e-3

df_gen = vcat(ss_df_gen, pw_df_gen)
df_gen[!, "year"] = parse.(Int, getindex.(split.(df_gen[!, "time"], " "), 1))
df_gen[!, "mode"] = ["PW", "SS"][(getindex.(split.(df_gen[!, "time"], " "), 2) .== "(SS)") .+ 1]
df_gen.value .*= 1e-6

# Add dummy spacings.
for a in Set(df_p_nom.asset)
    push!(df_p_nom, (time="2030", asset=a, value=0.0, year=2030, mode="AA"))
    push!(df_p_nom, (time="2040", asset=a, value=0.0, year=2040, mode="AA"))
end
for a in Set(df_gen.asset)
    push!(df_gen, (time="2030", asset=a, value=0.0, year=2030, mode="AA"))
    push!(df_gen, (time="2040", asset=a, value=0.0, year=2040, mode="AA"))
end

# Fix order.
sort!(df_p_nom, [:year, :mode], rev=[false, true])
sort!(df_gen, [:year, :mode], rev=[false, true])

p = plot(df_e_nom, kind="bar", x=:year, y=:value, color=:mode,
academic_layout("", "time", "volume [GWh]") do l
    l.barmode = "group"
end,
)
savefig(p, "plots/e_nom.png"; scale=3.0, width=1000, height=400)

p = plot(
    df_shedding,
    kind="bar",
    x=:year,
    y=:value,
    color=:mode,
    academic_layout("", "time", "energy [GWh]") do l
        l.barmode = "group"
    end,
)
savefig(p, "plots/shedding.png"; scale=3.0, width=400, height=400)

p = plot(
    df_obj,
    kind="bar",
    x=:year,
    y=:value,
    color=:mode,
    academic_layout("", "time", "cost [M EUR]") do l
        l.barmode = "group"
    end,
)
savefig(p, "plots/obj.png"; scale=3.0, width=400, height=400)

cols = ["#E63462", "#8223FF", "#00BBFF", "#F09D51", "#FFBBE9", "#0EAD69"]
p = plot(
    df_p_nom,
    kind="bar",
    x=:time,
    y=:value,
    color=:asset,
    academic_layout("", "time", "power [GW]") do l
        l.barmode = "relative"
    end,
)
for (i, trace) in enumerate(p.plot.data)
    trace.fields[:marker][:color] = cols[i]
end
savefig(p, "plots/p_nom.png"; scale=3.0, width=1000, height=400)

cols = ["#E63462", "#8223FF", "#00BBFF", "#F09D51", "#FFBBE9", "#FFBBE9", "#0EAD69"]
p = plot(
    df_gen,
    kind="bar",
    x=:time,
    y=:value,
    color=:asset,
    academic_layout("", "time", "energy [TWh]") do l
        l.barmode = "relative"
    end,
)
for (i, trace) in enumerate(p.plot.data)
    trace.fields[:marker][:color] = cols[i]
end
savefig(p, "plots/gen.png"; scale=3.0, width=1000, height=400)

