using JuMP
using DataFrames
import CSV
import HiGHS, Gurobi
import SDDP
import YAML
using OrderedCollections
using Statistics
using PlotlyJS


struct OptContainer3
    ste::Any
    exp::Any
    var::Any
    con::Any
    obj::Any
end
OptContainer = OptContainer3

include("util.jl")

include("opt/node.jl")
include("opt/demand.jl")
include("opt/res.jl")
include("opt/thermal.jl")
include("opt/storage.jl")

include("config.jl")
include("data.jl")

# TODO: transmission ?? 

model = JuMP.Model()

function build_stage_model!(model, time)
    model.ext[:opt_container] = OptContainer(Dict(), Dict(), Dict(), Dict(), Dict())

    # Build assets from config.
    parse_config!(model, "config.yaml"; time=time, can_invest=(time[1][2] % (52 * 168)) == 1)

    # Finalize all nodal balances.
    for (name, expr) in model.ext[:opt_container].exp
        endswith(name, ".nodal_balance") || continue
        model[Symbol("__con__$name")] = @constraint(model, expr .== 0.0)
    end

    # Register all names.
    for (name, element) in model.ext[:opt_container].var
        model[Symbol("__var__$name")] = element
    end

    # Register all states.
    for (name, element) in model.ext[:opt_container].ste
        model[Symbol("__state__$name")] = element
    end

    return nothing
end

function build_stage_objective!(model; prices::Dict)
    total_obj = AffExpr(0.0)
    for (fullname, obj) in model.ext[:opt_container].obj
        component, name = split(fullname, ".")
        if name == "cost"
            add_to_expression!(total_obj, obj)
        elseif startswith(name, "fuel_")
            fuel = split(name, "_")[2]
            add_to_expression!(total_obj, obj * prices[fuel])
        else
            add_to_expression!(total_obj, obj * prices[name])
        end
    end
    SDDP.@stageobjective(model, total_obj)
end

function subproblem_builder(subproblem::Model, node::Int; offset::Int=0)
    node += offset

    y = Int(floor((node - 1) / 52))
    year = [2030, 2040, 2050][y + 1]
    time = [(year, i + 168 * (node - y * 52 - 1)) for i in 1:168]

    build_stage_model!(subproblem, time)

    Ω = [(0.5, 0.25, 0.5, 5e4)]
    P = [1.0]
    Ω_entries = ["hydrogen", "methane", "co2", "shedding"]
    SDDP.parameterize(subproblem, Ω, P) do ω
        prices = Dict(n => getfield(Main, Symbol("price_$n"))(year; ω=ω[i]) for (i, n) in enumerate(Ω_entries))
        build_stage_objective!(subproblem; prices=prices)
        return nothing
    end

    return subproblem
end

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# SS: Single Shot optimization                                                            #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
model = SDDP.LinearPolicyGraph(
    (sp, n) -> subproblem_builder(sp, n);
    stages=52 * 3,
    sense=:Min,
    lower_bound=1e8,
    optimizer=Gurobi.Optimizer,
)
# SDDP.numerical_stability_report(model)

SDDP.train(model; iteration_limit=50)
simulations = SDDP.simulate(model, 2, collect(keys(object_dictionary(model.nodes[1].subproblem))))


all_p_nom = [
    split(split(string(it), "__")[3], ".")[1] => it for it in keys(object_dictionary(model.nodes[1].subproblem)) if
    endswith(string(it), ".p_nom") && startswith(string(it), "__var__")
]

all_gen = [
    split(split(string(it), "__")[3], ".")[1] => it for it in keys(object_dictionary(model.nodes[1].subproblem)) if
    endswith(string(it), ".gen") && startswith(string(it), "__var__")
]
push!(all_gen, "Storage (discharge)" => Symbol("__var__Storage.discharge"))
push!(all_gen, "Storage (charge)" => Symbol("__var__Storage.charge"))

res_p_nom = map(simulations[1][collect(1:52:156)]) do node
    return NamedTuple([(Symbol(k), node[v]) for (k, v) in all_p_nom])
end
df_p_nom = DataFrame(hcat(collect.(values.(res_p_nom))...)', collect(string.(keys(res_p_nom[1]))))
df_p_nom[!, "time"] = 1:3 #[2030, 2040, 2050]
df_p_nom = stack(df_p_nom, Not(:time); variable_name=:asset, value_name=:value)
plot(df_p_nom; kind="bar", x=:time, y=:value, color=:asset, Layout(; title="Installed Capacity", barmode="relative"))

res_gen = map(simulations[1]) do node
    return NamedTuple([(Symbol(k), sum(node[v])) for (k, v) in all_gen])
end
df_gen = DataFrame(
    hcat([sum(hcat(collect.(values.(res_gen))...)'[((i - 1) * 52 + 1):(i * 52), :]; dims=1)[1, :] for i in 1:3]...)',
    collect(string.(keys(res_gen[1]))),
)
df_gen[!, "Storage (charge)"] .*= -1
df_gen[!, "time"] = 1:3 #[2030, 2040, 2050]
df_gen = stack(df_gen, Not(:time); variable_name=:asset, value_name=:value)
plot(df_gen; kind="bar", x=:time, y=:value, color=:asset, Layout(; title="Generation", barmode="relative"))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# SS: Single Shot optimization                                                            #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
ss_res_p_nom = []
ss_res_gen = []
for i in 1:3
    model = SDDP.LinearPolicyGraph(
        (sp, n) -> subproblem_builder(sp, n; offset=(i - 1) * 52);
        stages=52,
        sense=:Min,
        lower_bound=1e8,
        optimizer=Gurobi.Optimizer,
    )

    SDDP.train(model; iteration_limit=50)
    simulations = SDDP.simulate(model, 1, collect(keys(object_dictionary(model.nodes[1].subproblem))))

    push!(ss_res_p_nom, NamedTuple([(Symbol(k), simulations[1][1][v]) for (k, v) in all_p_nom]))

    res_gen = map(simulations[1]) do node
        return NamedTuple([(Symbol(k), sum(node[v])) for (k, v) in all_gen])
    end
    push!(ss_res_gen, sum(hcat(collect.(values.(res_gen))...)'; dims=1)[1, :])
end

ss_df_p_nom = DataFrame(hcat(collect.(values.(ss_res_p_nom))...)', first.(all_p_nom))
ss_df_p_nom[!, "time"] = [2030, 2040, 2050]
ss_df_p_nom = stack(ss_df_p_nom, Not(:time); variable_name=:asset, value_name=:value)
plot(ss_df_p_nom; kind="bar", x=:time, y=:value, color=:asset, Layout(; title="Installed Capacity", barmode="relative"))

ss_df_gen = DataFrame(hcat(ss_res_gen...)', first.(all_gen))
ss_df_gen[!, "Storage (charge)"] .*= -1
ss_df_gen[!, "time"] = ["$it (SS)" for it in [2030, 2040, 2050]]
ss_df_gen = stack(ss_df_gen, Not(:time); variable_name=:asset, value_name=:value)
plot(ss_df_gen; kind="bar", x=:time, y=:value, color=:asset, Layout(; title="Generation", barmode="relative"))
