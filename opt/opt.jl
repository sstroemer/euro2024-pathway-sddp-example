struct OptContainer
    ste::Any
    exp::Any
    var::Any
    con::Any
    obj::Any
end

include("node.jl")
include("demand.jl")
include("res.jl")
include("thermal.jl")
include("storage.jl")

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

    return nothing
end

function subproblem_builder(subproblem::Model, node::Int; offset::Int=0)
    node += offset

    y = Int(floor((node - 1) / 52))
    year = [2030, 2040, 2050][y + 1]
    time = [(year, i + 168 * (node - y * 52 - 1)) for i in 1:168]

    build_stage_model!(subproblem, time)

    DEFAULT = (0.5, 0.25, 0.5, 0.5)
    Ω_entries = ["hydrogen", "methane", "co2", "shedding"]

    Ω = [DEFAULT]
    P = [1.0]

    SDDP.parameterize(subproblem, Ω, P) do ω
        prices = Dict(n => getfield(Main, Symbol("price_$n"))(year; ω=ω[i]) for (i, n) in enumerate(Ω_entries))
        build_stage_objective!(subproblem; prices=prices)
        return nothing
    end

    return subproblem
end
