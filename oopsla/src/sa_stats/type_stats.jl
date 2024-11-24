#=
if !Core.isdefined(:LJ_SRC_FILE_AST)
    include("syntax/AST.jl")
end
=#
using lj:   
  TUnion,
  TTuple,
  TApp,
  TWhere,
  TType,
  TName,
  TAny,
  TDataType,
  TUnionAll,
  TSuperUnion,
  TVar,
  TSuperTuple,
  TValue,
  EmptyUnion,
  lj_julia_dev,
  convert_ast,
  convert_tydecl,
  betared

function safe_sum(l)
  if length(l) == 0
    return 0
  else
    sum(l)
  end
end

### number of nodes in a type

function no_nodes(t::ASTBase)
  return 1
end

function no_nodes(t::Union{TUnion, TTuple})
  return safe_sum(map(no_nodes,t.ts)) + 1
end

function no_nodes(t::TApp)
  return no_nodes(t.t) + safe_sum(map(no_nodes,t.ts)) + 1
end

# maybe do not count bounds if bounds are Bot / Any?
function no_nodes(t::TWhere)
  return no_nodes(t.t) + no_nodes(t.lb) + no_nodes(t.ub) + 1
end

function no_nodes(t::Union{TUnionAll, TType})
  return no_nodes(t.t) + 1
end

### number of where clauses in a type

function no_where(t::ASTBase)
    return 0
end

function no_where(t::Union{TUnion, TTuple})
    return safe_sum(map(no_where, t.ts))
end

function no_where(t::TApp)
    return no_where(t.t) + safe_sum(map(no_where, t.ts))
end

function no_where(t::TWhere)
    return no_where(t.t) + no_where(t.lb) + no_where(t.ub) + 1
end

function no_where(t::Union{TUnionAll, TType})
    return no_where(t.t)
end

### number of trivial where clauses

function no_twhere(t::lj.ASTBase)
    return 0
end

function no_twhere(t::Union{lj.TUnion, lj.TTuple})
    return reduce((x,y) -> x + y, 0, map(no_twhere, t.ts))
end

function no_twhere(t::lj.TApp)
    return no_twhere(t.t) + reduce((x,y) -> x + y, 0, map(no_twhere, t.ts))
end

function no_twhere(t::lj.TWhere)
    if typeof(t.lb) != TUnion || t.lb.ts != [] || typeof(t.ub) != TAny
        return no_twhere(t.t) + no_twhere(t.lb) + no_twhere(t.ub)
    end
    return no_twhere(t.t) + no_twhere(t.lb) + no_twhere(t.ub) + 1
end

function no_twhere(t::Union{lj.TUnionAll, lj.TType})
    return no_twhere(t.t)
end

### no_val

function no_val(t::lj.ASTBase)
    return 0
end

function no_val(t::Union{lj.TUnion, lj.TTuple})
    return safe_sum(map(no_val, t.ts))
end

function no_val(t::lj.TApp)
    return no_val(t.t) + safe_sum(map(no_val, t.ts))
end

function no_val(t::lj.TWhere)
    return no_val(t.t) + no_val(t.lb) + no_val(t.ub) + 1
end

function no_val(t::lj.TValue)
    return 1
end

function no_val(t::Union{lj.TUnionAll, lj.TType})
    return no_val(t.t)
end

## no_Val

function no_Val(t::lj.ASTBase)
    return 0
end

function no_Val(t::Union{lj.TUnion, lj.TTuple})
    return safe_sum(map(no_Val, t.ts))
end

function no_Val(t::lj.TApp)
    if t.t == TName(:Value)
        return 1
    end 
    return no_Val(t.t) + safe_sum(map(no_Val, t.ts))
end

function no_Val(t::lj.TWhere)
    return no_Val(t.t) + no_Val(t.lb) + no_Val(t.ub) + 1
end

function no_Val(t::lj.TValue)
    return 0
end

function no_Val(t::Union{lj.TUnionAll, lj.TType})
    return no_Val(t.t)
end

## potentially_diagonal

if !Core.isdefined(:SEnv)
    type SEnv
        next::Union{Void, SEnv}
        var::Symbol
    end
end
if !Core.isdefined(:TSEnv)
    const TSEnv = Union{SEnv, Void}
end

function add_to_env(env::TSEnv, var::Symbol)
    return SEnv(env, var)
end
function in_env(env::TSEnv, var::Symbol)
    if env == nothing
        return false
    end
    if env.var==var
        return true
    elseif env.next != nothing
        return in_env(env.next, var)
    else
        return false
    end
end

type Occ
    cov::Int
    inv::Int
end

@enum State cov=1 inv=2
import Base.+
function +(r::Vararg{Occ, n} where n)
    return Occ(reduce(+,0,map(x->x.cov, r)), reduce(+,0,map(x->x.inv, r)))
end

function count_occurences(ast::lj.TVar, env::TSEnv, state::State)
    if in_env(env, ast.sym)
        if state == cov
            return Occ(1,0)
        elseif state == inv
            return Occ(0,1)
        end
    else
        return Occ(0,0)
    end
end

function count_occurences(ast::lj.TAny, env::TSEnv, state::State)
    return Occ(0,0)
end

function count_occurences(ast::lj.TUnion, env::TSEnv, state::State)
    res = map(x -> count_occurences(x, env, state), ast.ts)
    if length(res) == 0
        return Occ(0,0)
    end
    return Occ(maximum(map(x -> x.cov, res)), maximum(map(x -> x.inv, res)))
end

function count_occurences(ast::lj.TApp, env::TSEnv, state::State)
    res = map(x -> count_occurences(x, env, inv), ast.ts)
    return reduce(+, Occ(0,0), res)
end

function count_occurences(ast::lj.TWhere, env::TSEnv, state::State)
    envp = add_to_env(env, ast.tvar.sym)
    return count_occurences(ast.t, envp, state) + count_occurences(ast.lb, env, state) + count_occurences(ast.ub, env, state)
end

function count_occurences(ast::lj.TTuple, env::TSEnv, state::State)
    res = map(x -> count_occurences(x, env, state), ast.ts)
    return reduce(+, Occ(0,0), res)
end

function count_occurences(ast::lj.TName, env::TSEnv, state::State)
    return Occ(0,0)
end

function count_occurences(ast::lj.TUnionAll, env::TSEnv, state::State)
    return count_occurences(ast.t, env, state)
end

function count_occurences(ast::lj.TType, env::TSEnv, state::State)
    return count_occurences(ast.t, env, state)
end

function count_occurences(ast::lj.ASTBase, env::TSEnv, state::State)
    return Occ(0,0)
end



function potentially_diagonal(ast::lj.ASTBase)
    try
        normalized = lj_normalize_type(ast, false)
    catch e
        println("===============")
        println("Wrong generated type error.")
        println("Input type: $ast")
        println("Error: $e")
        return 0
    end
    res = count_occurences(lj_normalize_type(ast, false), nothing, cov)
    if res.cov > 1 && res.inv == 0
        return 1
    else
        return 0
    end
end

# is_interesting

function is_interesting(ast::lj.TWhere)
    return true
end

function is_interesting(ast::lj.TUnion)
    return true
end

function is_interesting(ast::lj.TApp)
    return reduce((x,y) -> x || y, false, map(is_interesting, ast.ts)) || is_interesting(ast.t)
end

function is_interesting(ast::lj.ASTBase)
    return false
end

function is_interesting(ast::lj.TTuple)
    return reduce((x,y) -> x || y, false, map(is_interesting, ast.ts))
end

function is_interesting(ast::lj.TType)
    return is_interesting(ast.t)
end

function is_interesting_n(ast::lj.ASTBase)
    if is_interesting(ast)
        return 1
    else
        return 0
    end
end

#how_dynamic
#the type can consist of exactly a top-level tuple (potentially inside a where) and Any types
#result is the fraction of types in the top-level tuple that are any

function how_dynamic(ast::TTuple)
    return mapreduce(is_dynamic_n, +, 0, ast.ts)/length(ast.ts)
end

function how_dynamic(ast::TWhere)
    return how_dynamic(ast.t)
end

function is_dynamic_n(ast::TAny)
    return 1
end

function is_dynamic_n(ast::ASTBase)
    return 0
end

#

### number of where clauses in a type

function count_unions(t::lj.ASTBase)
    return 0
end

function count_unions(t::Union{lj.TUnion, lj.TTuple})
    if length(t.ts) == 0
        return 0
    end
    return safe_sum(map(count_unions, t.ts)) + 1
end

function count_unions(t::TApp)
    if length(t.ts) === 0
        return count_unions(t.t)
    end
    return count_unions(t.t) + safe_sum(map(count_unions, t.ts)) 
end

function count_unions(t::TWhere)
    return count_unions(t.t) + count_unions(t.lb) + count_unions(t.ub)
end

function count_unions(t::TUnionAll)
    return count_unions(t.t) + 1
end

function count_unions(t::TType)
    return count_unions(t.t)
end

##

function used_in_union(ast::TVar, env::TSEnv, inunion)
    if in_env(env, ast.sym) && inunion
        return true
    else
        return false
    end
end

function used_in_union(ast::TAny, env::TSEnv, inunion)
    return false
end

function used_in_union(ast::TUnion, env::TSEnv, inunion)
    return mapreduce(x -> used_in_union(x, env, true), (x,y) -> x || y, false, ast.ts)
end

function used_in_union(ast::Union{TApp, TTuple}, env::TSEnv, inunion)
    return mapreduce(x -> used_in_union(x, env, inunion), (x,y) -> x || y, false, ast.ts)
end

function used_in_union(ast::TWhere, env::TSEnv, inunion)
    envp = add_to_env(env, ast.tvar.sym)
    return used_in_union(ast.t, envp, inunion) && used_in_union(ast.lb, env, inunion) && used_in_union(ast.ub, env, inunion)
end

function used_in_union(ast::TName, env::TSEnv, inunion)
    return false
end

function used_in_union(ast::TUnionAll, env::TSEnv, inunion)
    return used_in_union(ast.t, env, inunion)
end

function used_in_union(ast::TType, env::TSEnv, inunion)
    return used_in_union(ast.t, env, inunion)
end

function used_in_union(ast::ASTBase, env::TSEnv, inunion)
    return false
end

function check_used_in_union(ast::ASTBase)
    return used_in_union(ast, nothing, false)
end
