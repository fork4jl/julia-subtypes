# This file is a part of Julia. License is MIT: https://julialang.org/license

# tests for Core.Inference correctness and precision
import Core.Inference: Const, Conditional, ⊑

# issue 9770
@noinline x9770() = false
function f9770(x)
    return if x9770()
        g9770(:a, :foo)
    else
        x
    end
end
function g9770(x,y)
   return if isa(y, Symbol)
       f9770(x)
   else
       g9770(:a, :foo)
   end
end
@test g9770(:a, "c") === :a
@test g9770(:b, :c) === :b


# issue #1628
mutable struct I1628{X}
    x::X
end
let
    # here the potential problem is that the run-time value of static
    # parameter X in the I1628 constructor is (DataType,DataType),
    # but type inference will track it more accurately as
    # (Type{Integer}, Type{Int}).
    f1628() = I1628((Integer,Int))
    @test isa(f1628(), I1628{Tuple{DataType,DataType}})
end

let
    fT{T}(x::T) = T
    @test fT(Any) === DataType
    @test fT(Int) === DataType
    @test fT(Type{Any}) === DataType
    @test fT(Type{Int}) === DataType

    ff{T}(x::Type{T}) = T
    @test ff(Type{Any}) === Type{Any}
    @test ff(Type{Int}) === Type{Int}
    @test ff(Any) === Any
    @test ff(Int) === Int
end


# issue #3182
f3182{T}(::Type{T}) = 0
f3182(x) = 1
function g3182(t::DataType)
    # tricky thing here is that DataType is a concrete type, and a
    # subtype of Type, but we cannot infer the T in Type{T} just
    # by knowing (at compile time) that the argument is a DataType.
    # however the ::Type{T} method should still match at run time.
    return f3182(t)
end
@test g3182(Complex.body) == 0


# issue #5906

abstract type Outer5906{T} end

struct Inner5906{T}
    a:: T
end

struct Empty5906{T} <: Outer5906{T}
end

struct Hanoi5906{T} <: Outer5906{T}
    a::T
    succ :: Outer5906{Inner5906{T}}
    Hanoi5906{T}(a) where T = new(a, Empty5906{Inner5906{T}}())
end

function f5906{T}(h::Hanoi5906{T})
    if isa(h.succ, Empty5906) return end
    f5906(h.succ)
end

# can cause infinite recursion in type inference via instantiation of
# the type of the `succ` field
@test f5906(Hanoi5906{Int}(1)) === nothing

# issue on the flight from DFW
# (type inference deducing Type{:x} rather than Symbol)
mutable struct FooBarDFW{s}; end
fooDFW(p::Type{FooBarDFW}) = string(p.parameters[1])
fooDFW(p) = string(p.parameters[1])
@test fooDFW(FooBarDFW{:x}) == "x" # not ":x"

# Type inference for tuple parameters
struct fooTuple{s}; end
barTuple1() = fooTuple{(:y,)}()
barTuple2() = fooTuple{tuple(:y)}()

@test Base.return_types(barTuple1,Tuple{})[1] == Base.return_types(barTuple2,Tuple{})[1] == fooTuple{(:y,)}

# issue #6050
@test Core.Inference.getfield_tfunc(
          Dict{Int64,Tuple{UnitRange{Int64},UnitRange{Int64}}},
          Core.Inference.Const(:vals)) == Array{Tuple{UnitRange{Int64},UnitRange{Int64}},1}

# issue #12476
function f12476(a)
    (k, v) = a
    return v
end
@inferred f12476(1.0 => 1)


# issue #12551 (make sure these don't throw in inference)
Base.return_types(unsafe_load, (Ptr{nothing},))
Base.return_types(getindex, (Vector{nothing},))


# issue #12636
module MyColors

abstract type Paint{T} end
struct RGB{T<:AbstractFloat} <: Paint{T}
    r::T
    g::T
    b::T
end

myeltype{T}(::Type{Paint{T}}) = T
myeltype{P<:Paint}(::Type{P}) = myeltype(supertype(P))
myeltype(::Type{Any}) = Any

end

@test @inferred(MyColors.myeltype(MyColors.RGB{Float32})) == Float32
@test @inferred(MyColors.myeltype(MyColors.RGB)) == Any


# issue #12826
f12826{I<:Integer}(v::Vector{I}) = v[1]
@test Base.return_types(f12826,Tuple{Array{I,1} where I<:Integer})[1] == Integer


# non-terminating inference, issue #14009
# non-terminating codegen, issue #16201
mutable struct A14009{T}; end
A14009{T}(a::T) = A14009{T}()
f14009(a) = rand(Bool) ? f14009(A14009(a)) : a
code_typed(f14009, (Int,))
code_llvm(DevNull, f14009, (Int,))

mutable struct B14009{T}; end
g14009(a) = g14009(B14009{a})
code_typed(g14009, (Type{Int},))
code_llvm(DevNull, f14009, (Int,))


# issue #9232
arithtype9232{T<:Real}(::Type{T},::Type{T}) = arithtype9232(T)
result_type9232{T1<:Number,T2<:Number}(::Type{T1}, ::Type{T2}) = arithtype9232(T1, T2)
# this gave a "type too large", but not reliably
@test length(code_typed(result_type9232, Tuple{(Type{x} where x<:Union{Float32,Float64}), Type{T2} where T2<:Number})) == 1


# issue #10878
function g10878(x; kw...); end
invoke_g10878() = invoke(g10878, Tuple{Any}, 1)
@code_typed invoke_g10878()
code_llvm(DevNull, invoke_g10878, ())


# issue #10930
@test isa(code_typed(promote,(Any,Any,Vararg{Any})), Array)
find_tvar10930{T<:Tuple}(sig::Type{T}) = 1
function find_tvar10930(arg)
    if arg<:Tuple
        find_tvar10930(arg[random_var_name])
    end
    return 1
end
@test find_tvar10930(Vararg{Int}) === 1


# issue #12474
@generated function f12474(::Any)
    :(for i in 1
      end)
end
let
    ast12474 = code_typed(f12474, Tuple{Float64})
    @test isleaftype(ast12474[1][2])
    @test all(isleaftype, ast12474[1][1].slottypes)
end


# pr #15259
struct A15259
    x
    y
end
# check that allocation was ellided
@eval f15259(x,y) = (a = $(Expr(:new, :A15259, :x, :y)); (a.x, a.y, getfield(a,1), getfield(a, 2)))
@test isempty(filter(x -> isa(x,Expr) && x.head === :(=) &&
                          isa(x.args[2], Expr) && x.args[2].head === :new,
                     code_typed(f15259, (Any,Int))[1][1].code))
@test f15259(1,2) == (1,2,1,2)
# check that error cases are still correct
@eval g15259(x,y) = (a = $(Expr(:new, :A15259, :x, :y)); a.z)
@test_throws ErrorException g15259(1,1)
@eval h15259(x,y) = (a = $(Expr(:new, :A15259, :x, :y)); getfield(a, 3))
@test_throws BoundsError h15259(1,1)


# issue #7810
mutable struct Foo7810{T<:AbstractVector}
    v::T
end
bar7810() = [Foo7810([(a,b) for a in 1:2]) for b in 3:4]
@test Base.return_types(bar7810,Tuple{})[1] == Array{Foo7810{Array{Tuple{Int,Int},1}},1}


# issue #11366
f11366{T}(x::Type{Ref{T}}) = Ref{x}
@test !isleaftype(Base.return_types(f11366, (Any,))[1])


let f(T) = Type{T}
    @test Base.return_types(f, Tuple{Type{Int}}) == [Type{Type{Int}}]
end

# issue #9222
function SimpleTest9222{T1<:Real}(pdedata, mu_actual::Vector{T1},
        nu_actual::Vector{T1}, v0::Vector{T1}, epsilon::T1, beta::Vector{T1},
        delta::T1, l::T1, R::T1, s0::T1, show_trace::Bool = true)
    return 0.0
end
function SimpleTest9222{T1<:Real}(pdedata, mu_actual::Vector{T1},
        nu_actual::Vector{T1}, v0::Vector{T1}, epsilon::T1, beta::Vector{T1},
        delta::T1, l::T1, R::T1)
    return SimpleTest9222(pdedata, mu_actual, nu_actual, v0, epsilon,
        beta, delta, l, R, v0[1])
end
function foo9222()
    v0 = rand(10)
    mu_actual = rand(10)
    nu_actual = rand(10)
    SimpleTest9222(0.0, mu_actual, nu_actual, v0, 0.0, [1.0,1.0], 0.5, 5.0, 20.0)
end
@test 0.0 == foo9222()

# make sure none of the slottypes are left as Core.Inference.Const objects
function f18679()
    for i = 1:2
        if i == 1
            a = ((),)
        else
            return a[1]
        end
    end
end
g18679(x::Tuple) = ()
g18679() = g18679(any_undef_global::Union{Int,Tuple{}})
for code in Any[
        @code_typed(f18679())[1]
        @code_typed(g18679())[1]]
    @test all(x->isa(x, Type), code.slottypes)
    local notconst(other::ANY) = true
    notconst(slot::TypedSlot) = @test isa(slot.typ, Type)
    function notconst(expr::Expr)
        @test isa(expr.typ, Type)
        for a in expr.args
            notconst(a)
        end
    end
    for e in code.code
        notconst(e)
    end
end

# branching based on inferrable conditions
let f(x) = isa(x,Int) ? 1 : ""
    @test Base.return_types(f, Tuple{Int}) == [Int]
end

let g() = Int <: Real ? 1 : ""
    @test Base.return_types(g, Tuple{}) == [Int]
end

const NInt{N} = Tuple{Vararg{Int, N}}
@test Base.eltype(NInt) === Int
@test Base.return_types(eltype, (NInt,)) == Any[Union{Type{Int}, Type{Union{}}}] # issue 21763
fNInt(x::NInt) = (x...)
gNInt() = fNInt(x)
@test Base.return_types(gNInt, ()) == Any[NInt]

# issue #17572
function f17572{A}(::Type{Val{A}})
    return Tuple{Int}(Tuple{A}((1,)))
end
# test that inference doesn't error
@test isa(code_typed(f17572, (Type{Val{0}},)), Array)

# === with singleton constants
let f(x) = (x===nothing) ? 1 : 1.0
    @test Base.return_types(f, (Void,)) == Any[Int]
end

# issue #16530
mutable struct Foo16530a{dim}
    c::Vector{NTuple{dim, Float64}}
    d::Vector
end
mutable struct Foo16530b{dim}
    c::Vector{NTuple{dim, Float64}}
end
f16530a() = fieldtype(Foo16530a, :c)
f16530a(c) = fieldtype(Foo16530a, c)
f16530b() = fieldtype(Foo16530b, :c)
f16530b(c) = fieldtype(Foo16530b, c)

let T = Vector{Tuple{Vararg{Float64,dim}}} where dim
    @test f16530a() == T
    @test f16530a(:c) == T
    @test Base.return_types(f16530a, ()) == Any[Type{T}]
    @test Base.return_types(f16530b, ()) == Any[Type{T}]
    @test Base.return_types(f16530b, (Symbol,)) == Any[Type{T}]
end
@test f16530a(:d) == Vector

let T1 = Tuple{Int, Float64},
    T2 = Tuple{Int, Float32},
    T = Tuple{T1, T2}

    global f18037
    f18037() = fieldtype(T, 1)
    f18037(i) = fieldtype(T, i)

    @test f18037() === T1
    @test f18037(1) === T1
    @test f18037(2) === T2

    @test Base.return_types(f18037, ()) == Any[Type{T1}]
    @test Base.return_types(f18037, (Int,)) == Any[Union{Type{T1},Type{T2}}]
end

# issue #18015
mutable struct Triple18015
    a::Int
    b::Int
    c::Int
end
a18015(tri) = tri.a
b18015(tri) = tri.b
c18015(tri) = tri.c
setabc18015!(tri, a, b, c) = (tri.a = a; tri.b = b; tri.c = c)
let tri = Triple18015(1, 2, 3)
    setabc18015!(tri, b18015(tri), c18015(tri), a18015(tri))
    @test tri.a === 2 && tri.b === 3 && tri.c === 1
end

# issue #18222
f18222{T<:AbstractFloat}(::Union{T, Int}) = false
f18222(x) = true
g18222(x) = f18222(x)
@test f18222(1) == g18222(1) == true
@test f18222(1.0) == g18222(1.0) == false

# issue #18399
# TODO: this test is rather brittle
mutable struct TSlow18399{T}
    x::T
end
function hvcat18399(as)
    cb = ri->as[ri]
    g = Base.Generator(cb, 1)
    return g.f(1)
end
function cat_t18399(X...)
    for i = 2:1
        X[i]
        d->i
    end
end
C18399 = TSlow18399{Int}(1)
GB18399 = TSlow18399{Int}(1)
function test18399(C)
    B = GB18399::Union{TSlow18399{Int},TSlow18399{Any}}
    cat_t18399()
    cat_t18399(B, B, B)
    hvcat18399((C,))
    return hvcat18399(((2, 3),))
end
@test test18399(C18399) == (2, 3)

# issue #18450
f18450() = ifelse(true, Tuple{Vararg{Int}}, Tuple{Vararg})
@test f18450() == Tuple{Vararg{Int}}

# issue #18569
@test !Core.Inference.isconstType(Type{Tuple})

# ensure pure attribute applies correctly to all signatures of fpure
Base.@pure function fpure(a=rand(); b=rand())
    # use the `rand` function since it is known to be `@inline`
    # but would be too big to inline
    return a + b + rand()
end
gpure() = fpure()
gpure(x::Irrational) = fpure(x)
@test which(fpure, ()).pure
@test which(fpure, (typeof(pi),)).pure
@test !which(gpure, ()).pure
@test !which(gpure, (typeof(pi),)).pure
@test @code_typed(gpure())[1].pure
@test @code_typed(gpure(π))[1].pure
@test gpure() == gpure() == gpure()
@test gpure(π) == gpure(π) == gpure(π)

# Make sure @pure works for functions using the new syntax
Base.@pure (fpure2(x::T) where T) = T
@test which(fpure2, (Int64,)).pure

# issue #10880
function cat10880(a, b)
    Tuple{a.parameters..., b.parameters...}
end
@inferred cat10880(Tuple{Int8,Int16}, Tuple{Int32})

# issue #19348
function is_typed_expr(e::Expr)
    if e.head === :call ||
       e.head === :invoke ||
       e.head === :new ||
       e.head === :copyast ||
       e.head === :inert
        return true
    end
    return false
end
test_inferred_static(other::ANY) = true
test_inferred_static(slot::TypedSlot) = @test isleaftype(slot.typ)
function test_inferred_static(expr::Expr)
    if is_typed_expr(expr)
        @test isleaftype(expr.typ)
    end
    for a in expr.args
        test_inferred_static(a)
    end
end
function test_inferred_static(arrow::Pair)
    code, rt = arrow
    @test isleaftype(rt)
    @test code.inferred
    @test all(x->isleaftype(x), code.slottypes)
    @test all(x->isleaftype(x), code.ssavaluetypes)
    for e in code.code
        test_inferred_static(e)
    end
end

function g19348(x)
    a, b = x
    return a + b
end
test_inferred_static(@code_typed g19348((1, 2.0)))

# issue #5575
f5575() = zeros(Type[Float64][1], 1)
@test Base.return_types(f5575, ())[1] == Vector

# make sure Tuple{unknown} handles the possibility that `unknown` is a Vararg
function maybe_vararg_tuple_1()
    x = Any[Vararg{Int}][1]
    Tuple{x}
end
@test Type{Tuple{Vararg{Int}}} <: Base.return_types(maybe_vararg_tuple_1, ())[1]
function maybe_vararg_tuple_2()
    x = Type[Vararg{Int}][1]
    Tuple{x}
end
@test Type{Tuple{Vararg{Int}}} <: Base.return_types(maybe_vararg_tuple_2, ())[1]

# inference of `fieldtype`
mutable struct UndefField__
    x::Union{}
end
f_infer_undef_field() = fieldtype(UndefField__, :x)
@test Base.return_types(f_infer_undef_field, ()) == Any[Type{Union{}}]
@test f_infer_undef_field() === Union{}

mutable struct HasAbstractlyTypedField
    x::Union{Int,String}
end
f_infer_abstract_fieldtype() = fieldtype(HasAbstractlyTypedField, :x)
@test Base.return_types(f_infer_abstract_fieldtype, ()) == Any[Type{Union{Int,String}}]

# issue #11480
@noinline f11480(x,y) = x
let A = Ref
    function h11480(x::A{A{A{A{A{A{A{A{A{Int}}}}}}}}}) # enough for type_too_complex
        y :: Tuple{Vararg{typeof(x)}} = (x,) # apply_type(Vararg, too_complex) => TypeVar(_,Vararg)
        f(y[1], # fool getfield logic : Tuple{_<:Vararg}[1] => Vararg
          1) # make it crash by construction of the signature Tuple{Vararg,Int}
    end
    @test !Base.isvarargtype(Base.return_types(h11480, (Any,))[1])
end

# Issue 19641
foo19641() = let a = 1.0
    Core.Inference.return_type(x -> x + a, Tuple{Float64})
end
@inferred foo19641()

test_fast_eq(a, b) = @fastmath a == b
test_fast_ne(a, b) = @fastmath a != b
test_fast_lt(a, b) = @fastmath a < b
test_fast_le(a, b) = @fastmath a <= b
@inferred test_fast_eq(1f0, 1f0)
@inferred test_fast_ne(1f0, 1f0)
@inferred test_fast_lt(1f0, 1f0)
@inferred test_fast_le(1f0, 1f0)
@inferred test_fast_eq(1.0, 1.0)
@inferred test_fast_ne(1.0, 1.0)
@inferred test_fast_lt(1.0, 1.0)
@inferred test_fast_le(1.0, 1.0)

abstract type AbstractMyType18457{T,F,G} end
struct MyType18457{T,F,G}<:AbstractMyType18457{T,F,G} end
tpara18457{I}(::Type{AbstractMyType18457{I}}) = I
tpara18457{A<:AbstractMyType18457}(::Type{A}) = tpara18457(supertype(A))
@test tpara18457(MyType18457{true}) === true

@testset "type inference error #19322" begin
    Y_19322 = reshape(round.(Int, abs.(randn(5*1000)))+1,1000,5)

    function FOO_19322(Y::AbstractMatrix; frac::Float64=0.3, nbins::Int=100, n_sims::Int=100)
        num_iters, num_chains = size(Y)
        start_iters = unique([1; [round(Int64, s) for s in logspace(log(10,100),
                                                                    log(10,num_iters/2),nbins-1)]])
        result = zeros(Float64, 10, length(start_iters) * num_chains)
        j=1
        for c in 1:num_chains
            for st in 1:length(start_iters)
                n = length(start_iters[st]:num_iters)
                idx1 = start_iters[st]:round(Int64, start_iters[st] + frac * n - 1)
                idx2 = round(Int64, num_iters - frac * n + 1):num_iters
                y1 = Y[idx1,c]
                y2 = Y[idx2,c]
                n_min = min(length(y1), length(y2))
                X = [y1[1:n_min] y2[(end - n_min + 1):end]]
            end
        end
    end

    @test_nowarn FOO_19322(Y_19322)
end

randT_inferred_union() = rand(Bool) ? rand(Bool) ? 1 : 2.0 : nothing
function f_inferred_union()
    b = randT_inferred_union()
    if !(nothing !== b) === true
        return f_inferred_union_nothing(b)
    elseif (isa(b, Float64) === true) !== false
        return f_inferred_union_float(b)
    else
        return f_inferred_union_int(b)
    end
end
f_inferred_union_nothing(::Void) = 1
f_inferred_union_nothing(::Any) = "broken"
f_inferred_union_float(::Float64) = 2
f_inferred_union_float(::Any) = "broken"
f_inferred_union_int(::Int) = 3
f_inferred_union_int(::Any) = "broken"
@test @inferred(f_inferred_union()) in (1, 2, 3)

# issue #11015
mutable struct AT11015
    f::Union{Bool,Function}
end

g11015{S}(::Type{S}, ::S) = 1
f11015(a::AT11015) = g11015(Base.fieldtype(typeof(a), :f), true)
g11015(::Type{Bool}, ::Bool) = 2.0
@test Int <: Base.return_types(f11015, (AT11015,))[1]
@test f11015(AT11015(true)) === 1

# better inference of apply (#20343)
f20343(::String, ::Int) = 1
f20343(::Int, ::String, ::Int, ::Int) = 1
f20343(::Int, ::Int, ::String, ::Int, ::Int, ::Int) = 1
f20343(::Union{Int,String}...) = Int8(1)
f20343(::Any...) = "no"
function g20343()
    n = rand(1:3)
    i = ntuple(i->n==i ? "" : 0, 2n)::Union{Tuple{String,Int},Tuple{Int,String,Int,Int},Tuple{Int,Int,String,Int,Int,Int}}
    f20343(i...)
end
@test Base.return_types(g20343, ()) == [Int]
function h20343()
    n = rand(1:3)
    i = ntuple(i->n==i ? "" : 0, 3)::Union{Tuple{String,Int,Int},Tuple{Int,String,Int},Tuple{Int,Int,String}}
    f20343(i..., i...)
end
@test all(t -> t<:Integer, Base.return_types(h20343, ()))
function i20343()
    f20343([1,2,3]..., 4)
end
@test Base.return_types(i20343, ()) == [Int8]
struct Foo20518 <: AbstractVector{Int}; end # issue #20518; inference assumed AbstractArrays
Base.getindex(::Foo20518, ::Int) = "oops"      # not to lie about their element type
Base.indices(::Foo20518) = (Base.OneTo(4),)
foo20518(xs::Any...) = -1
foo20518(xs::Int...) = [0]
bar20518(xs) = sum(foo20518(xs...))
@test bar20518(Foo20518()) == -1
f19957(::Int) = Int8(1)            # issue #19957, inference failure when splatting a number
f19957(::Int...) = Int16(1)
f19957(::Any...) = "no"
g19957(x) = f19957(x...)
@test all(t -> t<:Union{Int8,Int16}, Base.return_types(g19957, (Int,))) # with a full fix, this should just be Int8

# Inference for some type-level computation
fUnionAll{T}(::Type{T}) = Type{S} where S <: T
@inferred fUnionAll(Real) == Type{T} where T <: Real
@inferred fUnionAll(Rational{T} where T <: AbstractFloat) == Type{T} where T<:(Rational{S} where S <: AbstractFloat)

fComplicatedUnionAll{T}(::Type{T}) = Type{Tuple{S,rand() >= 0.5 ? Int : Float64}} where S <: T
let pub = Base.parameter_upper_bound, x = fComplicatedUnionAll(Real)
    @test pub(pub(x, 1), 1) == Real
    @test pub(pub(x, 1), 2) == Int || pub(pub(x, 1), 2) == Float64
end

# issue #20733
# run this test in a separate process to avoid interfering with `getindex`
let def = "Base.getindex(t::NTuple{3,NTuple{2,Int}}, i::Int, j::Int, k::Int) = (t[1][i], t[2][j], t[3][k])"
    @test readstring(`$(Base.julia_cmd()) --startup-file=no -E "$def;test(t) = t[2,1,2];test(((3,4), (5,6), (7,8)))"`) ==
        "(4, 5, 8)\n"
end

# issue #20267
mutable struct T20267{T}
    inds::Vector{T}
end
# infinite type growth via lower bounds (formed by intersection)
f20267(x::T20267{T}, y::T) where (T) = f20267(Any[1][1], x.inds)
@test Base.return_types(f20267, (Any, Any)) == Any[Union{}]

# issue #20615
let A = 1:2, z = zip(A, A, A, A, A, A, A, A, A, A, A, A)
    @test z isa Core.Inference.limit_type_depth(typeof(z), 0)
    @test start(z) == (1, (1, (1, (1, (1, (1, (1, (1, (1, (1, (1, 1)))))))))))
end
# introduce TypeVars in Unions in invariant position
let T = Val{Val{Val{Union{Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64}}}}
    @test T <: Core.Inference.limit_type_depth(T, 0)
end

# issue #20704
f20704(::Int) = 1
Base.@pure b20704(x::ANY) = f20704(x)
@test b20704(42) === 1
@test_throws MethodError b20704(42.0)

bb20704() = b20704(Any[1.0][1])
@test_throws MethodError bb20704()

v20704() = Val{b20704(Any[1.0][1])}
@test_throws MethodError v20704()
@test Base.return_types(v20704, ()) == Any[Type{Val{1}}]

Base.@pure g20704(::Int) = 1
h20704(x::ANY) = g20704(x)
@test g20704(1) === 1
@test_throws MethodError h20704(1.2)

Base.@pure c20704() = (f20704(1.0); 1)
d20704() = c20704()
@test_throws MethodError d20704()

Base.@pure function a20704(x)
    rand()
    42
end
aa20704(x) = x(nothing)
@test code_typed(aa20704, (typeof(a20704),))[1][1].pure

#issue #21065, elision of _apply when splatted expression is not effect_free
function f21065(x,y)
    println("x=$x, y=$y")
    return x, y
end
g21065(x,y) = +(f21065(x,y)...)
function test_no_apply(expr::Expr)
    return all(test_no_apply, expr.args)
end
function test_no_apply(ref::GlobalRef)
    return ref.mod != Core || ref.name !== :_apply
end
test_no_apply(::Any) = true
@test all(test_no_apply, code_typed(g21065, Tuple{Int,Int})[1].first.code)

# issue #20033
# check return_type_tfunc for calls where no method matches
bcast_eltype_20033(f, A) = Core.Inference.return_type(f, Tuple{eltype(A)})
err20033(x::Float64...) = prod(x)
@test bcast_eltype_20033(err20033, [1]) === Union{}
@test Base.return_types(bcast_eltype_20033, (typeof(err20033), Vector{Int},)) == Any[Type{Union{}}]
# return_type on builtins
@test Core.Inference.return_type(tuple, Tuple{Int,Int8,Int}) === Tuple{Int,Int8,Int}

# issue #21088
@test Core.Inference.return_type(typeof, Tuple{Int}) == Type{Int}

# Inference of constant svecs
@eval fsvecinf() = $(QuoteNode(Core.svec(Tuple{Int,Int}, Int)))[1]
@test Core.Inference.return_type(fsvecinf, Tuple{}) == Type{Tuple{Int,Int}}

# nfields tfunc on `DataType`
let f = ()->Val{nfields(DataType[Int][1])}
    @test f() == Val{0}
end

# inference on invalid getfield call
@eval _getfield_with_string_() = getfield($(1=>2), "")
@test Base.return_types(_getfield_with_string_, ()) == Any[Union{}]

# inference AST of a constant return value
f21175() = 902221
@test code_typed(f21175, ())[1].second === Int
# call again, so that the AST is built on-demand
let e = code_typed(f21175, ())[1].first.code[1]::Expr
    @test e.head === :return
    @test e.args[1] ∈ (902221, Core.QuoteNode(902221))
end

# issue #10207
mutable struct T10207{A, B}
    a::A
    b::B
end
@test code_typed(T10207, (Int,Any))[1].second == T10207{Int,T} where T

# issue #21410
f21410(::V, ::Pair{V,E}) where {V, E} = E
@test code_typed(f21410, Tuple{Ref, Pair{Ref{T},Ref{T}} where T<:Number})[1].second == Type{Ref{T}} where T<:Number

# issue #21369
function inf_error_21369(arg)
    if arg
        # invalid instantiation, causing throw during inference
        Complex{String}
    end
end
function break_21369()
    try
        error("uhoh")
    catch
        eval(:(inf_error_21369(false)))
        bt = catch_backtrace()
        i = 1
        local fr
        while true
            fr = Base.StackTraces.lookup(bt[i])[end]
            if !fr.from_c
                break
            end
            i += 1
        end
        @test fr.func === :break_21369
        rethrow()
    end
end
@test_throws ErrorException break_21369()  # not TypeError

# issue #17003
abstract type AArray_17003{T,N} end
AVector_17003{T} = AArray_17003{T,1}

struct Nable_17003{T}
end

struct NArray_17003{T,N} <: AArray_17003{Nable_17003{T},N}
end

(::Type{NArray_17003}){T,N}(::Array{T,N}) = NArray_17003{T,N}()

gl_17003 = [1, 2, 3]

f2_17003(item::AVector_17003) = nothing
f2_17003(::Any) = f2_17003(NArray_17003(gl_17003))

@test f2_17003(1) == nothing

# issue #20847
function segfaultfunction_20847{N, T}(A::Vector{NTuple{N, T}})
    B = reinterpret(T, A, (N, length(A)))
    return nothing
end

tuplevec_20847 = Tuple{Float64, Float64}[(0.0,0.0), (1.0,0.0)]

for A in (1,)
    @test segfaultfunction_20847(tuplevec_20847) == nothing
end

# issue #21848
@test Core.Inference.limit_type_depth(Ref{Complex{T} where T}, Core.Inference.MAX_TYPE_DEPTH) == Ref
let T = Tuple{Tuple{Int64, Void},
              Tuple{Tuple{Int64, Void},
                    Tuple{Int64, Tuple{Tuple{Int64, Void},
                                       Tuple{Tuple{Int64, Void}, Tuple{Int64, Tuple{Tuple{Int64, Void}, Tuple{Tuple, Tuple}}}}}}}}
    @test Core.Inference.limit_type_depth(T, 0) >: T
    @test Core.Inference.limit_type_depth(T, 1) >: T
    @test Core.Inference.limit_type_depth(T, 2) >: T
end

# Issue #20902, check that this doesn't error.
@generated function test_20902()
    quote
        10 + 11
    end
end
@test length(code_typed(test_20902, (), optimize = false)) == 1
@test length(code_typed(test_20902, (), optimize = false)) == 1

# normalization of arguments with constant Types as parameters
g21771(T) = T
f21771(::Val{U}) where {U} = Tuple{g21771(U)}
@test @inferred(f21771(Val{Int}())) === Tuple{Int}
@test @inferred(f21771(Val{Union{}}())) === Tuple{Union{}}
@test @inferred(f21771(Val{Integer}())) === Tuple{Integer}

# issue #21653
# ensure that we don't try to resolve cycles using uncached edges
f21653() = f21653()
@test code_typed(f21653, Tuple{}, optimize=false)[1] isa Pair{CodeInfo, typeof(Union{})}

@noinline map3_22347(f, t::Tuple{}) = ()
@noinline map3_22347(f, t::Tuple) = (f(t[1]), map3_22347(f, Base.tail(t))...)
# issue #22347
let niter = 0
    map3_22347((1, 2, 3, 4)) do y
        niter += 1
        nothing
    end
    @test niter == 4
end

let isa_tfunc = Core.Inference.t_ffunc_val[
        findfirst(Core.Inference.t_ffunc_key, isa)][3]
    @test isa_tfunc(Array, Const(AbstractArray)) === Const(true)
    @test isa_tfunc(Array, Type{AbstractArray}) === Const(true)
    @test isa_tfunc(Array, Type{AbstractArray{Int}}) == Bool
    @test isa_tfunc(Array{Real}, Type{AbstractArray{Int}}) === Const(false)
    @test isa_tfunc(Array{Real, 2}, Const(AbstractArray{Real, 2})) === Const(true)
    @test isa_tfunc(Array{Real, 2}, Const(AbstractArray{Int, 2})) === Const(false)
    @test isa_tfunc(DataType, Int) === Bool # could be improved
    @test isa_tfunc(DataType, Const(Type{Int})) === Bool
    @test isa_tfunc(DataType, Const(Type{Array})) === Bool
    @test isa_tfunc(UnionAll, Const(Type{Int})) === Bool # could be improved
    @test isa_tfunc(UnionAll, Const(Type{Array})) === Bool
    @test isa_tfunc(Union, Const(Union{Float32, Float64})) === Bool
    @test isa_tfunc(Union, Type{Union}) === Const(true)
    @test isa_tfunc(typeof(Union{}), Const(Int)) === Bool # any result is ok
    @test isa_tfunc(typeof(Union{}), Const(Union{})) === Const(false)
    @test isa_tfunc(typeof(Union{}), typeof(Union{})) === Const(false)
    @test isa_tfunc(typeof(Union{}), Union{}) === Const(false) # any result is ok
    @test isa_tfunc(typeof(Union{}), Type{typeof(Union{})}) === Const(true)
    @test isa_tfunc(typeof(Union{}), Const(typeof(Union{}))) === Const(true)
    let c = Conditional(Core.SlotNumber(0), Const(Union{}), Const(Union{}))
        @test isa_tfunc(c, Const(Bool)) === Const(true)
        @test isa_tfunc(c, Type{Bool}) === Const(true)
        @test isa_tfunc(c, Const(Real)) === Const(true)
        @test isa_tfunc(c, Type{Real}) === Const(true)
        @test isa_tfunc(c, Const(Signed)) === Const(false)
        @test isa_tfunc(c, Type{Complex}) === Const(false)
        @test isa_tfunc(c, Type{Complex{T}} where T) === Const(false)
    end
    @test isa_tfunc(Val{1}, Type{Val{T}} where T) === Bool
    @test isa_tfunc(Val{1}, DataType) === Bool
    @test isa_tfunc(Any, Const(Any)) === Const(true)
    @test isa_tfunc(Any, Union{}) === Const(false) # any result is ok
    @test isa_tfunc(Any, Type{Union{}}) === Const(false)
    @test isa_tfunc(Union{Int64, Float64}, Type{Real}) === Const(true)
    @test isa_tfunc(Union{Int64, Float64}, Type{Integer}) === Bool
    @test isa_tfunc(Union{Int64, Float64}, Type{AbstractArray}) === Const(false)
end

let subtype_tfunc = Core.Inference.t_ffunc_val[
        findfirst(Core.Inference.t_ffunc_key, <:)][3]
    @test subtype_tfunc(Type{<:Array}, Const(AbstractArray)) === Const(true)
    @test subtype_tfunc(Type{<:Array}, Type{AbstractArray}) === Const(true)
    @test subtype_tfunc(Type{<:Array}, Type{AbstractArray{Int}}) == Bool
    @test subtype_tfunc(Type{<:Array{Real}}, Type{AbstractArray{Int}}) === Const(false)
    @test subtype_tfunc(Type{<:Array{Real, 2}}, Const(AbstractArray{Real, 2})) === Const(true)
    @test subtype_tfunc(Type{Array{Real, 2}}, Const(AbstractArray{Int, 2})) === Const(false)
    @test subtype_tfunc(DataType, Int) === Bool
    @test subtype_tfunc(DataType, Const(Type{Int})) === Bool
    @test subtype_tfunc(DataType, Const(Type{Array})) === Bool
    @test subtype_tfunc(UnionAll, Const(Type{Int})) === Bool
    @test subtype_tfunc(UnionAll, Const(Type{Array})) === Bool
    @test subtype_tfunc(Union, Const(Union{Float32, Float64})) === Bool
    @test subtype_tfunc(Union, Type{Union}) === Bool
    @test subtype_tfunc(Union{}, Const(Int)) === Const(true) # any result is ok
    @test subtype_tfunc(Union{}, Const(Union{})) === Const(true) # any result is ok
    @test subtype_tfunc(Union{}, typeof(Union{})) === Const(true) # any result is ok
    @test subtype_tfunc(Union{}, Union{}) === Const(true) # any result is ok
    @test subtype_tfunc(Union{}, Type{typeof(Union{})}) === Const(true) # any result is ok
    @test subtype_tfunc(Union{}, Const(typeof(Union{}))) === Const(true) # any result is ok
    @test subtype_tfunc(typeof(Union{}), Const(typeof(Union{}))) === Const(true) # Union{} <: typeof(Union{})
    @test subtype_tfunc(typeof(Union{}), Const(Int)) === Const(true) # Union{} <: Int
    @test subtype_tfunc(typeof(Union{}), Const(Union{})) === Const(true) # Union{} <: Union{}
    @test subtype_tfunc(typeof(Union{}), Type{typeof(Union{})}) === Const(true) # Union{} <: Union{}
    @test subtype_tfunc(typeof(Union{}), Type{typeof(Union{})}) === Const(true) # Union{} <: typeof(Union{})
    @test subtype_tfunc(typeof(Union{}), Type{Union{}}) === Const(true) # Union{} <: Union{}
    @test subtype_tfunc(Type{Union{}}, typeof(Union{})) === Const(true) # Union{} <: Union{}
    @test subtype_tfunc(Type{Union{}}, Const(typeof(Union{}))) === Const(true) # Union{} <: typeof(Union{})
    @test subtype_tfunc(Type{Union{}}, Const(Int)) === Const(true) # Union{} <: typeof(Union{})
    @test subtype_tfunc(Type{Union{}}, Any) === Const(true) # Union{} <: Any
    @test subtype_tfunc(Type{Union{}}, Union{Type{Int64}, Type{Float64}}) === Const(true)
    @test subtype_tfunc(Type{Union{}}, Union{Type{T}, Type{Float64}} where T) === Const(true)
    let c = Conditional(Core.SlotNumber(0), Const(Union{}), Const(Union{}))
        @test subtype_tfunc(c, Const(Bool)) === Bool # any result is ok
    end
    @test subtype_tfunc(Type{Val{1}}, Type{Val{T}} where T) === Bool
    @test subtype_tfunc(Type{Val{1}}, DataType) === Bool
    @test subtype_tfunc(Type, Type{Val{T}} where T) === Bool
    @test subtype_tfunc(Type{Val{T}} where T, Type) === Bool
    @test subtype_tfunc(Any, Const(Any)) === Const(true)
    @test subtype_tfunc(Type{Any}, Const(Any)) === Const(true)
    @test subtype_tfunc(Any, Union{}) === Bool # any result is ok
    @test subtype_tfunc(Type{Any}, Union{}) === Const(false) # any result is ok
    @test subtype_tfunc(Type, Union{}) === Bool # any result is ok
    @test subtype_tfunc(Type, Type{Union{}}) === Bool
    @test subtype_tfunc(Union{Type{Int64}, Type{Float64}}, Type{Real}) === Const(true)
    @test subtype_tfunc(Union{Type{Int64}, Type{Float64}}, Type{Integer}) === Bool
    @test subtype_tfunc(Union{Type{Int64}, Type{Float64}}, Type{AbstractArray}) === Const(false)
end

function f23024(::Type{T}, ::Int) where T
    1 + 1
end
v23024 = 0
g23024(TT::Tuple{DataType}) = f23024(TT[1], v23024)
@test Base.return_types(f23024, (DataType, Any)) == Any[Int]
@test Base.return_types(g23024, (Tuple{DataType},)) == Any[Int]
@test g23024((UInt8,)) === 2

# issue #22290
f22290() = return nothing
for i in 1:3
    ir = sprint(io->code_llvm(io, f22290, Tuple{}))
    @test contains(ir, "julia_f22290")
end

# approximate static parameters due to unions
let T1 = Array{Float64}, T2 = Array{_1,2} where _1
    inference_test_copy(a::T) where {T<:Array} = ccall(:jl_array_copy, Ref{T}, (Any,), a)
    rt = Union{Base.return_types(inference_test_copy, (Union{T1,T2},))...}
    @test rt >: T1 && rt >: T2

    el(x::T) where {T} = eltype(T)
    rt = Union{Base.return_types(el, (Union{T1,Array{Float32,2}},))...}
    @test rt >: Union{Type{Float64}, Type{Float32}}

    g(x::Ref{T}) where {T} = T
    rt = Union{Base.return_types(g, (Union{Ref{Array{Float64}}, Ref{Array{Float32}}},))...}
    @test rt >: Union{Type{Array{Float64}}, Type{Array{Float32}}}
end
