__precompile__()
module Monads

#
#
#    Interface
#
#
# types: Monad and its instances
export Monad, Identity, MList, Maybe, State
# combinators (MOnad methods)
export mreturn, join, fmap, mbind, mcomp, mthen, (>>)
# utilities
export liftM, Unit, mapM
# do syntax
export @mdo
# MonadPlus
export MonadPlus, mzero, mplus, guard
# State
export runState, put, get, evalState, execState

abstract type Monad{T} end 
abstract type MonadPlus{T} <: Monad{T} end
struct Unit end

#
#
# Stubs for all monad methods
#
#

## Buy two monad combinators, get the third free!
mreturn(::Type{M}, val :: Type) where {M<:Monad} = M{Type}(val)
mreturn(::Type{M}, val :: T) where {T, M<:Monad} = M{T}(val)

join(m::Monad) = mbind(identity, m)

fmap{M<:Monad}(f::Function, m::M) = mbind(m) do x
    mreturn(M, f(x))
end

mbind(f::Function, m::Monad) = join(fmap(f, m))

## Extra combinators
mcomp(g::Function, f::Function) = x -> mbind(g, f(x))

mthen(m::Monad, k::Monad) = mbind(_ -> k, m)

(>>)(m::Monad, k::Monad) = mthen(m, k)

## MonadPlus functions
guard(::Type{M}, c::Bool) where {M <: MonadPlus} = 
    c ? mreturn(M, Unit()) : mzero(M, Unit)

mzero(::Type{M}, ::Type{T}) where {T <: Type, M <: Monad} = M{Type}()
mzero(::Type{M}, ::Type{T}) where {T, M <: Monad} = M{T}()

#
#
# Macro for do-blocks (implementation)
#
#

## Friendly monad blocks
macro mdo(mtype, body)
    esc(mdo_desugar(mdo_patch(mtype, body)))
end

## patch up functions to insert the right monad
mdo_patch(mtype, expr) = expr
function mdo_patch(mtype, expr::Expr)
    expr.args = map(arg->mdo_patch(mtype, arg), expr.args)
    if expr.head == :return
        expr.head = :call
        insert!(expr.args, 1, :mreturn)
    end
    if expr.head == :call && any(expr.args[1] .== [:mreturn, :mzero, :guard, :liftM])
        insert!(expr.args, 2, mtype)
    end
    expr
end

## desugaring mdo syntax is a right fold
mdo_desugar(exprIn) = reduce(mdo_desugar_helper, :(), reverse(exprIn.args))
mdo_desugar_helper(rest, expr) = rest
function mdo_desugar_helper(rest, expr::Expr)
    if expr.head == :call && expr.args[1] == :(<|)
        # replace "<|" with monadic binding
        quote
            mbind($(expr.args[3])) do $(expr.args[2])
                $rest
            end
        end
    elseif expr.head == :(=)
        # replace assignment with let binding
        quote
            let
                $expr
                $rest
            end
        end
    elseif expr.head == :line
        rest
    elseif rest == :()
        expr
    else
        # replace with sequencing
        :(mthen($expr, $rest))
    end
end

## Function lifting
liftM{M<:Monad}(::Type{M}, f::Function) = m1 -> @mdo M begin
    x1 <| m1
    return f(x1)
end

# f :: T -> M S, res :: M [S]
function mapM(::Type{M}, f :: Function, as :: Vector) where {M<:Monad} 
    k = (a,r) -> @mdo M begin
        x  <| f(a)
        xs <| r
        return(push!(xs, x))
    end
    foldr(k, mreturn(M, []), reverse(as))
end

#                                                       #
#                                                       #
#                      Monad instances                  #
#                                                       #
#                                                       #

#
## Starting slow: Identity
#

struct Identity{T} <: Monad{T}
    value :: T
end

mbind(f::Function, m::Identity) = f(m.value)

#
## List
#

struct MList{T} <: MonadPlus{T}
    value :: Vector{T}
    
    MList{T}(x :: Vector{T}) where T = new{T}(x)
    MList{T}(x :: T) where T = new{T}([x])
    MList{T}() where T = new{T}(T[])
end

MList(x :: Vector{T}) where T = MList{T}(x)
MList(x :: T) where T = MList{T}([x])

function join(mm :: MList{MList{T}}) where T
    MList{T}(
     foldl(
       (v,m) -> vcat(v, m.value), 
       T[], 
       mm.value))
end
fmap(f::Function, m::MList) = MList(map(f, m.value))

# It's also a MonadPlus

mplus(m1::MList{T}, m2::MList{T}) where T = MList(vcat(m1.value, m2.value))

import Base.==
==(l1 :: MList{T}, l2 :: MList{T}) where T =
    l1.value == l2.value

#
## Maybe
#

struct Maybe{T} <: MonadPlus{T}
    value :: Union{T, Void} #Any

    Maybe{T}() where T = new{T}(nothing) #(println("???Noth-new $(T)"); new{T}(nothing))
    Maybe{T}(x :: T) where T = new{T}(x) #(println("???MB-new???"); new{T}(x))
end

Maybe(x::Type) = Maybe{Type}(x) #(println("???MB-NEW???"); Maybe{Type}(x))
Maybe(x :: T) where T = Maybe{T}(x)

mbind(f::Function, m::Maybe{T}) where T = 
    isa(m.value, Void) ? Maybe{T}() : f(m.value)

mplus(m1::Maybe{T}, m2::Maybe{T}) where T = 
    isa(m1.value, T) ? m1 : m2

#
## State
#

struct State{T} <: Monad{T}
    runState :: Function # s -> (a, s)
end
state(f) = State(f)

runState(s::State) = s.runState
runState(s::State, st) = s.runState(st)

function mbind(f::Function, s::State)
      state(st -> begin
          (x, stp) = runState(s, st)
          runState(f(x), stp)
            end
            )
end
mreturn(::Type{State}, x) = state(st -> (x, st))

put(newState) = state(_ -> (nothing, newState))
get() = state(st -> (st, st))

evalState(s::State, st) = runState(s, st)[1]
execState(s::State, st) = runState(s, st)[2]

end

