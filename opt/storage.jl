function add_storage!(model, config)
    oc = model.ext[:opt_container]

    name = config[:name]
    T = config[:T]
    node = config[:node]
    year = T[1][1]

    annuity_p = config[:annuity_power] / 8736.0 * length(T)
    annuity_e = config[:annuity_energy] / 8736.0 * length(T)
    p_nom_max = config[:p_nom_max]
    e_nom_max = config[:e_nom_max]

    efficiency = sqrt(config[:roundtrip_efficiency])

    # Approximate "adjustment" of annuity.
    dy = year - 2030
    annuity_p_now = annuity_p * (1.0 - 0.62 * dy / 20.0)
    annuity_e_now = annuity_e * (1.0 - 0.49 * dy / 20.0)
    dy = (year + 2030) / 2.0 - 2030
    annuity_p_old = annuity_p * (1.0 - 0.62 * dy / 20.0)
    annuity_e_old = annuity_e * (1.0 - 0.49 * dy / 20.0)

    # Nominal power, and energy content.
    p_nom = oc.var["$name.p_nom"] = @variable(model, lower_bound = 0, upper_bound = p_nom_max, container = Array)
    e_nom = oc.var["$name.e_nom"] = @variable(model, lower_bound = 0, upper_bound = e_nom_max, container = Array)

    # Charge/discharge per time step.
    charge = oc.var["$name.charge"] = @variable(model, [t = 1:length(T)], lower_bound = 0, container = Array)
    oc.con["$name.charge_ub"] = @constraint(model, [t = 1:length(T)], charge[t] <= p_nom, container = Array)
    discharge = oc.var["$name.discharge"] = @variable(model, [t = 1:length(T)], lower_bound = 0, container = Array)
    oc.con["$name.discharge_ub"] = @constraint(model, [t = 1:length(T)], discharge[t] <= p_nom, container = Array)

    # State of charge (in energy).
    soc = oc.var["$name.soc"] = @variable(model, [t = 1:length(T)], lower_bound = 0, container = Array)
    oc.con["$name.soc_ub"] = @constraint(model, [t = 1:length(T)], soc[t] <= e_nom, container = Array)
    oc.con["$name.soc"] = @constraint(
        model,
        [t = 1:(length(T) - 1)],
        soc[t + 1] == soc[t] + charge[t] * efficiency - discharge[t] / efficiency,
        container = Array
    )

    # Add charge/discharge to the nodal balance.
    add_to_expression!.(oc.exp["$node.nodal_balance"], charge, -1.0)
    add_to_expression!.(oc.exp["$node.nodal_balance"], discharge, 1.0)

    # Relaxation penalties.
    _zp = @variable(model, lower_bound = 0, container = Array)
    _zm = @variable(model, lower_bound = 0, container = Array)

    # States (SDDP).
    state_p_nom =
        oc.ste["$name.p_nom"] = @variable(
            model,
            [[name]],
            SDDP.State,
            lower_bound = 0.0,              # does that affect performance?
            upper_bound = p_nom_max,        # does that affect performance?
            initial_value = 0.0,
            base_name = "state_p_nom"
        ).data[1]
    state_e_nom =
        oc.ste["$name.e_nom"] = @variable(
            model,
            [[name]],
            SDDP.State,
            lower_bound = 0.0,              # does that affect performance?
            upper_bound = e_nom_max,        # does that affect performance?
            initial_value = 0.0,
            base_name = "state_e_nom"
        ).data[1]
    state_soc =
        oc.ste["$name.soc"] = @variable(
            model,
            [[name]],
            SDDP.State,
            lower_bound = 0.0,              # does that affect performance?
            upper_bound = e_nom_max,        # does that affect performance?
            initial_value = 0.0,
            base_name = "state_soc"
        ).data[1]
    if config[:can_invest]
        @constraints(model, begin
            state_p_nom.in <= p_nom
            state_e_nom.in <= e_nom
        end)
    else
        @constraints(model, begin
            state_p_nom.in == p_nom
            state_e_nom.in == e_nom
        end)
    end
    @constraints(model, begin
        state_p_nom.out == p_nom
        state_e_nom.out == e_nom
        state_soc.in == soc[1] + _zp - _zm  # relax that to make it feasible for all initial states
        state_soc.out == soc[end] + charge[end] * efficiency - discharge[end] / efficiency
        soc[end] + charge[end] * efficiency - discharge[end] / efficiency >= 0
        soc[end] + charge[end] * efficiency - discharge[end] / efficiency <= e_nom
    end)

    # Total cost (for a change here, since we need the incoming state).
    invest_old_p = state_p_nom.in
    invest_old_e = state_e_nom.in
    invest_now_p = p_nom - invest_old_p
    invest_now_e = e_nom - invest_old_e
    oc.obj["$name.cost"] = @expression(
        model,
        annuity_p_now * invest_now_p +
        annuity_e_now * invest_now_e +
        annuity_p_old * invest_old_p +
        annuity_e_old * invest_old_e +
        _zm * 1e5 +
        _zp * 1e5
    )

    return nothing
end
