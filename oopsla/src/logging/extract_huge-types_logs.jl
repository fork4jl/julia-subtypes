################################################################################
### Generates file with full subtype logs from the file with types 
################################################################################

## We have [huge-types.txt] files that only contain big types.
## But validation runs on full subtype log entries (two types + result).
## Thus, we have to extract full entries having types only.

## *****************************************************************************
## Aux general functions
## *****************************************************************************

function lj_find_from(val :: T, xs :: Vector{T}, from_i :: Int) where T
  while from_i <= length(xs)
    if xs[from_i] == val
      return from_i
    end
    from_i += 1
  end
  return 0 # didn't find [val]
end

function lj_writelines(lines :: Vector{String}, fname :: String)
  f  = open(fname, "w")
  for ln in lines 
    println(f, ln)
  end
  close(f)
end


## *****************************************************************************
## Extraction of log entries with huge types
## *****************************************************************************

## Note that huge types are written in the order they appear in the log file.
## To be sure we take correct entries, we scan logs in order.

## Note. This doesn't work for corrupted log!

# extract full log entries containing types-elements of huge_types from full_log
function lj_extrhgtys_get_entries(huge_types :: Vector{String},
                                  full_log   :: Vector{String})
  rslt = String[]
  log_i :: Int = 1
  # remove empty lines from huge_types
  for htype in filter(s -> s != "", huge_types)
    htype_i = lj_find_from(htype, full_log, log_i)
    # for some reason, type was not found in logs ==> just skip it
    if htype_i == 0
      continue
    end
    # htype might be the first or the second type in the entry
    # if it's the very first line of log or prev line is empty,
    #   htype is the first type
    (t1, t2, r) = ("", "", "")
    if htype_i == 1 || full_log[htype_i-1] == ""
      t1 = full_log[htype_i]
      t2 = full_log[htype_i+1]
      r  = full_log[htype_i+2]
      log_i = htype_i + 4
    # otherwise it's the second type in the entry
    else
      t1 = full_log[htype_i-1]
      t2 = full_log[htype_i]
      r  = full_log[htype_i+1]
      log_i = htype_i + 3
    end
    push!(rslt, t1)
    push!(rslt, t2)
    push!(rslt, r)
    push!(rslt, "")
  end
  rslt
end

# extract full log entries containing types-lines of the file huge_types_fname
# from the file full_log_fname
function lj_extrhgtys_get_entries(huge_types_fname :: String, 
                                  full_log_fname   :: String)
  huge_types = readlines(huge_types_fname)
  full_log   = readlines(full_log_fname)
  if length(huge_types) > 0 && length(full_log) > 3
    return lj_extrhgtys_get_entries(huge_types, full_log)
  else
    return String[]
  end
end


## *****************************************************************************
## Bulk extraction of log entries with huge types for log dirs
## *****************************************************************************

# extract huge types from the log [pkg_log_dname] with the prefix [prefix]
function lj_extrhgtys_process_log(prefix :: String, pkg_log_dname :: String)
  logname = prefix * "-log_subt"
  subt_log_fname   = joinpath(pkg_log_dname, logname * ".txt")
  if !isfile(subt_log_fname)
    return false
  end
  # first try parallel version
  huge_types_fname = joinpath(pkg_log_dname, logname, "huge-types-par.txt")
  if !isfile(huge_types_fname)
    huge_types_fname = joinpath(pkg_log_dname, logname, "huge-types.txt")
    if !isfile(huge_types_fname)
      return false
    end
  end
  # we have both huge-types and log files now,
  # but huge_types might be empty
  if find(s -> s!="", readlines(huge_types_fname)) == []
    return false
  end
  println("INFO: extract huge types for $(prefix)-$(basename(pkg_log_dname)):") 
  #println("      ($(subt_log_fname), $(huge_types_fname)) >>> $(hgtys_subt_log_fname)")
  hgtys_log = lj_extrhgtys_get_entries(huge_types_fname, subt_log_fname)
  hgtys_subt_log_fname = joinpath(pkg_log_dname, logname * "_ht.txt")
  lj_writelines(hgtys_log, hgtys_subt_log_fname)
  println(hgtys_subt_log_fname)
  return true
end

function lj_extrhgtys_process_dir(pkg_log_dname)
  for prefix in ["add", "test"]
    lj_extrhgtys_process_log(prefix, pkg_log_dname)
  end
end

function lj_extract_all_huge_types(logs_dirname)
  dirnames = readdir(logs_dirname)
  for dname in dirnames
    dname = joinpath(logs_dirname, dname)
    if !isdir(dname)
      continue
    end
    lj_extrhgtys_process_dir(dname)
  end
end

## *****************************************************************************
## Entry points to extraction
## *****************************************************************************

function lj_extract_huge_types_entry()
  if length(ARGS) < 3 
    print("ERROR: Two file names are required as arguments after -f: ")
    println("<huge-types-file> and <full-subt-log-file>")
  elseif !isfile(ARGS[2]) || !isfile(ARGS[3])
    println("ERROR: Both arguments <huge-types-file> and <full-subt-log-file> should be text files")
  else
    rslt = lj_extrhgtys_get_entries(ARGS[2], ARGS[3])
    for str in rslt
      println(str)
    end
  end
end

function lj_extract_huge_types_for_log_entry()
  if length(ARGS) < 2
    println("ERROR: <single-pkg-logs-dir> name is required as an argument after -d")
  elseif !isdir(ARGS[2])
    println("ERROR: <single-pkg-logs-dir> should be a directory")
  else
    log_dname = abspath(ARGS[2])
    lj_extrhgtys_process_dir(log_dname)
  end
end

function lj_extract_all_huge_types_entry()
  if length(ARGS) < 2
    println("ERROR: <all-pkgs-logs-dir> name is required as an argument after -a")
  elseif !isdir(ARGS[2])
    println("ERROR: <all-pkgs-logs-dir> should be a directory")
  else
    logs_dname = abspath(ARGS[2])
    lj_extract_all_huge_types(logs_dname)
  end
end


function lj_extrhgtys_entry()
  script_name = "extract_huge-types_logs.jl"
  run_usage_msg = "Run $(script_name) without arguments to learn about the usage."
  if length(ARGS) == 0
    println("INFO: No input provided for extraction.")
    println("      Use one of these formats to run huge-types extraction:")
    println("      1] $(script_name) -f <huge-types-file> <full-subt-log-file>")
    println("      2] $(script_name) -d <single-pkg-logs-dir>")
    println("      3] $(script_name) -a <all-pkgs-logs-dir>")
  elseif ARGS[1] == "-f"
    lj_extract_huge_types_entry()
  elseif ARGS[1] == "-d"
    lj_extract_huge_types_for_log_entry()
  elseif ARGS[1] == "-a"
    lj_extract_all_huge_types_entry()
  else
    println("ERROR: Unknown mode $(ARGS[1]). ", run_usage_msg)
  end
end

function lj_extract_huge_types_main()
  try
    lj_extrhgtys_entry()
  catch e
    println("ERROR during extraction:")
    println(e)
  end
end


lj_extract_huge_types_main()

