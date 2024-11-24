reify(x :: String) = eval(Meta.parse(x))

cnt = 0
cnt_ok = 0

if length(ARGS) != 1
    println("Usage: `julia spec-beats-subt.jl prefix`")
    exit()
end
prefix = ARGS[1]
open(prefix * "-log_spec.txt", "r") do f
    open(prefix * "-subt-beats-spec.txt", "w") do g
        while !eof(f)
            try
                t1 = readline(f)
                t2 = readline(f)
                readline(f) # res
                readline(f) # empty
                cnt += 1
                if !reify("$(t1) <: $(t2)")
                    cnt_ok += 1
                    println(g, "$(t1)\n$(t2)\n")
                end
            end
        end
        println(g,"$(cnt_ok) times subt defer from spec\ntotal checks: $(cnt)")
    end
end
