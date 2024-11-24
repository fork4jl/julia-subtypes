#
# Run at the level where project directories are stored
#

# set [false] to show all exceptions in the result err table
lj_colerr_only_sub_exceptions = true

# Deps handling
dep1 = "JSON"
if Pkg.installed(dep1) == nothing
  Pkg.add(dep1)
end
eval(Meta.parse("using $(dep1)"))

############  Formatting utilities

# Get project label like GreatProj-using or MyProj-test
# from a string like: ./GreatProj/add_log-subt/results.json
# (output of the find caommand -- see main function)
function get_proj_label(r :: String)
    ss = split(r, "/")
    pr = ss[2] * (startswith(ss[3], "add")
                  ? "/use" : "/test")
    if contains(ss[3], "_ht")
      pr = pr * "-ht"
    end
    pr
end


tex = haskey(ENV, "tex")
sep = tex ? "&" : "|"
bsep = tex ? "&" : "||"

eol() = tex ? "\\\\" : bsep

bpad(s,n,m) = lpad("",n) * "$(s)" * lpad("",m)
function pwc(s, w)
    sw = w - length("$(s)")
    bpad(s, div(sw,2), sw - div(sw,2))
end
pwr(s, w) = lpad(s, w - 1) * " "
pwcb(s,w) = sep * pwc(s,w) * sep
pwcbl(s,w) = sep * pwc(s,w)
pwcbbl(s,w) = bsep * pwc(s,w)
pwcbr(s,w) = pwc(s,w) * sep
pwcbbr(s,w) = pwc(s,w) * bsep
pwrb(s,w) = sep * pwr(s,w) * sep
pwrbl(s,w) = sep * pwr(s,w)
pwrbbl(s,w) = bsep * pwr(s,w)
pwrbr(s,w) = pwr(s,w) * sep
pwrbbr(s,w) = pwr(s,w) * bsep

dashed() =
        lpad("", total_width - length(bsep),'-') * bsep

bdashed() =
        lpad("", total_width - length(bsep),'=') * bsep

##########  Formatting constants

prw = 40 # Width of the "PROJECT" column

scw = 8 # "standard" width for a subcolumn 

# Parser
pts = scw # #types subcolumn
pun = scw # unsupp subcolumn
pnw = scw # not WF subcolumn

# total
ptot = pts + pun + pnw + #total
       2 # inner seps

# Typeof
tts = scw # #types subcolumn
tps = scw # passed subcolumn
tfl = scw # fail subcolumn
tan = scw # ANY subcolumn

ttot = tts + tps + tfl + tan + #total
       3 # inner seps

# Subtype
sts = scw # #types subcolumn
str = scw # trivial subcolumn
sps = scw # passed subcolumn
sfl = scw # fail subcolumn

stot = sts + str + sps + sfl + #total
       3 # inner seps

# Total width of the results table
total_width = prw + ptot + ttot + stot +
              4 * 2 # inner seps * width of the sep
nw = 8
nnw = 6

##########  Data Structures

lj_colres_total_fresh() = Dict(
    "pcnt" => 0, "unsup" => 0, "notWF" => 0, 
    "tcnt" => 0, "tpos" => 0,  "tneg" => 0, "tany" => 0,
    "scnt" => 0, "strv" => 0, "spos" => 0,  "sneg" => 0
)

lj_colerr_total_fresh() = Dict(
    "cnt" => 0,  "varg" => 0, "tt" => 0, 
    "getf" => 0, "any" => 0,  "undersc" => 0, "logfail" => 0,
    "nnf" => 0,  "exc" => 0,  "freevar" => 0
)

##########  Main printing functions

function print_head_res_cols()
    d = (s,n) -> pwcbbr(s,n)
    println(d("PROJECT", prw), d("PARSER", ptot), d("TYPEOF",ttot), d("SUBTYPE",stot))
end

function print_head_res_subcols()
    d = s -> pwcbl(s,scw)
    b = s -> pwcbbl(s,scw)
    println(pwr("",prw),
            b(" #types "), d(" unsupp "), d(" not WF "), 
            b(" #tests "), d(" passed "), d(" fail "), d(" ANY "), 
            b(" #tests "), d(" triv "), d(" passed "), d(" fail "), bsep)
    println(dashed())
end

function print_head_res()
    println(dashed())
    print_head_res_cols()
    print_head_res_subcols()
end

function print_head_res_rev()
    print_head_res_subcols()
    print_head_res_cols()
    println(dashed())
end

function print_head_err()
    colw = 26
    d = s -> pwcbl(s,nw)
    n = s -> pwrbl(s,nnw)
    b = s -> pwcbbl(s,nw)
    println(pwr("",prw),
            b(" #types "),   d(" vararg "), d(" values "), 
            b(" getfld "), n(" ANY "), d(" _ "),
            b(" logfail"), d("Unkwn id"), d(" excep's"), d(" freevr "), bsep)
    println(lpad("",prw + 3*colw + nw + 5,'-') * bsep)
end

function print_proj_res(pr, json)
    d = s -> pwrbl(s,nw)
    b = s -> pwrbbl(s,nw)
    p = json["parser"]
    t = json["typeof"]
    s = json["subtype"]
    #TODO: remove when all .json are good
    for jsond in [p, t, s]
      if !haskey(jsond, "trivial")
        jsond["trivial"] = 0
      end
    end
    lj_colres_total_add!(lj_colres_total, p, t, s)
    println(rpad(pr,prw)
           #                     Parser
           , b(p["cnt"])                        # #types
           , d(p["varg"] + p["tt"] + t["getf"] +# unsupp
               get(p, "toolarge", 0))
           , d(p["freevar"] + p["exc"] + t["nnf"] + t["exc"] + p["logfail"] 
                + p["undersc"])                 # not WF
           #                     Typeof
           , b(t["cnt"] - t["nnf"] - t["exc"])  # #tests
           , d(t["pos"])                        # passed
           , d(t["neg"])                        # fail
           , d(t["capany"])                     # ANY
           #                     Subtype
           , b(s["cnt"] - s["exc"])             # #tests
           , d(s["trivial"])                    # trivial checks
           , d(s["pos"])                        # passed
           , d(s["neg"])                        # fail
           , eol()
          )
end

function print_errs(pr, json)
    d = s -> pwrbl(s,nw)
    n = s -> pwrbl(s,nnw)
    b = s -> pwrbbl(s,nw)
    p = json["parser"]
    t = json["typeof"]
    s = json["subtype"]
    lj_colerr_total_add!(lj_colerr_total, p, t, s)
    println(rpad(pr,prw)
           #                     Parser
           , b(p["cnt"])
           , d(p["varg"])
           , d(p["tt"])
           , b(t["getf"])
           , n(t["capany"])
           , d(p["undersc"])
           , b(p["logfail"])
           , d(t["nnf"])
           , d(lj_colerr_only_sub_exceptions ? s["exc"] : 
               p["exc"] + t["exc"] + s["exc"])
           , d(p["freevar"])
           , bsep
          )
end

#########  Compute totals

function lj_colres_total_add!(total, p, t, s)
    # parser
    total["pcnt"]  += p["cnt"]
    total["unsup"] += p["varg"] + p["tt"] + t["getf"] 
                      + get(p, "toolarge", 0)
    total["notWF"] += p["freevar"] + p["exc"] + t["nnf"] + t["exc"] 
                      + p["logfail"] + p["undersc"]
    # typeof
    total["tcnt"]  += t["cnt"] - t["nnf"] - t["exc"]
    total["tpos"]  += t["pos"]
    total["tneg"]  += t["neg"]
    total["tany"]  += t["capany"]
    # subtype
    total["scnt"]  += s["cnt"] - s["exc"]
    total["strv"]  += s["trivial"]
    total["spos"]  += s["pos"]
    total["sneg"]  += s["neg"]
end

lj_colres_total = lj_colres_total_fresh()

function lj_colerr_total_add!(total, p, t, s)
    total["cnt"]     += p["cnt"]
    total["varg"]    += p["varg"]
    total["tt"]      += p["tt"]
    total["getf"]    += t["getf"]
    total["any"]     += t["capany"]
    total["undersc"] += p["undersc"]
    total["logfail"] += p["logfail"]
    total["nnf"]     += t["nnf"]
    total["exc"]     += lj_colerr_only_sub_exceptions ? s["exc"] : 
                        p["exc"] + t["exc"] + s["exc"]
    total["freevar"] += p["freevar"]
end

lj_colerr_total = lj_colerr_total_fresh()

############# Print totals

function print_proj_total()
    d = s -> pwrbl(s, scw)
    b = s -> pwrbbl(s, scw)
    println(
        tex ?
            "\\midrule" :
            bdashed()
        )
    println(rpad("TOTAL",prw)
           #                     Parser
           , b(lj_colres_total["pcnt"])         # #types
           , d(lj_colres_total["unsup"])        # unsupp
           , d(lj_colres_total["notWF"])        # not WF
           #                     Typeof
           , b(lj_colres_total["tcnt"])         # #tests
           , d(lj_colres_total["tpos"])         # passed
           , d(lj_colres_total["tneg"])         # fail
           , d(lj_colres_total["tany"])         # ANY
           #                     Subtype
           , b(lj_colres_total["scnt"])         # #tests
           , d(lj_colres_total["strv"])         # trivial
           , d(lj_colres_total["spos"])         # passed
           , d(lj_colres_total["sneg"])         # fail
           , eol()
          )
    if !tex
      println(dashed())
    end
end

function print_errs_total()
    colw = 26
    d = s -> pwrbl(s,nw)
    n = s -> pwrbl(s,nnw)
    b = s -> pwrbbl(s,nw)
    println(lpad("",prw + 3*colw + nw + 5,'=') * bsep)
    println(rpad("TOTAL",prw)
           , b(lj_colerr_total["cnt"])
           , d(lj_colerr_total["varg"])
           , d(lj_colerr_total["tt"])
           , b(lj_colerr_total["getf"])
           , n(lj_colerr_total["any"])
           , d(lj_colerr_total["undersc"])
           , b(lj_colerr_total["logfail"])
           , d(lj_colerr_total["nnf"])
           , d(lj_colerr_total["exc"])
           , d(lj_colerr_total["freevar"])
           , bsep
          )
    println(lpad("",prw + 3*colw + nw + 5,'-') * bsep)
end

##############  Choosing b/w modes: Results or Errors

abstract type Mode end
struct Res <: Mode end
struct Err <: Mode end

print_head(::Res) = print_head_res()
print_head(::Err) = print_head_err()

print_head_rev(::Res) = print_head_res_rev()
print_head_rev(::Err) = print_head_err()

print_proj(::Res, pr, res) = print_proj_res(pr, res)
print_proj(::Err, pr, res) = print_errs(pr, res)

print_totals(::Res) = print_proj_total()
print_totals(::Err) = print_errs_total()

#####################  Main

function main()
    # Setup fresh environment for computing totals
    lj_colres_total = lj_colres_total_fresh()
    lj_colerr_total = lj_colerr_total_fresh()

    # Compute validation mode
    valmode = ""
    for vm in ["add", "test"]
        if haskey(ENV, vm)
            valmode = vm
        end
    end

    # Collect result-filenames
    rsseq = readlines(pipeline(`find -name results.json`))
    rspar = readlines(pipeline(`find -name results-par.json`))
    rs = sort(filter(s -> contains(s, valmode), vcat(rsseq, rspar)))
    
    # Determine the report mode: Results or Errors
    mode = length(ARGS) > 0 ? Err() : Res()

    if !tex
      print_head(mode)
    end
    
    # Loop over projects
    for r in rs
        pr = get_proj_label(r)
        print_proj(mode, pr, JSON.parsefile(r))
    end

    print_totals(mode)
    if !tex
      print_head_rev(mode)
    end
    println()
end

main()

