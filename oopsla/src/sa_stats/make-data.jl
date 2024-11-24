include("extract_method_types.jl")
data = run_analysis(ARGS[1])
write_out_all(data, ARGS[2])