function add_demand!(model, config)
    oc = model.ext[:opt_container]

    name = config[:name]
    T = config[:T]
    node = config[:node]
    value = load_data("demand", config[:value]; t1=T[1], t2=T[end])

    # Shedding variable.
    shedding = oc.var["$name.shedding"] = @variable(model, [t = 1:length(T)], lower_bound = 0, container = Array)

    # Shedding cost/penalty.
    oc.obj["$name.shedding"] = @expression(model, sum(shedding))

    # Draw from the nodal balance.
    add_to_expression!.(oc.exp["$node.nodal_balance"], value, -1.0)
    add_to_expression!.(oc.exp["$node.nodal_balance"], shedding, 1.0)

    return nothing
end
