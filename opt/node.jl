function add_node!(model, config)
    oc = model.ext[:opt_container]

    name = config[:name]
    T = config[:T]

    oc.exp["$name.nodal_balance"] = [AffExpr(0.0) for t in 1:length(T)]

    return nothing
end
