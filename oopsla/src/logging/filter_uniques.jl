################################################################################
#
#
#  This (yet another) filtering program is meant to filter raw output of
#  `julia-log` as in the current _The Simplest_ implementation of it
#  (that is, `julia-log` just spitsevery subt/spec-check to stderr.
#
#  This program is meant to be used in pipeline (in bash sense) with julia-log:
#
#      julia-log/julia -e 'Pkg.test("JuMP")' 2> >(julia src/filter_uniques.jl)
#
#  As a result you should get two log-files: log_subt.txt and log_spec.txt
#  with unique subt/spec-checks performed while executing a program.
#
################################################################################

spectyset = Dict()
subtyset = Dict()
fvsubtyset = Dict()

function add(pty, r, d)
  d[pty] = r
end

function get()
  t1 = readline()
  t2 = readline()
  r  = readline() # Meta.parse(Int)?
  ((t1,t2),r)
end

function dump(d, fname)
  open(fname, "w") do f
    for ((x,y),r) in d
      println(f, x)
      println(f, y)
      println(f, "-> ", r)
      println(f)
    end
  end
end

while !eof(STDIN)
  s = readline()
  try
    if  s == "subt:"
      (pty, r) = get()
      add(pty, r, subtyset)
    elseif s == "subt-fv:"
      (pty, r) = get()
      add(pty, r, fvsubtyset) 
    elseif s == "spec:"
      (pty, r) = get()
      if r != "0"
        add(pty, r, spectyset)
      end
    end
  catch e
    println("filter_uniques ERROR in $(s)\nTypes: $(p)\n$(e)")
  end
end

prefix = length(ARGS) > 0 ? (ARGS[1] * "-") : ""

dump(subtyset,  prefix * "log_subt.txt")
dump(spectyset, prefix * "log_spec.txt")
dump(fvsubtyset, prefix * "log_subt_fv.txt")
