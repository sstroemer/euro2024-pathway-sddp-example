str_log = """
         1   5.474826e+10  2.154546e+08  2.042306e+00       312   1
         2   5.753215e+10  2.157695e+08  3.104596e+00       624   1
         4   2.979862e+10  2.174987e+08  4.797703e+00      1248   1
         6   2.567744e+10  2.179989e+08  6.405178e+00      1872   1
         8   1.992340e+10  9.898696e+08  7.891306e+00      2496   1
         9   6.843163e+10  1.047175e+09  8.936938e+00      2808   1
        15   1.955237e+10  1.160310e+10  1.447013e+01      4680   1
        21   2.114184e+10  1.195667e+10  1.984421e+01      6552   1
        27   1.930518e+10  1.203886e+10  2.496470e+01      8424   1
        33   1.932154e+10  1.409399e+10  3.025204e+01     10296   1
        39   1.938724e+10  1.725039e+10  3.596374e+01     12168   1
        45   1.998846e+10  1.807160e+10  4.132036e+01     14040   1
        52   1.889311e+10  1.819202e+10  4.653912e+01     16224   1
        59   1.887898e+10  1.846915e+10  5.193754e+01     18408   1
        66   1.876446e+10  1.850088e+10  5.697399e+01     20592   1
        73   1.871713e+10  1.853813e+10  6.198036e+01     22776   1
        80   1.868898e+10  1.854049e+10  6.732085e+01     24960   1
        87   1.867896e+10  1.854716e+10  7.281160e+01     27144   1
        94   1.877061e+10  1.855022e+10  7.816332e+01     29328   1
       101   1.878288e+10  1.857333e+10  8.350170e+01     31512   1
       108   1.874037e+10  1.860645e+10  8.894291e+01     33696   1
       115   1.870771e+10  1.861459e+10  9.419684e+01     35880   1
       122   1.868697e+10  1.861785e+10  9.946756e+01     38064   1
       129   1.869691e+10  1.862040e+10  1.048418e+02     40248   1
       136   1.868010e+10  1.862934e+10  1.102054e+02     42432   1
       143   1.868972e+10  1.864296e+10  1.153775e+02     44616   1
"""

# 183   1.866706e+10  1.865456e+10  1.455324e+02     57096   1
# 222   1.865903e+10  1.865747e+10  1.755574e+02     69264   1
# 250   1.865956e+10  1.865818e+10  1.966157e+02     78000   1
# -------------------------------------------------------------------
# status         : iteration_limit
# total time (s) : 1.966157e+02
# total solves   : 78000
# best bound     :  1.865818e+10
# simulation ci  :  1.989152e+10 ± 6.303626e+08
# numeric issues : 0
# -------------------------------------------------------------------

entries = []
for l in split(str_log, "\n")
    startswith(l, " ") || continue
    push!(entries, string.(split(l, " "; keepempty=false)))
end

df_perf = DataFrame(parse.(Float64, hcat(entries...))', ["iteration", "simulation", "bound", "time", "solves", "-"])
df_perf = stack(df_perf, Not(:time, :iteration, :solves, Symbol("-")); variable_name=:value, value_name=:v)
df_perf.v .*= 1e-6

p = plot(
    df_perf,
    kind="scatter",
    x=:iteration,
    y=:v,
    color=:value,
    mode="markers+lines",
    academic_layout("Convergence of total objective value", "iteration", "cost [M EUR]") do l
        l.yaxis["type"] = "log"
        delta = maximum(df_perf.iteration) - minimum(df_perf.iteration)
        return l.xaxis["range"] =
            [minimum(df_perf.iteration) - delta * 0.05, maximum(df_perf.iteration) + delta * 0.05]
    end,
)
savefig(p, "plots/performance_i.png"; scale=3.0, width=1000, height=400)

p = plot(
    df_perf,
    kind="scatter",
    x=:time,
    y=:v,
    color=:value,
    mode="markers+lines",
    academic_layout("Convergence of total objective value", "time [s]", "cost [M EUR]") do l
        l.yaxis["type"] = "log"
        delta = maximum(df_perf.time) - minimum(df_perf.time)
        return l.xaxis["range"] = [minimum(df_perf.time) - delta * 0.05, maximum(df_perf.time) + delta * 0.05]
    end,
)
savefig(p, "plots/performance_t.png"; scale=3.0, width=1000, height=400)
