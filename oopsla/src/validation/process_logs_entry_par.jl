#=
A setup facility for process_logs.jl

It handles two things before dispatching to process_logs.jl itself:

1. Execute a program which is the source for the log being processed.
    This setups valid context to process logs.
2. Dump pseudo-type declarations (using decls_dump.jl) in the context.

The tool interface is as follows:

    julia process_logs_entry.jl logfile [source-program] [decls-file]

Notes

1. [] means optional. But weather optional args are given or not implies 
   something on the first argument.

2. If logfile is the only argument, it should be given as a path containing at 
   least the name of the parent directory. Moreover, in this case:
   1. Logfile's parent dir name = project name.
   2. Log-file name: $(mode)-... -- where $(mode) is either add or test.
   3. Program which is the source for log should be next to log-file and 
        have the name: $(mode)-$(project).jl
        
   This requirements are rised from the output format of `collect_logs.py`
   utility (bulk logging of zillions of projects with `Pkg.add` / `Pkg.test` programs.

3. Second argument, if given, provides a name of the program which was the 
   source of the log.

4. Third argument: If you don't have a type databse named `source-name.json`, 
   you can either wait while it is dumped by this script or supply another file 
   for it (third argument).
=#

if length(ARGS) < 1 || !isfile(ARGS[1])
    println("You havent provided log file to validate against.\n"
            * "Absolute path required.")
    if length(ARGS) > 0
        println(ARGS[1])
    end
    exit()
end

# Main constants
lj_src = joinpath(dirname(@__FILE__()), "..") # subprocesses have wrong _FILE_
log_name = ARGS[1]

sourcepath = ""
# Define:
# - sourcepath -- a path to the target program
# - dumppath -- a path to the target program
if (length(ARGS) > 1) # we process a log of a program given as second arg
    sourcepath = joinpath(pwd(), ARGS[2])
    dumppath = sourcepath * ".json"
else # we process a log of a program named as described in file header (proj/mode-...jl)
    # Basic paths from a single parameter -- log-file name
    log_basename = basename(log_name)
    proj_dir = dirname(log_name)
    proj_name = basename(proj_dir)

    # Computing mode
    dashIdx = search(log_basename, '-')
    if dashIdx == 0
        println("Unxpected log file-name $(log_name): should be `mode-smth`")
        exit()
    end
    mode_log = log_basename[1:dashIdx-1]

    # Target program filename
    sourcename = "$(mode_log)-$(proj_name).jl"
    sourcepath = joinpath(proj_dir, "$(sourcename)")
    dumppath = joinpath(proj_dir, "$(mode_log)-decls_inferred.json")
end

if (length(ARGS) > 2) # avoid dumping type base, use given one
    dumppath = ARGS[3]
end

# ---------v

# Handle type decls dump
@everywhere decls_mode = 2 # custom dump
decls_dump_file = dumppath
if !isfile(decls_dump_file)
    println("INFO: No decls file found ($(decls_dump_file))")
    println("INFO: Execute a source program of a log to get valid context for dumping...")
    oldArgs = Base.ARGS
    ARGS = []
    try
        include(sourcepath)
        println("INFO: Program has been successfully executed")
    catch e
        println("WARNING: There were errors inside target program ($(sourcepath)):\n$(e)")
    end
    ARGS = oldArgs
    fname_decls = decls_dump_file
    include(lj_src * "/aux/decls_dump.jl")
end



# This is needed to pass values of sourcepath and decls_dump_file into workers
ENV["LJ_SOURCEPATH"] = sourcepath
ENV["LJ_DECLSDUMP"]  = decls_dump_file

# We need correct values of variables [lj_src], [sourcepath], [decls_dump_file]
# on all workers, but they are only initialized on the main process.

# put info into channel
lj_info_channel = RemoteChannel(() -> Channel{Tuple}(1))
put!(lj_info_channel, (lj_src, sourcepath, decls_dump_file))

# load info on the workers
@everywhere function lj_info_load(lj_info_channel :: RemoteChannel)
    info = fetch(lj_info_channel)
    global lj_src = info[1]
    global sourcepath = info[2]
    global decls_dump_file = info[3]
end
for pid in workers()
    remotecall_fetch(lj_info_load, pid, lj_info_channel)
end
close(lj_info_channel)

include(lj_src * "/validation/process_logs_par.jl")

