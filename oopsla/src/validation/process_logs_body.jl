################################################################################
### Shared functionality of parallel and non-parallel versions
### of [process_logs*.jl].
### 
### !!!ATTENTION!!! 
### This file is not to be run. 
### It is to be included into [process_logs*.jl]
################################################################################

const MAX_TYPE_SIZE = 1000
const LJ_SUB_REVISED = false

# if lj_validation_max_type_size == true, big types are skipped
# make false if all logs should be processed 
lj_validation_max_type_size = false #true

### !!! Module [Monads] has to be loaded

##########################    Statistics utilities    ##########################

mutable struct ValStats <: Stats
    cnt :: Int
    pos :: Int
    neg :: Int
    exc :: Int
    nnf :: Int
    varg    :: Int
    tt      :: Int
    freevar :: Int
    undersc :: Int
    capany  :: Int
    getf    :: Int
    logfail :: Int
    toolarge:: Int
    trivial :: Int
end
ValStats() = ValStats(0,0,0,0,0,0,0,0,0,0,0,0,0,0)

import Main.addStats
function addStats(x::ValStats, y::ValStats)
    result = ValStats()
    for currfield in fieldnames(ValStats)
        val = getfield(x, currfield) + getfield(y, currfield)
        setfield!(result, currfield, val)
    end
    result
end

function compute_neg(s :: ValStats)
    s.neg = s.cnt - s.pos - s.exc - s.nnf - s.varg - s.tt - s.freevar - s.undersc - s.capany - s.getf - s.logfail - s.toolarge - s.trivial
end

StatsDict = Dict{String, Stats}
FilesDict = Dict{String, IOStream}

lwpad(w :: Int) = (s :: Union{String, Int}) -> lpad(s, w)

function make_report_table(log_name :: String, sdict :: StatsDict) :: String
    parser_s = sdict["parser_s"]
    typeof_s = sdict["typeof_s"]
    subtype_s = sdict["subtype_s"]

    compute_neg(parser_s)
    compute_neg(typeof_s)
    compute_neg(subtype_s)

    w = 7
    lpad = lwpad(w)
    dash = "--"
    
    resStr = """
Tested: $(log_name)

            | Parser  | Typeof  | Subtype
------------------------------------------
Total       | $(lpad(parser_s.cnt)) | $(lpad(typeof_s.cnt)) | $(lpad(subtype_s.cnt))
Trivial     | $(lpad(dash)) | $(lpad(dash)) | $(lpad(subtype_s.trivial))
Passed      | $(lpad(parser_s.pos)) | $(lpad(typeof_s.pos)) | $(lpad(subtype_s.pos))
Failed      | $(lpad(parser_s.neg)) | $(lpad(typeof_s.neg)) | $(lpad(subtype_s.neg))
Exceptions  | $(lpad(parser_s.exc)) | $(lpad(typeof_s.exc)) | $(lpad(subtype_s.exc))
Unkn names  | $(lpad(dash)) | $(lpad(dash)) |   --
Getfields   | $(lpad(dash)) | $(lpad(typeof_s.getf)) |   --
ANY         | $(lpad(dash)) | $(lpad(typeof_s.capany)) |   --
Varargs     | $(lpad(parser_s.varg)) | $(lpad(dash)) |   --
Underscores | $(lpad(parser_s.undersc)) | $(lpad(dash)) |   --
Term in type| $(lpad(parser_s.tt)) | $(lpad(dash)) |   --
Free var    | $(lpad(parser_s.freevar)) | $(lpad(dash)) |   --
Log failures| $(lpad(parser_s.logfail)) | $(lpad(dash)) |   --
Huge Types  | $(lpad(parser_s.toolarge)) | $(lpad(dash)) |   --
"""
    resStr
end

##########################    Logging utilities   ##############################
#
# Not that logs! A new ones -- the results of a validation

function my_file_log_raw(f, t1, t2, r)
  println(f, t1, "\n", t2, "\n", r, "\n")
end

function my_file_log_subtype(f, t1, t2, r)
  println(f, t1, "\n", t2, "\n-> ", r, "\n")
end

function my_file_log_typeof(f, t)
  println(f, t)
end

function my_file_log_subtype(f, t1, t2, r, e)
  e1 = lj_trunc("$(e)")
  println(f, t1, "\n", t2, "\n-> ", r, "\nError: $(e1)", "\n")
end

function my_file_log_typeof(f, t, e)
  e1 = lj_trunc("$(e)")
  println(f, t, "\nError: $(e1)", "\n")
end

function lj_trunc(s :: String)
  if length(s) > 200
    s = s[1:200] * "... (truncated for clarity)"
  end
  s
end

######  Checking utilities: compare results of LJ with ones from the logs  #####
#                       or sanity-check the logs themselves

# Turn String into a (Julia's) thing
parsenhash(s :: String) = Meta.parse(replace_hashes_not_in_lits(s))
reify(x :: String) = eval(Main, parsenhash(s))
reify(x :: Union{Expr, Symbol}) = eval(Main, x)
#SourceProgramEnvModule.eval(Meta.parse(replace_hashes_not_in_lits(x)))

# Check lj_typeof
function check_typeof(ts :: String, tast :: ASTBase, tt :: Type)
    u = typeof(tt)
    v = lj_typeof_ast_entry(tast)
    su = string(lj_parse_type("$(u)"))
    sv = "$(v)"
    r = su == sv ? 1 : 0
    (r, su, sv)
end

# Logs should make sense from Julia's point of view
function check_log(t1, t2, refres :: Bool)
    refres == issubtype(t1, t2)
end

# Check lj_subtype
function check_subtype(t1 :: ASTBase, t2 :: ASTBase, refres :: Bool)
#    println("Check subtype: $(t1) <: $(t2)")
    # we first try out "trivial subtyping"
    (r, stats) = lj_subtype_trivial_ast_entry(t1, t2)
    # if it does not know the answer, we run full subtyping
    if r == LJSUBT_UNDEF
        sr = LJ_SUB_REVISED ? 
                lj_subtype_ast_entry_revised(t1, t2) : 
                lj_subtype_ast_entry(t1, t2)
        (res, stats) = (sr.sub, sr.stats)
        res == refres ? 1 : 0, stats
    else # otherwise it's false
        #@assert (r == LJSUBT_TRUE ? refres : !refres)
        #2, stats
        res = r == LJSUBT_TRUE
        res == refres ? 2 : 0, stats
    end
end

########################## Validation utilities ################################
############## validation is checking (as above) + error handling ##############

function validate_type(ts :: String, sdict :: StatsDict, fdict :: FilesDict)
  try
    texpr = parsenhash(ts)
    if lj_validation_max_type_size && lj_expr_size(texpr) > MAX_TYPE_SIZE
      throw(LJErrTypeTooLarge())
    end
    t = reify(texpr)
    #println("*** $(ts)") # println("&&& $(t)")
    #zzz = TyMock(t) # println("%%%")
    #xxx = Maybe(t) #println("---") #xxx
    if isa(t, Bool)
      throw(LJErrFreeVar("Looks like a constrained type variable"))
    end
    Maybe(t)
  catch e
    if isa(e, UndefVarError) || isa(e, LJErrFreeVar) ||
        isa(e,TypeError) && typeof(e.got) == UniformScaling{Int} # contains I
      my_file_log_typeof(fdict["exce_freevar_f"], ts, e)
      sdict["parser_s"].freevar += 1
    elseif isa(e, LJErrTypeTooLarge)
      sdict["parser_s"].toolarge += 1
      my_file_log_typeof(fdict["huge_types_f"], ts)
    else 
      my_file_log_typeof(fdict["fail_log_f"], ts, e)
      sdict["parser_s"].logfail += 1
    end
    Maybe{Void}()
  end
end

function validate_res_format(res_str :: String, t1 :: String, t2 :: String,
                             sdict :: StatsDict, fdict :: FilesDict)
    # Sanity check of logs #1: type-1 failure mean we found complete garbage
    # This should not happen after improvement of logging infrastructure
    if length(res_str) != 4 || !(res_str[4] in ['0', '1'])
        #println("WARNING: non-parsable result string")
        println(fdict["fail_log_f"], "type-1 failure (corrupted log)")
        sdict["parser_s"].logfail += 2
        my_file_log_raw(fdict["fail_log_f"], t1, t2, res_str)
        Maybe{Bool}()
    else
        sub_res = (res_str[4] == '1')  # result of t1 <: t2
        Maybe(sub_res) #Maybe{Bool}(sub_res)
    end
end

# Sanity check of logs: Julia should agree on what we've found in logs
function validate_log(t1, t2, sub_res :: Bool,
                      sdict :: StatsDict, fdict :: FilesDict)
    # tt1/2 should by Type{T} where T, but in some (ill-formed) cases can be smth else
    try
        cl = check_log(t1, t2, sub_res)
        #println("check_log($(t1), $(t2)): ", cl)
        if !cl
            throw(ErrorException("Julia does not agree with the log"))
        else
            return true
        end
    catch e
        println(fdict["fail_log_f"], "type-2 failure")
        my_file_log_subtype(fdict["fail_log_f"], t1, t2, sub_res ? '1' : '0', e)
        sdict["parser_s"].logfail += 2
        sdict["parser_s"].pos -= 2
        return false
    end
end

# Is our parser good enough to handle a (surely meaningful, due to previious checks) 
# type found in a log?
function validate_parser(ts :: String, sdict :: StatsDict, fdict :: FilesDict)
    stat = sdict["parser_s"]
    result = true
    tast = nothing
    if contains(ts, "Vararg")
        result = false
        stat.varg += 1
    elseif length(matchall(r"where _", ts)) > 1
        result = false
        stat.undersc += 1
    else
        try
            tast = lj_parse_type(ts)
            stat.pos += 1
        catch e
            result = false
            if isa(e, LJErrTermInType)
              stat.tt += 1
            else
              stat.exc += 1
              my_file_log_typeof(fdict["exce_parser_f"], ts, e)
            end
        end
    end
    result, tast
end

# Is our lj_typeof good? It has some restrictions, so we pass string to check 
# those along with actual type (which we will feed to Julia's typeof)
function validate_typeof(ts :: String, tast :: ASTBase, tt, sdict :: StatsDict, fdict :: FilesDict) 
    # tt should by Type{T} where T, but in some (ill-formed) cases can be smth else
    stat = sdict["typeof_s"]
    stat.cnt += 1
    if contains(ts, "ANY")
        stat.capany += 1
        return true
    end
    result = true
    try
        (ct1, su, sv) = check_typeof(ts, tast, tt)
        stat.pos += ct1
        if ct1 == 0
            if contains(ts, "getfield")
              throw(LJErrGetfield())
            end
            u = typeof(tt)
            v = lj_typeof_ast_entry(tast)
            my_file_log_typeof(fdict["fail_typeof_f"], 
                ts * " ->lj $(v) ($(sv))\n" * string(tt) * " -> $(u) ($(su))")
        end
    catch e
        #println(ts, " exception:\n$(e)")
        result = false
        if isa(e, LJErrNameNotFound)
          my_file_log_typeof(fdict["exce_typeof_f"], ts, "Name not found: $(e.name)")
          stat.nnf += 1
        elseif isa(e, LJErrIInType) # I is also term-in-type
          stat.cnt -= 1
          sdict["parser_s"].tt += 1
          sdict["parser_s"].pos -= 1 # Term-in-types caught later then we'd like to
        elseif isa(e, LJErrGetfield) || contains(ts, "getfield")
          stat.getf += 1
        else
          my_file_log_typeof(fdict["exce_typeof_f"], ts, e)
          stat.exc += 1
        end
    end
    result
end

function validate_subtype(t1 :: String, t2 :: String,
                          t1ast :: ASTBase, t2ast :: ASTBase,
                          sub_res :: Bool,
                          sdict :: StatsDict, fdict :: FilesDict)  
    sdict["subtype_s"].cnt += 1
    try
        sr, stats = check_subtype(t1ast, t2ast, sub_res)
        if sr == 2 # trivial subtype worked (fast path)
            sdict["subtype_s"].trivial += 1
        else
            sdict["subtype_s"].pos += sr
        end
        addStats(sdict["rules_s"], stats)
        if sr == 0
            my_file_log_subtype(fdict["fail_subtype_f"], t1, t2, sub_res)
        end
        true
    catch e
        if isa(e, LJErrTypeTooLarge)
            sdict["subtype_s"].toolarge += 1
            my_file_log_subtype(fdict["exce_subtype_f"], t1, t2, sub_res, 
                "t1 or t2 has to much unions / normal form of t1 or t2 is too large")
            false
        else
            sdict["subtype_s"].exc += 1
            my_file_log_subtype(fdict["exce_subtype_f"], t1, t2, sub_res, e)
            false
        end
    end
end

# proc_type :: String, StatsDict, FilesDict -> Maybe Type
function proc_type(s :: String, sdict :: StatsDict, fdict :: FilesDict) 
    @mdo Maybe begin
        t <| validate_type(s, sdict, fdict)
        (vp, tast) = validate_parser(s, sdict, fdict)
        guard(vp && validate_typeof(s, tast, t, sdict, fdict))
        return((t, tast))
    end
end

# Top-level structure of the algorithm for log processing
function proc(s1, s2, rs, sdict :: StatsDict, fdict :: FilesDict) 
    @mdo Maybe begin
        r  <| validate_res_format(rs, s1, s2, sdict, fdict)
        tt <| mapM(Maybe, x -> proc_type(x, sdict, fdict), 
                   [s1, s2])
        vl = validate_log(tt[1][1], tt[2][1], r, sdict, fdict)
        guard(vl && validate_subtype(s1, s2, tt[1][2], tt[2][2], r, sdict, fdict))
    end
end

############################# Dictionaries #####################################

make_pid_filename(prefix :: String, suffix :: String) = 
    make_pid_filename(prefix, suffix, myid())
    
make_pid_filename(prefix :: String, suffix :: String, pid::Int) = 
    prefix * "-" * string(pid) * suffix    
    
    
function makeStatsDict()::StatsDict
    sdict :: StatsDict = StatsDict()
    sdict["parser_s"] = ValStats()
    sdict["typeof_s"] = ValStats()
    sdict["subtype_s"] = ValStats()
    sdict["rules_s"] = RulesStats()
    sdict
end

function logFileNames(log_out_dir::String, for_par::Bool = false
)::Dict{String, Tuple{String, String}}
    fnames = Dict{String, Tuple{String, String}}()
    fnames["fail_subtype_f"] = ("subtype-failures", ".txt")
    fnames["exce_subtype_f"] = ("subtype-exceptions", ".txt")
    fnames["fail_typeof_f"] = ("typeof-failures", ".txt")
    fnames["exce_typeof_f"] = ("typeof-exceptions", ".txt")
    fnames["exce_parser_f"] = ("parser-exceptions", ".txt")
    fnames["exce_freevar_f"] = ("freevar-exceptions", ".txt")
    fnames["fail_log_f"] = ("log-failures", ".txt")
    fnames["huge_types_f"] = ("huge-types", ".txt")
    for kv in fnames
        (k, (name, ext)) = kv
        fnames[k] = (log_out_dir * "/" * name * (for_par ? "-par" : ""), ext)
    end
    fnames
end

function makeFilesDict(log_out_dir::String, for_par::Bool = false)::FilesDict
    fdict :: FilesDict = FilesDict()
    fnames = logFileNames(log_out_dir, for_par)
    for kv in fnames
        (k, (name, ext)) = kv
        fname = for_par ? make_pid_filename(name, ext) : (name * ext)
        fdict[k] = open(fname, "w")
    end
    fdict
end
