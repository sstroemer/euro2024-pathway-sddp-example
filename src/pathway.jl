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

