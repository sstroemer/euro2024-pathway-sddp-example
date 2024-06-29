rule = SDDP.DecisionRule(model; node=105)
ogs = [
    Symbol("state_p_nom[Hydro]"),
    Symbol("state_p_nom[Storage]"),
    Symbol("state_p_nom[Gas Turbine (CH4)]"),
    Symbol("state_p_nom[Wind]"),
    Symbol("state_e_nom[Storage]"),
    Symbol("state_p_nom[PV]"),
    Symbol("state_p_nom[Gas Turbine (H2)]"),
    Symbol("state_soc[Storage]"),
]
solution = SDDP.evaluate(
    rule;
    incoming_state=Dict(it => 0.0 for it in ogs),
    noise=(0.5, 0.25, 0.5, 5e4),
    controls_to_record=[Symbol("__var__demand1.shedding")],
)

objective_values = [sum(stage[:stage_objective] for stage in sim) for sim in simulations]

μ = round(mean(objective_values); digits=2)
ci = round(1.96 * std(objective_values) / sqrt(500); digits=2)

println("Confidence interval: ", μ, " ± ", ci)
println("Lower bound: ", round(SDDP.calculate_bound(model); digits=2))

shedding = map(simulations[1]) do node
    return node[Symbol("__var__demand1.shedding")]
end
