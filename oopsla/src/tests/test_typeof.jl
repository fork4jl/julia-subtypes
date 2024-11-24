if !Core.isdefined(:LJ_MAIN_FILE)
  include("../lj.jl")
end

using ..lj: compose_unionalls, lj_simplify, no_union, cartesian, 
            TDataType, TUnionAll, TSuperUnion, TName, TAny, TTuple

usingTest() # using Base.Test / using Test

@testset "Tests axioms of lj_typeof          " begin
    @test lj_typeof("Any")                      === TDataType()
    @test lj_typeof("Union")                    === TDataType()
    @test lj_typeof("Int")                      === TDataType()
end

@testset "lj_typeof for user-defined ty-names" begin

    # User-defined types
    @test lj_typeof("Bar", ["struct Bar end"])        === TDataType()
    @test lj_typeof("Bar", ["struct Bar{T} end"])     === compose_unionalls(1)
    @test lj_typeof("Bar", ["struct Bar{T,S} end"])   === compose_unionalls(2)
    @test_throws LJErrNameNotFound lj_typeof("Bar")


    # User-defined parametric types instantiations
    @test lj_typeof("Bar{Int}", ["abstract type Bar{T} end"])        === TDataType()
    @test lj_typeof("Bar", ["abstract type Bar{T} end"])             === compose_unionalls(1)
    @test lj_typeof("Bar", ["abstract type Bar{T,S} end"])           === compose_unionalls(2)
    @test lj_typeof("Bar{Int}", ["abstract type Bar{T,S} end"])      === compose_unionalls(1)
    @test lj_typeof("Bar{Int,Real}", ["abstract type Bar{T,S} end"]) === TDataType()
    @test_throws AssertionError lj_typeof("Bar{Int,Real,Bool}", ["abstract type Bar{T,S} end"])

    # Base types and hidden `where`s
    @test lj_typeof("Vector{Int}") === TDataType()
    @test lj_typeof("Vector{}")    === compose_unionalls(1)
    @test lj_typeof("Vector") === TUnionAll(TDataType())
    @test_throws AssertionError lj_typeof("Int{Int}")

    # WHERE
    @test lj_typeof("Vector{T} where T") === TUnionAll(TDataType())
    @test lj_typeof("(Vector{T} where T){Int}") === TDataType()
    @test lj_typeof("(Tuple{Vector{T} where T, Vector{S}} where S){Int}") === TDataType()
    @test lj_typeof("(Tuple{Vector, Vector{S}} where S){Int}") === TDataType()
    @test lj_typeof("(Tuple{Vector{T}, Vector{S}} where T where S){Int}") === TUnionAll(TDataType())
    
    @test lj_typeof("(Union{T, String} where T){Int}") === TSuperUnion()
end

@testset "Simplifications, unions....        " begin

    @test lj_typeof("Union{Int}")   === TDataType()

    @test lj_typeof("Union{Int, Real}")     === TDataType()
    @test lj_typeof("Union{Int, Char}")   === TSuperUnion()

    @test lj_typeof("Union{}")   == TName("TypeofBottom", "Core")
    @test lj_typeof("Core.Union{}")   == TName("TypeofBottom", "Core")
    @test lj_typeof("Base.Union{}")   == TName("TypeofBottom", "Core")

  # Simplification engine
  @test lj_simplify("T where T") === TAny()
  @test lj_simplify("Bool where T") === TName("Bool")
  @test lj_typeof("Tuple{Vector{T} where T} where T") === TDataType()
  @test lj_typeof("Union{T,T} where T") === TDataType()
  @test lj_typeof("T where T where S") === TDataType()
  @test lj_typeof("T where S where T") === TDataType()
  
  # FROM LOGS
  @test lj_typeof("Tuple{typeof(Base.convert), Type{AbstractArray} where M<:(AbstractArray{T, 2} where T) where S} where S") === TDataType()
  @test lj_typeof("Union{Array{T, 2} where T<:Float64, Array{T, 2} where T<:Float32}") === TSuperUnion()

end

@testset "Tests for aux utilities            " begin

    # Cartesian tests
    em = Vector{Vector{Int}}()
    ee = copy(em)
    push!(ee,Vector{Int}())
    @test cartesian(em) == ee # this is weird
    @test cartesian(ee) == em # this is even more...

    @test cartesian([[1]]) == [[1]]
    @test cartesian([[1, 2]]) == [[1], [2]]
    @test cartesian([[1,2],[3]]) == [[1,3],[2,3]]
    @test cartesian([[1,2],[3],[4,5]]) == [[1,3,4], [1,3,5], [2,3,4], [2,3,5]]

    # No-union tests
    v = ASTBase[ TTuple(ASTBase[TName(:A), TName(:B)])
               , TTuple(ASTBase[TName(:A), TName(:C)])]
    u = no_union(lj_parse_type("Tuple{A, Union{B,C}}"))
    @test ((v[1].ts == u[1].ts) && (v[2].ts == u[2].ts))
end

