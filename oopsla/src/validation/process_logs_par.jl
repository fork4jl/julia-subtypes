## We temporarily redirect stderr to /dev/null, 
## so that we don't see errors of a source program
@everywhere begin
    stderr_default = STDERR
    stderr_null = nothing
    stderr_null_on = false
    # #=
    if ispath("/dev/null")
        stderr_null = redirect_stderr(open("/dev/null", "w"))
        println("WARNING: stderr was redirected to /dev/null for clarity")
        stderr_null_on = true
    end
    # =#
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
    if stderr_null_on
        close(stderr_null)
        redirect_stderr(stderr_default)
        println("WARNING: stderr was switch on again")
    end
end    


## Now we include [type_validator] definitions on all processes
@everywhere include(lj_src * "/lj.jl")
## And [Monads] module
@everywhere include(lj_src * "/validation/Monads.jl")


## This module incapsulates everything we need for parallelism
@everywhere module LogsProcessingParallel

export ValStats, addStats, compute_neg, 
       StatsDict, makeStatsDict, make_report_table,
       worker_job, 
       logFileNames, make_pid_filename, 
       LogEntry, PROCESS_LOGS_DONE
       
using Monads

using lj:
      replace_hashes_not_in_lits,
      ASTBase, lj_AST_size,
      lj_subtype_ast_entry, lj_typeof_ast_entry,
      lj_subtype_ast_entry_revised,
      lj_subtype_trivial_ast_entry,
      LJSUBT_UNDEF, LJSUBT_TRUE, LJSUBT_FALSE,
      LJErrTermInType, LJErrCannotParse,
      LJErrNameNotFound, LJErrNameAmbiguous,
      LJErrIInType, LJErrGetfield,
      LJErrTypeNotWF, LJErrFreeVar, LJErrTypeTooLarge,
      lj_parse_type, lj_expr_size, 
      Stats, RulesStats, addStats

using Main.lj_src

import lj.addStats

## All functions responsible for log validation 
## are defined in [process_logs_body.jl]
include(lj_src * "/validation/process_logs_body.jl")

#######################    Parallelism Utilities   #############################

struct LogEntry
    type1  :: String
    type2  :: String
    result :: String
end
    
# integer in 1..100 (each PROCESS_STEP percents a worker reports on progress)
const PROCESS_STEP = 5 #10 #1 
# end of a worker's job
const PROCESS_LOGS_DONE = 666


## Main worker's function 
function worker_job(
    log_out_dir::String, # log directory
    sourcepath::String,  # path to the source program logged  
    infochannel :: RemoteChannel, # channel for reports
    srcdata  # source array with data to be processed
) :: StatsDict
    # #=
    if ispath("/dev/null")
        stderr_null = redirect_stderr(open("/dev/null", "w"))
        #println("WARNING: stderr was redirected to /dev/null for clarity")
    end
    # =#
    ## --- prepare data for logging
    sdict = makeStatsDict()
    fdict = makeFilesDict(log_out_dir, true)
    ## --- main part
    put!(infochannel, "Process #" * string(myid()) * " started")
    rangelen::Int = length(srcdata)
    portion = div(rangelen, div(100, PROCESS_STEP))
    #println(myid(), " - ", portion)
    step::Int = 1
    progress::Int = PROCESS_STEP
    ## --- worker's loop
    for entry in srcdata
        sdict["parser_s"].cnt += 2
        # 
        #=
        println("------ Proc for:")
        println("entry.type1: $(entry.type1)")
        println("entry.type2: $(entry.type2)")
        println("entry.result: $(entry.result)")
        # =#
        proc(entry.type1, entry.type2, entry.result, sdict, fdict)
        # println("====== end proc")
        if step == portion       
            put!(infochannel, (myid(), progress))
            progress += PROCESS_STEP
            step = 1
        else
            step += 1
        end
    end
    ## --- closing files
    for kv in fdict
        (k, v) = kv
        close(v)
    end
    put!(infochannel, (myid(), 100))
    put!(infochannel, PROCESS_LOGS_DONE) # end of work 
    sdict
end

end # LogsProcessingParallel


using LogsProcessingParallel

#######################    Main Process Utilities   ############################

## splits an array into pieces for workers from workerpids
function distribute_work(workerpids :: AbstractVector{Int}, 
                         srcdata :: AbstractVector
) :: Vector{Tuple{Int, UnitRange{Int}}}  
    ranges = Vector{Tuple{Int, UnitRange{Int}}}()
    workercnt = length(workerpids)
    if workercnt == 0
        throw(ArgumentError("Pool of workers is empty"))
    end
    datacnt = length(srcdata)
    portion = div(datacnt, workercnt)
    # just in case, if we have little to do
    if portion == 0
        push!(ranges, (workerpids[1], 1:datacnt))
        return ranges
    end
    currind = 1
    for i in 1:workercnt-1
        endind = currind+portion-1
        push!(ranges, (workerpids[i], currind:endind))
        currind = endind + 1
    end
    push!(ranges, (workerpids[workercnt], currind:datacnt))
    ranges
end

## calculates overall progress given progresses of workers
function overall_progress(data :: AbstractVector{Int})
    datalen = length(data)
    datasum = sum(data)
    datalen > 2 ? div(datasum, datalen - 1) : datasum
end

## main process receives and prints info about workers' progress
function process_progress_info(infochannel::RemoteChannel, workerscnt::Int)
    endscnt :: Int = 0
    progresses = Vector{Int}(workerscnt+1)
    for i in 1:workerscnt+1
        progresses[i] = 0
    end   
    print("Progress: ")
    while (endscnt < workerscnt)
        nextval = take!(infochannel)
        if nextval == PROCESS_LOGS_DONE
            endscnt += 1
        elseif isa(nextval, Tuple{Int, Int})
            (pid, progress) = nextval
            progresses[pid] = progress
            print(overall_progress(progresses), "% ")
        else
            #println(nextval)
        end
    end
    println("\nProcesses completed")
end

## fetch workers' results and calculates the whole result
function fetch_results(results :: Vector{Future})
    print("Fetching results... ")
    sdict = makeStatsDict()
    for result in results
        r = fetch(result)
        sdict["parser_s"]  = addStats(sdict["parser_s"], r["parser_s"])
        sdict["typeof_s"]  = addStats(sdict["typeof_s"], r["typeof_s"])
        sdict["subtype_s"] = addStats(sdict["subtype_s"], r["subtype_s"])
        addStats(sdict["rules_s"], r["rules_s"])
    end
    println("Done")
    sdict
end

function fetch_and_println(results :: Vector{Future})
    println("Fetch results:")
    for result in results
        r = fetch(result)
        println(r)
    end
end

function concatenate_files(prefix :: String, suffix :: String,
                           ranges :: Vector{Tuple{Int, UnitRange{Int}}})
    resfname = prefix * suffix
    resf = open(resfname, "w")
    for (pid, _) in ranges
        fname = make_pid_filename(prefix, suffix, pid)
        f = open(fname, "r")
        lines = readlines(f)
        Base.join(resf, lines, "\n")
        println(resf)
        close(f)
    end    
    close(resf)
end

function remove_files(prefix :: String, suffix :: String,
                      ranges :: Vector{Tuple{Int, UnitRange{Int}}})
    for (pid, _) in ranges
        fname = make_pid_filename(prefix, suffix, pid)
        rm(fname)
    end    
end

function concat_and_rm_log_files(log_out_dir::String,
                                 ranges::Vector{Tuple{Int, UnitRange{Int}}})
    fnames = logFileNames(log_out_dir, true)
    for kv in fnames
        (k, (name, ext)) = kv
        concatenate_files(name, ext, ranges)
        remove_files(name, ext, ranges)
    end
end


##############################      Main       #################################

println("Log validation started")

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
res_fname = joinpath(log_out_dir, "results-par.txt")

if !isdir(log_out_dir)
    mkdir(log_out_dir)
end

### Process

lns = readlines(log_name)
lenlns = length(lns)

print("Preparing source array...")
# convert array of lines into array of LogEntry
logdata = LogEntry[]
line_i = 1
while line_i <= lenlns - 3
    push!(logdata, 
          LogEntry(lns[line_i], lns[line_i+1], lns[line_i+2]))
    line_i += 4
end
println("Done")

srcdata = logdata

println("Workers: ", workers())
workerpids = workers()
workercnt = length(workerpids)

ranges = distribute_work(workerpids, srcdata)
#println("Ranges:\n", ranges)

results = Vector{Future}()
progressinfo = RemoteChannel(() -> Channel{Any}(64))

print("Running workers... ")
for (pid, range) in ranges
    rslt = remotecall(worker_job, pid, 
                      log_out_dir, sourcepath, 
                      progressinfo, srcdata[range])
    push!(results, rslt)
end
println("Done")

println("Waiting for results...")
process_progress_info(progressinfo, length(ranges))

#fetch_and_println(results)
sdict = fetch_results(results)

close(progressinfo)

print("Processing results... ")

concat_and_rm_log_files(log_out_dir, ranges)

res_f  = open(res_fname, "w")
println(res_f, make_report_table(log_name, sdict))
close(res_f)

if !Core.isdefined(:JSON)
    using JSON
end

# #=
open(joinpath(log_out_dir,"results-par.json"), "w") do f
    JSON.print(f, Dict(   :parser  => sdict["parser_s"]
                        , :typeof  => sdict["typeof_s"]
                        , :subtype => sdict["subtype_s"]), 4)
end
open(joinpath(log_out_dir,"rules-stats-par.json"), "w") do f
    JSON.print(f, sdict["rules_s"], 4)
end
open(joinpath(log_out_dir,"rules-stats-par.txt"), "w") do f
    show_dict_sort_v(f, sdict["rules_s"].s)
end
# =#
println("Done")

