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
ss_df_p_nom[!, "time"] = ["$it (SS)" for it in [2030, 2040, 2050]]
ss_df_p_nom = stack(ss_df_p_nom, Not(:time); variable_name=:asset, value_name=:value)

ss_df_gen = DataFrame(hcat(ss_res_gen...)', first.(all_gen))
ss_df_gen[!, "Storage (charge)"] .*= -1
ss_df_gen[!, "time"] = ["$it (SS)" for it in [2030, 2040, 2050]]
ss_df_gen = stack(ss_df_gen, Not(:time); variable_name=:asset, value_name=:value)

p = plot(ss_df_p_nom; kind="bar", x=:time, y=:value, color=:asset, Layout(; title="Capacity (SS)", barmode="relative"))
display(p)
p = plot(ss_df_gen; kind="bar", x=:time, y=:value, color=:asset, Layout(; title="Generation (SS)", barmode="relative"))
display(p)
