# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# PW: Pathway optimization                                                                #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
model = SDDP.LinearPolicyGraph(
    (sp, n) -> subproblem_builder(sp, n);
    stages=52 * 3,
    sense=:Min,
    lower_bound=1e8,
    optimizer=Gurobi.Optimizer,
)
# SDDP.numerical_stability_report(model)

registered_objects = collect(keys(object_dictionary(model.nodes[1].subproblem)))

SDDP.train(model; iteration_limit=TRAIN_MAX_ITER)
simulations = SDDP.simulate(model, SIMULATE_ITER, registered_objects)

# ==========================================================================
# ==========================================================================
# ==========================================================================
all_p_nom = [
    split(split(string(it), "__")[3], ".")[1] => it for
    it in registered_objects if endswith(string(it), ".p_nom") && startswith(string(it), "__var__")
]
all_gen = [
    split(split(string(it), "__")[3], ".")[1] => it for
    it in registered_objects if endswith(string(it), ".gen") && startswith(string(it), "__var__")
]
push!(all_gen, "Storage (discharge)" => Symbol("__var__Storage.discharge"))
push!(all_gen, "Storage (charge)" => Symbol("__var__Storage.charge"))
# ==========================================================================
# ==========================================================================
# ==========================================================================

pw_res_p_nom = map(simulations[1][[1, 53, 105]]) do node
    return NamedTuple([(Symbol(k), node[v]) for (k, v) in all_p_nom])
end

pw_res_gen = map(simulations[1]) do node
    return NamedTuple([(Symbol(k), sum(node[v])) for (k, v) in all_gen])
end

pw_df_p_nom = DataFrame(hcat(collect.(values.(pw_res_p_nom))...)', first.(all_p_nom))
pw_df_p_nom[!, "time"] = ["$it (PW)" for it in [2030, 2040, 2050]]
pw_df_p_nom = stack(pw_df_p_nom, Not(:time); variable_name=:asset, value_name=:value)

pw_df_gen = DataFrame(
    hcat([sum(hcat(collect.(values.(pw_res_gen))...)'[((i - 1) * 52 + 1):(i * 52), :]; dims=1)[1, :] for i in 1:3]...)',
    first.(all_gen),
)
pw_df_gen[!, "Storage (charge)"] .*= -1
pw_df_gen[!, "time"] = ["$it (PW)" for it in [2030, 2040, 2050]]
pw_df_gen = stack(pw_df_gen, Not(:time); variable_name=:asset, value_name=:value)

p = plot(pw_df_p_nom, kind="bar", x=:time, y=:value, color=:asset, Layout(title="Capacity (PW)", barmode="relative"))
display(p)
p = plot(pw_df_gen, kind="bar", x=:time, y=:value, color=:asset, Layout(title="Generation (PW)", barmode="relative"))
display(p)
