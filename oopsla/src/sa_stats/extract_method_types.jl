Pkg.init()
if Pkg.installed("JSON") == nothing
	Pkg.add("JSON")
end
using JSON

if !Core.isdefined(:LJ_SRC_FILE_PARSING) && !isdefined(:static_parse)
    include("../lj.jl")
    static_parse = 2
end
include("type_stats.jl")

parsed = quote
    function tester(x::Int, y::Union{Int, String}, z:: T where T)
    end
end

parse_file(file::IO) = parse_file(readstring(file))
"""Parse a file into expressions"""
function parse_file(file_path::AbstractString)
  if isfile(file_path) # Probably change this (isfile errors w long strings)
    contents = readstring(file_path)
  else
    contents = file_path
  end
    exprs = []
    i = start(contents)
  while !done(contents, i)
    try
      ex, i = Meta.parse(contents, i) # TODO see if I can get JuliaParser working
      push!(exprs, ex)
    catch x
#      throw("""File "$(file_path)" raises error: \n$(x) after $i""")
      println("""File "$(file_path)" raises error: \n$(x)""")
      return [] # Come up with non failing way to parse file later # how do I update i?
    end
  end
  exprs
end
"""Recursivley searches directories within passed one to find julia files"""
function search_dirs(base_dir::AbstractString,
           files::Array{AbstractString,1}=Array{AbstractString,1}())
  dir_queue = map(x->joinpath(base_dir, x), readdir(base_dir))
  for entity in dir_queue
    if isfile(entity) && entity[end-2:end]==".jl"
      push!(files, entity)
    elseif isdir(entity)
      append!(files, search_dirs(entity))
    end
  end
  return files
end

function extract_keyword_type(def::Expr)
    if typeof(def) == Symbol
        return :(Any)
    elseif typeof(def) == Expr && def.head == :(::)
        if length(def.args) > 1
            return def.args[2]
        else
            return def.args[1]
        end
    elseif typeof(def) == Expr && def.head == :(...)
        return :(Vararg)
    else
        error("Unhandled AST form (case 4)")
    end
end
function extract_keyword_type(def::Symbol)
    return :(Any)
end

type FoundDecls
    types::Array{Expr, 1}
    methods::Array{Expr, 1}
end

function combine_fd(arr::AbstractArray{FoundDecls,1})
    if length(arr) > 0
        return FoundDecls(collect(Iterators.flatten(map(x -> x.types, arr))),
                          collect(Iterators.flatten(map(x -> x.methods, arr))))
    else
        return FoundDecls([],[])
    end
end

function combine_fd(old::FoundDecls, ntypes::AbstractArray{Expr, 1}, nmethods::AbstractArray{Expr,1})
    return FoundDecls(append!(old.types, ntypes), append!(old.methods, nmethods))
end

type AnalyzeException <: Exception
    message::String
end


function extract_keyword_type(def)
    if typeof(def) == Symbol
        return :(Any)
    elseif typeof(def) == Expr && def.head == :(::)
        if length(def.args) > 1
            return def.args[2]
        else
            return def.args[1]
        end
    elseif typeof(def) == Expr && def.head == :(...)
        return :(Vararg)
    else
        error("Unhandled AST Form (case 5)")
    end
end

# gets the type of an expression of the form a::b or ::b
function gettypeasc(e::Expr)
    if length(e.args) > 1
        return e.args[2]
    else
        return e.args[1]
    end
end

function parseWhere(decl::Expr, e::Expr, vars::Array{Any, 1})
    if decl.head == :where
        unshift!(vars, decl.args[2])
        return parseWhere(decl.args[1], e, vars)
    elseif decl.head == :(::)
    	return parseWhere(decl.args[1], e, vars)
    elseif decl.head == :call
        return parseCall(decl, e; whereclauses=vars)
    end

    println("===UNHANDLED AST FORM===")
    println(decl)
    dump(decl)
    throw(AnalyzeException("Unhandled AST form (case 3)"))
end

function parseCall(decl::Expr, e::Expr; whereclauses=Array{Any,1}())
    argtypes = Array{Any, 1}()
    foundname = Void()
    name = true
    for arg in decl.args
        #decls are either of the form symbol or ::
        if typeof(arg) == Symbol
            # zip - no type (effectively any)
            if name
                name = false
                foundname = arg
            else
                push!(argtypes,:(Any))
            end
        elseif typeof(arg) == Expr && arg.head == :(.)
            foundname = arg.args[2]
            if foundname isa QuoteNode
                foundname = foundname.value
            end
            name = false
        elseif typeof(arg) == Expr && arg.head == :($)
            name = Symbol("#META#" * string(gensym()))
            name = false
        elseif typeof(arg) == Expr && arg.head == :(:)
            return FoundDecls([],[])
        elseif typeof(arg) == Expr && arg.head == :macrocall
            push!(argtypes, :(Any))
        elseif typeof(arg) == Expr && arg.head == :(...)
            push!(argtypes, :(Vararg))
        elseif typeof(arg) == Expr && arg.head == :kw
            def = arg.args[1]
            push!(argtypes, extract_keyword_type(def))
        elseif typeof(arg) == Expr && arg.head == :parameters
            for kwarg in arg.args
                if typeof(kwarg) == Symbol
                    push!(argtypes, :(Any))
                elseif typeof(kwarg) == Expr && kwarg.head == :kw
                    push!(argtypes, extract_keyword_type(kwarg.args[1]))
                elseif typeof(kwarg) == Expr && kwarg.head == :(::)
                    push!(argtypes, kwarg.args[2])
                elseif typeof(kwarg) == Expr && kwarg.head == :(...)
                    push!(argtypes, :(Vararg))
                elseif typeof(kwarg) == Expr && kwarg.head == :$
                    return FoundDecls([],[])
                else
                    dump(kwarg)
                    throw(AnalyzeException("Unhandled AST form (case 2)"))
                end
            end
        elseif typeof(arg) == Expr && arg.head == :curly
            #deal with type parameters.
            #will consist of the function name, followed by the type params
            #the type params will just be saves for a synthetic where clause
            #to be passed to convert_ast later
            for whc in arg.args
                if typeof(whc) == Symbol
                    if name
                        foundname = whc
                        name = false
                    else
                        push!(whereclauses, whc)
                    end
                elseif typeof(whc) == Expr && whc.head == :(.)
                    foundname = whc.args[2]
                    if foundname isa QuoteNode
                        foundname = foundname.value
                    end
                    name = false
                elseif typeof(whc) == Expr && whc.head == :($)
                    foundname = Symbol("#META#" * string(gensym()))
                    name = false
                elseif typeof(whc) == Expr && whc.head == :(<:)
                    push!(whereclauses, whc)
                elseif typeof(whc) == Expr && whc.head == :(::)
                    name = false
                    foundname = Symbol(gettypeasc(whc))
                    println("ignoring odd inner constructor")
                elseif typeof(whc) == Expr && whc.head == :parameters
                    return FoundDecls([],[])
                else
                    dump(whc)
                    throw(AnalyzeException("Unhandled AST form (case 1)"))
                end
            end
        elseif typeof(arg) == Expr && arg.head == :(::)
            if name # this is a custom dispatch target
                name = false
                foundname = Symbol(gettypeasc(arg))
            end
            # one of
            # :: type
            # :: var type
            if length(arg.args) > 1
                push!(argtypes, arg.args[2])
            else
                push!(argtypes, arg.args[1])
            end

        else
            println("===UNHANDLED AST FORM===")
            println(e)
            dump(arg)
            throw(AnalyzeException("Unhandled AST form (case 0)"))
        end
    end

    if length(whereclauses) > 0 #were there type arguments?
        inner = :(Tuple{$(argtypes...)})
        for arg in whereclauses
            inner = :($inner where $arg)
        end
        synthesized = inner
    else
        synthesized = :(Tuple{$(argtypes...)})
    end
    if !isa(foundname, Symbol)
        println("===UNPARSEABLE NAME==")
        println(e)
        println(foundname)
        foundname = Symbol("#GEN#" * string(gensym()))
    end
    return FoundDecls([], [synthesized])
end


function recurser(e::Expr)
    if e.head == :function || (e.head == :(=) && isa(e.args[1], Expr) && e.args[1].head == :call)
        #do function things
        # must be of form args = [call, [:fnname, args ...]]
        decl = e.args[1]
        if typeof(decl) == Symbol
            return FoundDecls([],[])
        elseif decl.head == :where
            res = parseWhere(decl, e, Any[])
            return res
        elseif decl.head == :call
            res = parseCall(decl, e)
            return res
        else
            return combine_fd(map(recurser, e.args))
        end
    elseif e.head == :type || e.head == :abstract || e.head == :bitstype || e.head == :typealias
        return FoundDecls([e], [])
    elseif e.head == :macrocall
        if typeof(e.args[1]) == GlobalRef && e.args[1].mod == Core && e.args[1].name == Symbol("@doc")
            return recurser(e.args[3])
        end
        if e.args[1] == Symbol("@compat")
            return recurser(e.args[2])
        end
        return FoundDecls([],[])
    else
        #go through types
        if length(e.args) == 0
            return FoundDecls([], [])
        end
        return combine_fd(map(recurser, e.args))
    end
end

function recurser(e::Any)
    return FoundDecls([],[])
end

global simplewhere = 0
function cleanup_types(e::Expr)
    if e.head == :(.)
        return e
    end
    if e.head == :(...)
        return :Any
    end
    if e.head == :($)
        return :Any
    end
    if e.head == :macrocall
        return :Any
    end
    if e.head == :(<:) && length(e.args) == 1
        global simplewhere = simplewhere + 1
        return :Any
    end
    if e.head == :call && e.args[1] == :typeof
        return :Any
    end
    if e.head == :if
        return :Any
    end
    ei = Expr(e.head)
    ei.args = map(cleanup_types, e.args)
    return ei
end
function cleanup_types(e::QuoteNode)
    return :(1)
end
function cleanup_types(e::Bool)
    return :(1)
end
function cleanup_types(e::Char)
    return :1
end
function cleanup_types(e::Symbol)

    return e
end
function cleanup_types(e::Any)
    return e
end

function extract_types(file::AbstractString)
    if ~ isfile(file)
        error("file not found")
    end
    exprs = parse_file(file)
    combine_fd(map(recurser, exprs))
end

function where_failed(fn::Function, list)
    return map(x -> begin println(x[1]); fn(x[2]) end, enumerate(list))
end

function get_all_types(files::Array{AbstractString,1})
    found = combine_fd(map(extract_types, files))
    return FoundDecls(found.types, map(cleanup_types, found.methods))
end

function compute_statistics(statistic::Function, file::AbstractString)
    found_types = get_all_types(file)
    return map(statistic, map(lj.convert_ast, found_types.methods))
end



type ConvertedDecls
    types::AbstractArray{Expr,1}
    methods::AbstractArray{lj.ASTBase,1}
end

type PkgStats
    name::String
    files::AbstractArray{String, 1}
    nloc::Int64
    fn_stats::Dict{Symbol, Any}
    td_stats::Dict{Symbol, Any}
    found::ConvertedDecls
end

function get_pkg_files(pkg::String)
    if pkg == "Base"
        src_path = "$JULIA_HOME/../../base"
    else
        src_path = "$(Pkg.dir(pkg))/src"
    end
    println(src_path)
    return search_dirs(src_path)
end

function get_raw_types(pkg::String)
    files = get_pkg_files(pkg) 
    nfiles = length(files)
    nloc = reduce(+, map(countlines, files))
    fds = get_all_types(files)
    return fds, files, nloc
end

function get_types(pkg::String)
    fds, files, nloc = get_raw_types(pkg)
    # cds = ConvertedDecls(fds.types, map(lj.convert_ast,fds.methods))
    rslts = Any[]
    for m in fds.methods
      try
        mr = lj.convert_ast(m)
        push!(rslts, mr)
      catch err
        println("PARSE_INFO: ", m)
      end
    end
    cds = ConvertedDecls(fds.types, rslts)
    return cds,files,nloc
end

function compute_statistics(pkgs::AbstractArray{String, 1}, fnstat::Dict{Symbol, Function}, tystat::Dict{Symbol, Function})
    outp = []
    println(pkgs)
    for pkg in pkgs
        if pkg != "Base" && Pkg.installed(pkg) == nothing
            Pkg.clone(pkg)
        end
        cds,files,nloc = get_types(pkg)
        push!(outp, PkgStats(pkg, files, nloc,
                             Dict(a[1] => a[2](cds.methods) for a in fnstat),
                             Dict(a[1] => a[2](cds.types) for a in tystat), cds))
    end
    return outp
end

function is_parametric(x::Expr)
    if x.head == :(<:)
        return is_parametric(x.args[1])
    elseif x.head == :abstract
        return is_parametric(x.args[1])
    elseif x.head == :type
        return is_parametric(x.args[2])
    elseif x.head == :(curly)
        return true
    else
        return false
    end
end
function is_parametric(x::Any)
    return false
end

function is_complex_parametric(x::Expr)
    if x.head == :(<:)
        return is_complex_parametric(x.args[1])
    elseif x.head == :abstract
        return is_complex_parametric(x.args[1])
    elseif x.head == :type
        return is_complex_parametric(x.args[2])
    elseif x.head == :(curly)
        return mapreduce(is_complex_parametric_inner, (x,y) -> x || y, false, x.args)
    else
        return false
    end
end

function is_complex_parametric(s::Symbol)
    return false
end

function is_complex_parametric_inner(x :: Symbol)
    return false
end

function is_complex_parametric_inner(x :: Expr)
    return x.head == :(<:) 
end

function is_bitstype(e::Expr)
    return e.head == :bitstype
end

function is_bound(x::Expr)
    if x.head == :(<:)
        return true
    elseif x.head == :comparison
        return true
    else
        return false
    end
end
function is_bound(x::Symbol)
    return false
end

function is_trivially_parametric(x::Expr)
    if x.head == :(<:)
        return is_trivially_parametric(x.args[1])
    elseif x.head == :abstract
        return is_trivially_parametric(x.args[1])
    elseif x.head == :type
        return is_trivially_parametric(x.args[2])
    elseif x.head == :(curly)
        return reduce((x,y)->x&&y, true, map(x -> ! is_bound(x), x.args[2:length(x.args)]))
    else
        return false
    end
end

function is_trivially_parametric(x::Any)
    return false
end

function std_fn()
    return Dict{Symbol,Function}(
        :no_nodes => x->map(no_nodes, x),
        :no_where => x->map(no_where, x),
        :no_val => x->map(no_Val, x),
        :no_concr => x->map(no_val, x),
        :no_variants => x -> length(x),
        :no_triv_where => x->map(no_twhere, x),
        :count_unions => x -> map(count_unions, x),
#        :potentially_diagonal => x -> map(potentially_diagonal,x),
        :is_interesting => x -> map(is_interesting_n,x),
        :how_dynamic => x -> map(how_dynamic, x))
#        :var_used_in_union => x -> map(check_used_in_union, x))
end

function std_ty()
    return Dict{Symbol, Function}(
        :no_types => x -> length(x),
        :no_abstract => x -> length(filter(y -> y.head == :abstract,x)),
        :no_triv_parametric => x -> length(filter(is_trivially_parametric, x)),
        :no_parametric => x -> length(filter(is_parametric, x)),
        :complex_parametric => x -> map(is_complex_parametric, x),
        :is_bitstype => x -> map(is_bitstype, x))     
end

function run_analysis(packages)
    pkgs = readlines(packages)
    unshift!(pkgs, "Base")
    pkgs = map(x->String(split(x,".")[1]), pkgs)
    decls = compute_statistics(pkgs, std_fn(),std_ty())
    decls
end

type PkgStatsNoTypes
    name::String
    files::AbstractArray{String,1}
    nloc::Int64
    fn_stats::Dict{Symbol, Any}
    td_stats::Dict{Symbol, Any}
end

function toJSON(ps::PkgStats)
    return (PkgStatsNoTypes(ps.name, ps.files, ps.nloc, ps.fn_stats, ps.td_stats))
end

function write_out_all(x, filename)
    outp = [toJSON(ps) for ps in x]
    begin open(filename, "w") do f
        write(f, JSON.json(outp))
    end
    end
end

function write_out(x, filename)
    begin open(filename, "w") do f
        write(f, toJSON(x))
    end
    end
end

function write_out_idx(x, idx)
    begin open("../../stats/static-types/$(idx).json", "w") do f
        write(f, JSON.json(x))
    end end
end
