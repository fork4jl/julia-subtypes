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
lj_src = joinpath(dirname(@__FILE__()), "..")
log_name = ARGS[1]

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
decls_mode = 2 # custom dump
decls_dump_file = dumppath
if !isfile(decls_dump_file)
    println("INFO: No decls file found ($(decls_dump_file)) -- dumping it now")
    # #=
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
    # =#    
    fname_decls = decls_dump_file
    include(lj_src * "/aux/decls_dump.jl")
end

include(lj_src * "/validation/process_logs.jl")

