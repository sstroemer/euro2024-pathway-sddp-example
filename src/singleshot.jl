# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# SS: Single Shot optimization                                                            #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
ss_res_p_nom = []
ss_res_gen = []
ss_res_e_nom = []
ss_res_shedding = []
ss_res_obj = []
for i in 1:3
    model = SDDP.LinearPolicyGraph(
        (sp, n) -> subproblem_builder(sp, n; offset=(i - 1) * 52);
        stages=52,
        sense=:Min,
        lower_bound=1e9,
        optimizer=Gurobi.Optimizer,
    )

    SDDP.train(model; iteration_limit=TRAIN_MAX_ITER)
    simulations = SDDP.simulate(model, SIMULATE_ITER, collect(keys(object_dictionary(model.nodes[1].subproblem))))

    push!(ss_res_p_nom, NamedTuple([(Symbol(k), simulations[1][1][v]) for (k, v) in all_p_nom]))
    push!(ss_res_e_nom, value(simulations[1][1][Symbol("__var__Storage.e_nom")]))
    push!(ss_res_shedding, sum(sum(value.(simulations[1][i][Symbol("__var__demand1.shedding")])) for i in 1:52))

    res_gen = map(simulations[1]) do node
        return NamedTuple([(Symbol(k), sum(node[v])) for (k, v) in all_gen])
    end
    push!(ss_res_gen, sum(hcat(collect.(values.(res_gen))...)'; dims=1)[1, :])

    objective_values = [sum(stage[:stage_objective] for stage in sim) for sim in simulations]
    push!(
        ss_res_obj,
        (
            round(mean(objective_values); digits=2),
            round(1.96 * std(objective_values) / sqrt(length(simulations)); digits=2),
        ),
    )
end

ss_df_p_nom = DataFrame(hcat(collect.(values.(ss_res_p_nom))...)', first.(all_p_nom))
ss_df_p_nom[!, "time"] = ["$it (SS)" for it in [2030, 2040, 2050]]
ss_df_p_nom = stack(ss_df_p_nom, Not(:time); variable_name=:asset, value_name=:value)

ss_df_gen = DataFrame(hcat(ss_res_gen...)', first.(all_gen))
ss_df_gen[!, "Storage (charge)"] .*= -1
ss_df_gen[!, "time"] = ["$it (SS)" for it in [2030, 2040, 2050]]
ss_df_gen = stack(ss_df_gen, Not(:time); variable_name=:asset, value_name=:value)

p = plot(ss_df_p_nom, kind="bar", x=:time, y=:value, color=:asset, Layout(title="Capacity (SS)", barmode="relative"))
display(p)
p = plot(ss_df_gen, kind="bar", x=:time, y=:value, color=:asset, Layout(title="Generation (SS)", barmode="relative"))
display(p)
