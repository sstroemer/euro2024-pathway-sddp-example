function add_res!(model, config)
    oc = model.ext[:opt_container]

    name = config[:name]
    T = config[:T]
    node = config[:node]
    avail = load_data("res", config[:availability]; t1=T[1], t2=T[end])

    vom = config[:vom]
    annuity = config[:annuity] / 8736.0 * length(T)
    p_nom_max = config[:p_nom_max]

    # Nominal power.
    p_nom = oc.var["$name.p_nom"] = @variable(model, lower_bound = 0, container = Array)

    # Generation per time step.
    gen = oc.var["$name.gen"] = @variable(model, [t = 1:length(T)], lower_bound = 0, container = Array)
    oc.con["$name.gen_ub"] = @constraint(model, [t = 1:length(T)], gen[t] <= avail[t] * p_nom, container = Array)

    # Total cost.
    oc.obj["$name.cost"] = @expression(model, vom * sum(gen) + annuity * p_nom)

    # Add generation to the nodal balance.
    add_to_expression!.(oc.exp["$node.nodal_balance"], gen)

    # State.
    state_p_nom =
        oc.ste["$name.p_nom"] = @variable(
            model,
            [[name]],
            SDDP.State,
            lower_bound = 0.0,
            upper_bound = p_nom_max,
            initial_value = 0.0,
            base_name = "state_p_nom"
        ).data[1]
    if config[:can_invest]
        @constraint(model, state_p_nom.in <= p_nom)
    else
        @constraint(model, state_p_nom.in == p_nom)
    end
    @constraint(model, state_p_nom.out == p_nom)

    return nothing
end
