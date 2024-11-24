
# #=
println("INFO: Execute a source program to get a valid context for log validation:")
println("*** include($(sourcepath))")
oldArgs = ARGS
ARGS = []
try      
    include(sourcepath)
    println("INFO: Program has been successfully executed")
catch e
    #println("WARNING: There were errors inside target program ($(sourcepath)):\n$(e)") # AE
end
ARGS = oldArgs
# =#

#include(lj_src * "/lj.jl")
push!(LOAD_PATH, lj_src)
using lj

#include(lj_src * "/validation/Monads.jl")
push!(LOAD_PATH, lj_src * "/validation")
using Monads

import lj.addStats

## All functions responsible for log validation 
## are defined in [process_logs_body.jl]
include("process_logs_body.jl")


########################      Main       ########################

start = true # debug
if !start
    tralala
end

### Looking up log file name to process
if !Core.isdefined(:log_name)
    log_name = "../../logging/sample-progs/empty-prog/log_subt.txt"
end
if length(ARGS) == 0 || !isfile(ARGS[1])
    println("INFO: You haven't provided a trace file as either a" *
    " first command-line argument or `log_name` variable, " *
    "defaulting to $(log_name)")
else
    #println("we got the arg!")
    log_name = ARGS[1]
end

# Redirect stderr to /dev/null (non-portable) #=
if ispath("/dev/null")
   redirect_stderr(open("/dev/null"))
   println("WARNING: stderr was redirected to /dev/null for clarity")
end
# =#

### Main paths

base_no_ext(s) = basename(s)[1:end-4]

log_base = base_no_ext(log_name)
log_out_dir = joinpath(dirname(log_name), log_base)
res_fname = joinpath(log_out_dir, "results.txt")

if !isdir(log_out_dir)
    mkdir(log_out_dir)
end

# Open all log files
sdict = makeStatsDict()
fdict = makeFilesDict(log_out_dir)

### Process

lns = readlines(log_name)
lenlns = length(lns)
workload = div(length(lns), 4)
wl_10per = div(workload, 10)
print("\nProgress: 0% ")
cnt = 1
cntw = 0
#Profile.init(n = 10^7, delay = 0.01)
while start && cnt <= lenlns - 3

    #println("#", cnt)

    # Rendering progress bar
    cntw += 1
    if wl_10per != 0 && mod(cntw, wl_10per) == 0
        print("$(div(cntw, wl_10per))0% ")
    end

    # Update values for new iteration
    sdict["parser_s"].cnt += 2 # We asume we have two more types in the log, though
                      # they may be complete garbage (that's why parser_s and
                      # not typeof_s here)
    t1 = lns[cnt]            # type 1
    t2 = lns[cnt+1]          # type 2
    res_str = lns[cnt+2]
    cnt += 4 # empty line

    #
    #=
    println("---- before proc $(cnt)")
    println("t1: $(t1)")
    println("t2: $(t2)")
    println("res_str: $(res_str)")
    # =#
    #@profile 
    proc(t1, t2, res_str, sdict, fdict)
    #println("==== end proc $(cnt)")
end

println()
for (k, v) in fdict
    close(v)
end

res_f  = open(res_fname, "w")
println(res_f, make_report_table(log_name, sdict))
close(res_f)

dep1 = "JSON"
if isa(Pkg.installed(dep1), Void)
  Pkg.add(dep1)
end
eval(Meta.parse("using $(dep1)"))

open(joinpath(log_out_dir,"results.json"), "w") do f
    JSON.print(f, Dict(   :parser  => sdict["parser_s"]
                        , :typeof  => sdict["typeof_s"]
                        , :subtype => sdict["subtype_s"]), 4)
end
open(joinpath(log_out_dir,"rules-stats.json"), "w") do f
    JSON.print(f, sdict["rules_s"], 4)
end
open(joinpath(log_out_dir,"rules-stats.txt"), "w") do f
    show_dict_sort_v(f, sdict["rules_s"].s)
end



