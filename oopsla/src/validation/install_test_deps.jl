deps = Set()
pkg_dir = Pkg.dir()
#println("Add all test deps for all requires packages in $(pkg_dir)")
reqs = keys(Pkg.Reqs.parse(joinpath(pkg_dir, "REQUIRE")))
for pkg in reqs
    #println("Adding deps to the list for: $(pkg)")
    req = joinpath(pkg_dir, pkg, "test/REQUIRE")
    #println("Test-deps list should be stored at: $(req)")
    if isfile(req)
       #println("There are test-deps for $(pkg):")
       ds = keys(Pkg.Reqs.parse(req))
       #println(ds)
       union!(deps, ds)
    end
end
#println("Resulting set of test-deps:\n", deps)
setdiff!(deps, ["julia"])
for d in deps
    Pkg.add(d)
end
