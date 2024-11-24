if !Core.isdefined(:LJ_MAIN_FILE)
  include("../lj.jl")
end

using ..lj:   TUnion,
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

usingTest() # using Base.Test / using Test

@testset "Tests for convert_ast              " begin
    @test lj_parse_type("Bool where T") === TWhere(TName(:Bool), TVar(:T))

    # Builtin forms
    @test lj_parse_type("Type") === TWhere(TType(TVar(:T)), TVar(:T))
    @test lj_parse_type("UnionAll") === TUnionAll(TDataType())

    # Parsing typeof
    @test lj_parse_type("typeof(Type)") === TUnionAll(TDataType())
    @test lj_parse_type("typeof(prBool)") == TName(Symbol("typeof(prBool)"))
    if lj_julia_dev()
        @test lj_parse_type("typeof(Base.:(+))") == TName("typeof(:+)", "Base")
    else
        @test lj_parse_type("typeof(Base.:(+))") == TName("typeof(+)", "Base")
    end
    @test lj_parse_type("typeof(Core._apply)") == TName("typeof(_apply)", "Core")
    
    # Parsing bounds
    @test convert_ast(Meta.parse("T where T <: Bool")) ===
      TWhere(TVar(:T), TVar(:T), EmptyUnion, TName(:Bool))
    @test convert_ast(Meta.parse("T where T >: Bool")) ===
      TWhere(TVar(:T), TVar(:T), TName(:Bool), TAny())
    @test convert_ast(Meta.parse("T where Bool <: T <: String")) ===
      TWhere(TVar(:T), TVar(:T), TName(:Bool), TName(:String))

    # Parsing values
    @test convert_ast(Meta.parse("Array{Bool,1}")) ==
      TApp(TName(:Array), [TName(:Bool), TValue("1")])

    # Vector-Array translation
    @test convert_ast(Meta.parse("Vector{Bool}")) ==
      TApp(TName(:Array), [TName(:Bool), TValue("1")])
      
    @test lj_parse_type("Val{'a'}") == 
      TApp(TName(:Val), [TValue("a")])
      
    # Qualified names
    @test lj_parse_type("Base.Vector{T} where T") == 
        TWhere(
            TApp(TName(:Vector, "Base"), [TVar(:T)]), 
            TVar(:T))
end

@testset "Tests for convert_tydecl           " begin
    # Abstract types
    td1 = convert_tydecl(Meta.parse("abstract type My end"))
    @test td1.name == :My && td1.super == TAny() && length(td1.params) == 0

    td1 = convert_tydecl(Meta.parse("abstract type My <: Bar end"))
    @test td1.name == :My && td1.super == TName(:Bar) && length(td1.params) == 0

    td1 = convert_tydecl(Meta.parse("abstract type My{T} end"))
    @test td1.name == :My && td1.super == TAny() && td1.params[1] == (EmptyUnion, :T, TAny())

    td1 = convert_tydecl(Meta.parse("abstract type My{T} <: Bar end"))
    @test td1.name == :My && td1.super == TName(:Bar) && td1.params[1] == (EmptyUnion, :T, TAny())

    # Bounded ty-vars
    td1 = convert_tydecl(Meta.parse("abstract type My{T <: Bool} end"))
    @test td1.name == :My && td1.super == TAny() && td1.params[1] == (EmptyUnion, :T, TName(:Bool))

    td1 = convert_tydecl(Meta.parse("abstract type My{T >: Bool} end"))
    @test td1.name == :My && td1.super == TAny() && td1.params[1] == (TName(:Bool), :T, TAny())

    td1 = convert_tydecl(Meta.parse("abstract type My{String <: T <: Bool} end"))
    @test td1.name == :My && td1.super == TAny() && td1.params[1] == (TName(:String), :T, TName(:Bool))

    # Concrete types
    td1 = convert_tydecl(Meta.parse("struct My end"))
    @test td1.name == :My && td1.super == TAny() && length(td1.params) == 0
    
    td1 = convert_tydecl(Meta.parse("struct My <: Bar end"))
    @test td1.name == :My && td1.super == TName(:Bar) && length(td1.params) == 0
    
    td1 = convert_tydecl(Meta.parse("struct My{T} end"))
    @test td1.name == :My && td1.super == TAny() && td1.params[1] == (EmptyUnion, :T, TAny())
    
    td1 = convert_tydecl(Meta.parse("struct My{T} <: Bar end"))
    @test td1.name == :My && td1.super == TName(:Bar) && td1.params[1] == (EmptyUnion, :T, TAny())
end

@testset "Tests for convert_tydecl           " begin
    @test string(betared(lj_parse_type("Type"))) == "Type{T} where T"
    @test string(betared(lj_parse_type("(Ref{T} where T){Int}"))) == "Ref{Int64}"
    @test string(betared(lj_parse_type("Union{(Ref{T} where T){Int}, Bool}")))  == "Union{Ref{Int64}, Bool}"
end

