#
# Run at the level where project directories are stored
#

using JSON

include("../../aux/aux.jl")

#####################  Main

function merge_f(rs1, rs2)
    [rs1[1] + rs2[1], rs1[2] + rs2[2]]
end

function main()

    # Collect result-filenames
    run(`rm -f rules-stats.json`)
    rsseq = readlines(pipeline(`find -name rules-stats.json`))
    rspar = readlines(pipeline(`find -name rules-stats-par.json`))
    rs = vcat(rsseq, rspar)
    #println("Found:\n",rs)

    # Loop over projects
    stats = Dict{String, Vector{Int}}()
    for r in rs
        #println("reading $(r)")
        merge!(merge_f, stats, JSON.parsefile(r)["s"])
    end

    show_dict_sort_v(STDOUT, stats)
    
    open("rules-stats.json", "w") do f
        JSON.print(f, stats, 4)
    end
end

main()

