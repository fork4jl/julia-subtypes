# This file is a part of Julia. License is MIT: https://julialang.org/license

# Array test
isdefined(Main, :TestHelpers) || @eval Main include("TestHelpers.jl")
using TestHelpers.OAs

@testset "basics" begin
    @test length([1, 2, 3]) == 3
    @test countnz([1, 2, 3]) == 3

    let a = ones(4), b = a+a, c = a-a
        @test b[1] === 2. && b[2] === 2. && b[3] === 2. && b[4] === 2.
        @test c[1] === 0. && c[2] === 0. && c[3] === 0. && c[4] === 0.
    end

    @test length((1,)) == 1
    @test length((1,2)) == 2

    @test isequal(1.+[1,2,3], [2,3,4])
    @test isequal([1,2,3].+1, [2,3,4])
    @test isequal(1.-[1,2,3], [0,-1,-2])
    @test isequal([1,2,3].-1, [0,1,2])

    @test isequal(5*[1,2,3], [5,10,15])
    @test isequal([1,2,3]*5, [5,10,15])
    @test isequal(1./[1,2,5], [1.0,0.5,0.2])
    @test isequal([1,2,3]/5, [0.2,0.4,0.6])

    @test isequal(2.%[1,2,3], [0,0,2])
    @test isequal([1,2,3].%2, [1,0,1])
    @test isequal(2.÷[1,2,3], [2,1,0])
    @test isequal([1,2,3].÷2, [0,1,1])
    @test isequal(-2.%[1,2,3], [0,0,-2])
    @test isequal([-1,-2,-3].%2, [-1,0,-1])
    @test isequal(-2.÷[1,2,3], [-2,-1,0])
    @test isequal([-1,-2,-3].÷2, [0,-1,-1])

    @test isequal(1.<<[1,2,5], [2,4,32])
    @test isequal(128.>>[1,2,5], [64,32,4])
    @test isequal(2.>>1, 1)
    @test isequal(1.<<1, 2)
    @test isequal([1,2,5].<<[1,2,5], [2,8,160])
    @test isequal([10,20,50].>>[1,2,5], [5,5,1])


    a = ones(2,2)
    a[1,1] = 1
    a[1,2] = 2
    a[2,1] = 3
    a[2,2] = 4
    b = a'
    @test a[1,1] == 1. && a[1,2] == 2. && a[2,1] == 3. && a[2,2] == 4.
    @test b[1,1] == 1. && b[2,1] == 2. && b[1,2] == 3. && b[2,2] == 4.
    a[[1 2 3 4]] = 0
    @test a == zeros(2,2)
    a[[1 2], [1 2]] = 1
    @test a == ones(2,2)
    a[[1 2], 1] = 0
    @test a[1,1] == 0. && a[1,2] == 1. && a[2,1] == 0. && a[2,2] == 1.
    a[:, [1 2]] = 2
    @test a == 2ones(2,2)

    a = Array{Float64}(2, 2, 2, 2, 2)
    a[1,1,1,1,1] = 10
    a[1,2,1,1,2] = 20
    a[1,1,2,2,1] = 30

    @test a[1,1,1,1,1] == 10
    @test a[1,2,1,1,2] == 20
    @test a[1,1,2,2,1] == 30

    @test_throws ArgumentError reinterpret(Int8, a)

    b = reshape(a, (32,))
    @test b[1]  == 10
    @test b[19] == 20
    @test b[13] == 30
    @test_throws DimensionMismatch reshape(b,(5,7))
    @test_throws DimensionMismatch reshape(b,(35,))
    @test_throws DimensionMismatch reinterpret(Int, b, (35,))
    @test_throws ArgumentError reinterpret(Any, b, (32,))
    @test_throws DimensionMismatch reinterpret(Complex128, b, (32,))
    c = ["hello", "world"]
    @test_throws ArgumentError reinterpret(Float32, c, (2,))
    a = Vector(ones(5))
    @test_throws ArgumentError resize!(a, -2)

    b = rand(32)
    a = reshape(b, (2, 2, 2, 2, 2))
    @test ndims(a) == 5
    @test a[2,1,2,2,1] == b[14]
    @test a[2,2,2,2,2] == b[end]
end
@testset "reshaping SubArrays" begin
    a = collect(reshape(1:5, 1, 5))
    @testset "linearfast" begin
        s = view(a, :, 2:4)
        r = reshape(s, (length(s),))
        @test length(r) == 3
        @test r[1] == 2
        @test r[3,1] == 4
        @test r[Base.ReshapedIndex(CartesianIndex((1,2)))] == 3
        @test parent(reshape(r, (1,3))) === r.parent === s
        @test parentindexes(r) == (1:1, 1:3)
        @test reshape(r, (3,)) === r
        @test convert(Array{Int,1}, r) == [2,3,4]
        @test_throws MethodError convert(Array{Int,2}, r)
        @test convert(Array{Int}, r) == [2,3,4]
        @test Base.unsafe_convert(Ptr{Int}, r) == Base.unsafe_convert(Ptr{Int}, s)
        @test isa(r, StridedArray)  # issue #22411
    end
    @testset "linearslow" begin
        s = view(a, :, [2,3,5])
        r = reshape(s, length(s))
        @test length(r) == 3
        @test r[1] == 2
        @test r[3,1] == 5
        @test r[Base.ReshapedIndex(CartesianIndex((1,2)))] == 3
        @test parent(reshape(r, (1,3))) === r.parent === s
        @test parentindexes(r) == (1:1, 1:3)
        @test reshape(r, (3,)) === r
        @test convert(Array{Int,1}, r) == [2,3,5]
        @test_throws MethodError convert(Array{Int,2}, r)
        @test convert(Array{Int}, r) == [2,3,5]
        @test_throws ErrorException Base.unsafe_convert(Ptr{Int}, r)
        r[2] = -1
        @test a[3] == -1
        a = zeros(0, 5)  # an empty linearslow array
        s = view(a, :, [2,3,5])
        @test length(reshape(s, length(s))) == 0
    end
end
@testset "reshape(a, Val{N})" begin
    a = ones(Int,3,3)
    s = view(a, 1:2, 1:2)
    for N in (1,3)
        @test isa(reshape(a, Val{N}), Array{Int,N})
        @test isa(reshape(s, Val{N}), Base.ReshapedArray{Int,N})
    end
end
@testset "reshape with colon" begin
    # Reshape with an omitted dimension
    let A = linspace(1, 60, 60)
        @test size(reshape(A, :))         == (60,)
        @test size(reshape(A, :, 1))      == (60, 1)
        @test size(reshape(A, (:, 2)))    == (30, 2)
        @test size(reshape(A, 3, :))      == (3, 20)
        @test size(reshape(A, 2, 3, :))   == (2, 3, 10)
        @test size(reshape(A, (2, :, 5))) == (2, 6, 5)
        @test_throws DimensionMismatch reshape(A, 7, :)
        @test_throws DimensionMismatch reshape(A, :, 2, 3, 4)
        @test_throws DimensionMismatch reshape(A, (:, :))

        B = rand(2,2,2,2)
        @test size(reshape(B, :)) == (16,)
        @test size(reshape(B, :, 4)) == (4, 4)
        @test size(reshape(B, (2, 1, :))) == (2, 1, 8)
        @test_throws DimensionMismatch reshape(B, 3, :)
        @test_throws DimensionMismatch reshape(B, :, :, 2, 2)
    end
end

@test reshape(1:5, (5,)) === 1:5
@test reshape(1:5, 5) === 1:5

@testset "setindex! on a reshaped range" begin
    a = reshape(1:20, 5, 4)
    for idx in ((3,), (2,2), (Base.ReshapedIndex(1),))
        try
            a[idx...] = 7
            error("wrong error")
        catch err
            @test err.msg == "indexed assignment fails for a reshaped range; consider calling collect"
        end
    end
end

@testset "conversion from ReshapedArray to Array (#18262)" begin
    a = Base.ReshapedArray(1:3, (3, 1), ())
    @test convert(Array, a) == a
    @test convert(Array{Int}, a) == a
    @test convert(Array{Float64}, a) == a
    @test convert(Matrix, a) == a
    @test convert(Matrix{Int}, a) == a
    @test convert(Matrix{Float64}, a) == a
    b = Base.ReshapedArray(1:3, (3,), ())
    @test convert(Array, b) == b
    @test convert(Array{Int}, b) == b
    @test convert(Array{Float64}, b) == b
    @test convert(Vector, b) == b
    @test convert(Vector{Int}, b) == b
    @test convert(Vector{Float64}, b) == b
end

@testset "operations with IndexLinear ReshapedArray" begin
    b = collect(1:12)
    a = Base.ReshapedArray(b, (4,3), ())
    @test a[3,2] == 7
    @test a[6] == 6
    a[3,2] = -2
    a[6] = -3
    a[Base.ReshapedIndex(5)] = -4
    @test b[5] == -4
    @test b[6] == -3
    @test b[7] == -2
    b = reinterpret(Int, a, (3,4))
    b[1] = -1
    @test vec(b) == vec(a)

    a = rand(1, 1, 8, 8, 1)
    @test @inferred(squeeze(a, 1)) == @inferred(squeeze(a, (1,))) == reshape(a, (1, 8, 8, 1))
    @test @inferred(squeeze(a, (1, 5))) == squeeze(a, (5, 1)) == reshape(a, (1, 8, 8))
    @test @inferred(squeeze(a, (1, 2, 5))) == squeeze(a, (5, 2, 1)) == reshape(a, (8, 8))
    @test_throws ArgumentError squeeze(a, 0)
    @test_throws ArgumentError squeeze(a, (1, 1))
    @test_throws ArgumentError squeeze(a, (1, 2, 1))
    @test_throws ArgumentError squeeze(a, (1, 1, 2))
    @test_throws ArgumentError squeeze(a, 3)
    @test_throws ArgumentError squeeze(a, 4)
    @test_throws ArgumentError squeeze(a, 6)

    sz = (5,8,7)
    A = reshape(1:prod(sz),sz...)
    @test A[2:6] == [2:6;]
    @test A[1:3,2,2:4] == cat(2,46:48,86:88,126:128)
    @test A[:,7:-3:1,5] == [191 176 161; 192 177 162; 193 178 163; 194 179 164; 195 180 165]
    @test reshape(A, Val{2})[:,3:9] == reshape(11:45,5,7)
    rng = (2,2:3,2:2:5)
    tmp = zeros(Int,map(maximum,rng)...)
    tmp[rng...] = A[rng...]
    @test  tmp == cat(3,zeros(Int,2,3),[0 0 0; 0 47 52],zeros(Int,2,3),[0 0 0; 0 127 132])

    @test cat([1,2],1,2,3.,4.,5.) == diagm([1,2,3.,4.,5.])
    blk = [1 2;3 4]
    tmp = cat([1,3],blk,blk)
    @test tmp[1:2,1:2,1] == blk
    @test tmp[1:2,1:2,2] == zero(blk)
    @test tmp[3:4,1:2,1] == zero(blk)
    @test tmp[3:4,1:2,2] == blk

    x = rand(2,2)
    b = x[1,:]
    @test isequal(size(b), (2,))
    b = x[:,1]
    @test isequal(size(b), (2,))

    x = rand(5,5)
    b = x[2:3,2]
    @test b[1] == x[2,2] && b[2] == x[3,2]

    B = zeros(4,5)
    B[:,3] = 1:4
    @test B == [0 0 1 0 0; 0 0 2 0 0; 0 0 3 0 0; 0 0 4 0 0]
    B[2,:] = 11:15
    @test B == [0 0 1 0 0; 11 12 13 14 15; 0 0 3 0 0; 0 0 4 0 0]
    B[[3,1],[2,4]] = [21 22; 23 24]
    @test B == [0 23 1 24 0; 11 12 13 14 15; 0 21 3 22 0; 0 0 4 0 0]
    B[4,[2,3]] = 7
    @test B == [0 23 1 24 0; 11 12 13 14 15; 0 21 3 22 0; 0 7 7 0 0]

    @test isequal(reshape(reshape(1:27, 3, 3, 3), Val{2})[1,:], [1,  4,  7,  10,  13,  16,  19,  22,  25])

    a = [3, 5, -7, 6]
    b = [4, 6, 2, -7, 1]
    ind = findin(a, b)
    @test ind == [3,4]

    rt = Base.return_types(setindex!, Tuple{Array{Int32, 3}, UInt8, Vector{Int}, Int16, UnitRange{Int}})
    @test length(rt) == 1 && rt[1] == Array{Int32, 3}
end
@testset "construction" begin
    @test typeof(Vector{Int}(3)) == Vector{Int}
    @test typeof(Vector{Int}()) == Vector{Int}
    @test typeof(Vector(3)) == Vector{Any}
    @test typeof(Vector()) == Vector{Any}
    @test typeof(Matrix{Int}(2,3)) == Matrix{Int}
    @test typeof(Matrix(2,3)) == Matrix{Any}

    @test size(Vector{Int}(3)) == (3,)
    @test size(Vector{Int}()) == (0,)
    @test size(Vector(3)) == (3,)
    @test size(Vector()) == (0,)
    @test size(Matrix{Int}(2,3)) == (2,3)
    @test size(Matrix(2,3)) == (2,3)

    # TODO: will throw MethodError after 0.6 deprecations are deleted
    dw = Base.JLOptions().depwarn
    if dw == 2
        @test_throws ErrorException Matrix{Int}()
        @test_throws ErrorException Matrix()
    elseif dw == 1
        @test_warn "deprecated" Matrix{Int}()
        @test_warn "deprecated" Matrix()
    elseif dw == 0
        @test size(Matrix{Int}()) == (0,0)
        @test size(Matrix()) == (0,0)
    else
        error("unexpected depwarn value")
    end
    @test_throws MethodError Array{Int,3}()
end
@testset "get" begin
    A = reshape(1:24, 3, 8)
    x = get(A, 32, -12)
    @test x == -12
    x = get(A, 14, -12)
    @test x == 14
    x = get(A, (2,4), -12)
    @test x == 11
    x = get(A, (4,4), -12)
    @test x == -12
    X = get(A, -5:5, NaN32)
    @test eltype(X) == Float32
    @test Base.elsize(X) == sizeof(Float32)
    @test !all(isinteger, X)
    @test isnan.(X) == [trues(6);falses(5)]
    @test X[7:11] == [1:5;]
    X = get(A, (2:4, 9:-2:-13), 0)
    Xv = zeros(Int, 3, 12)
    Xv[1:2, 2:5] = A[2:3, 7:-2:1]
    @test X == Xv
    X2 = get(A, Vector{Int}[[2:4;], [9:-2:-13;]], 0)
    @test X == X2
end
@testset "arrays as dequeues" begin
    l = Any[1]
    push!(l,2,3,8)
    @test l[1]==1 && l[2]==2 && l[3]==3 && l[4]==8
    v = pop!(l)
    @test v == 8
    v = pop!(l)
    @test v == 3
    @test length(l)==2
    m = Any[]
    @test_throws ArgumentError pop!(m)
    @test_throws ArgumentError shift!(m)
    unshift!(l,4,7,5)
    @test l[1]==4 && l[2]==7 && l[3]==5 && l[4]==1 && l[5]==2
    v = shift!(l)
    @test v == 4
    @test length(l)==4

    v = [3, 7, 6]
    @test_throws BoundsError insert!(v, 0, 5)
    for i = 1:4
        vc = copy(v)
        @test insert!(vc, i, 5) === vc
        @test vc == [v[1:(i-1)]; 5; v[i:end]]
    end
    @test_throws BoundsError insert!(v, 5, 5)
end
@testset "concatenation" begin
    @test isequal([ones(2,2)  2*ones(2,1)], [1. 1 2; 1 1 2])
    @test isequal([ones(2,2); 2*ones(1,2)], [1. 1; 1 1; 2 2])
end

@testset "typed array literals" begin
    X = Float64[1 2 3]
    Y = [1. 2. 3.]
    @test size(X) == size(Y)
    for i = 1:3 @test X[i] === Y[i] end
    X = Float64[1;2;3]
    Y = [1.,2.,3.]
    @test size(X) == size(Y)
    for i = 1:3 @test X[i] === Y[i] end
    X = Float64[1 2 3; 4 5 6]
    Y = [1. 2. 3.; 4. 5. 6.]
    @test size(X) == size(Y)
    for i = 1:length(X) @test X[i] === Y[i] end

    _array_equiv(a,b) = eltype(a) == eltype(b) && a == b
    @test _array_equiv(UInt8[1:3;4], [0x1,0x2,0x3,0x4])
    @test_throws MethodError UInt8[1:3]
    @test_throws MethodError UInt8[1:3,]
    @test_throws MethodError UInt8[1:3,4:6]
    a = Array{UnitRange{Int}}(1); a[1] = 1:3
    @test _array_equiv([1:3,], a)
    a = Array{UnitRange{Int}}(2); a[1] = 1:3; a[2] = 4:6
    @test _array_equiv([1:3,4:6], a)
end

@testset "typed hvcat" begin
    X = Float64[1 2 3; 4 5 6]
    X32 = Float32[X X; X X]
    @test eltype(X32) <: Float32
    for i=[1,3], j=[1,4]
        @test X32[i:(i+1), j:(j+2)] == X
    end
end
@testset "end" begin
    X = [ i+2j for i=1:5, j=1:5 ]
    @test X[end,end] == 15
    @test X[end]     == 15  # linear index
    @test X[2,  end] == 12
    @test X[end,  2] == 9
    @test X[end-1,2] == 8
    Y = [2, 1, 4, 3]
    @test X[Y[end],1] == 5
    @test X[end,Y[end]] == 11
end
@testset "find, findfirst, findnext, findlast, findprev" begin
    a = [0,1,2,3,0,1,2,3]
    @test find(a) == [2,3,4,6,7,8]
    @test find(a.==2) == [3,7]
    @test find(isodd,a) == [2,4,6,8]
    @test findfirst(a) == 2
    @test findfirst(a.==0) == 1
    @test findfirst(a.==5) == 0
    @test findfirst([1,2,4,1,2,3,4], 3) == 6
    @test findfirst(isodd, [2,4,6,3,9,2,0]) == 4
    @test findfirst(isodd, [2,4,6,2,0]) == 0
    @test findnext(a,4) == 4
    @test findnext(a,5) == 6
    @test findnext(a,1) == 2
    @test findnext(a,1,4) == 6
    @test findnext(a,5,4) == 0
    @test findlast(a) == 8
    @test findlast(a.==0) == 5
    @test findlast(a.==5) == 0
    @test findlast([1,2,4,1,2,3,4], 3) == 6
    @test findlast(isodd, [2,4,6,3,9,2,0]) == 5
    @test findlast(isodd, [2,4,6,2,0]) == 0
    @test findprev(a,4) == 4
    @test findprev(a,5) == 4
    @test findprev(a,1) == 0
    @test findprev(a,1,4) == 2
    @test findprev(a,1,8) == 6
    @test findprev(isodd, [2,4,5,3,9,2,0], 7) == 5
    @test findprev(isodd, [2,4,5,3,9,2,0], 2) == 0
end
@testset "find with general iterables" begin
    s = "julia"
    # FIXME once 16269 is resolved
    # @test find(s) == [1,2,3,4,5]
    @test find(c -> c == 'l', s) == [3]
    g = graphemes("日本語")
    @test find(g) == [1,2,3]
    @test find(isascii, g) == Int[]
end
@testset "findn" begin
    b = findn(ones(2,2,2,2))
    @test (length(b[1]) == 16)
    @test (length(b[2]) == 16)
    @test (length(b[3]) == 16)
    @test (length(b[4]) == 16)

    #hand made case
    a = ([2,1,2],[1,2,2],[2,2,2])
    z = zeros(2,2,2)
    for i = 1:3
        z[a[1][i],a[2][i],a[3][i]] = 10
    end
    @test isequal(a,findn(z))
end

@testset "findmin findmax indmin indmax" begin
    @test indmax([10,12,9,11]) == 2
    @test indmin([10,12,9,11]) == 3
    @test findmin([NaN,3.2,1.8]) == (1.8,3)
    @test findmax([NaN,3.2,1.8]) == (3.2,2)
    @test findmin([NaN,3.2,1.8,NaN]) == (1.8,3)
    @test findmax([NaN,3.2,1.8,NaN]) == (3.2,2)
    @test findmin([3.2,1.8,NaN,2.0]) == (1.8,2)
    @test findmax([3.2,1.8,NaN,2.0]) == (3.2,1)

    #14085
    @test findmax(4:9) == (9,6)
    @test indmax(4:9) == 6
    @test findmin(4:9) == (4,1)
    @test indmin(4:9) == 1
    @test findmax(5:-2:1) == (5,1)
    @test indmax(5:-2:1) == 1
    @test findmin(5:-2:1) == (1,3)
    @test indmin(5:-2:1) == 3
end

@testset "permutedims" begin
    # keeps the num of dim
    p = randperm(5)
    q = randperm(5)
    a = rand(p...)
    b = permutedims(a,q)
    @test isequal(size(b), tuple(p[q]...))

    # hand made case
    y = zeros(1,2,3)
    for i = 1:6
        y[i]=i
    end

    z = zeros(3,1,2)
    for i = 1:3
        z[i] = i*2-1
        z[i+3] = i*2
    end

    # permutes correctly
    @test isequal(z,permutedims(y,[3,1,2]))
    @test isequal(z,permutedims(y,(3,1,2)))

    # of a subarray
    a = rand(5,5)
    s = view(a,2:3,2:3)
    p = permutedims(s, [2,1])
    @test p[1,1]==a[2,2] && p[1,2]==a[3,2]
    @test p[2,1]==a[2,3] && p[2,2]==a[3,3]

    # of a non-strided subarray
    a = reshape(1:60, 3, 4, 5)
    s = view(a,:,[1,2,4],[1,5])
    c = convert(Array, s)
    for p in ([1,2,3], [1,3,2], [2,1,3], [2,3,1], [3,1,2], [3,2,1])
        @test permutedims(s, p) == permutedims(c, p)
        @test PermutedDimsArray(s, p) == permutedims(c, p)
    end
    @test_throws ArgumentError permutedims(a, (1,1,1))
    @test_throws ArgumentError permutedims(s, (1,1,1))
    @test_throws ArgumentError PermutedDimsArray(a, (1,1,1))
    @test_throws ArgumentError PermutedDimsArray(s, (1,1,1))
    cp = PermutedDimsArray(c, (3,2,1))
    @test pointer(cp) == pointer(c)
    @test_throws ArgumentError pointer(cp, 2)
    @test strides(cp) == (9,3,1)
    ap = PermutedDimsArray(collect(a), (2,1,3))
    @test strides(ap) == (3,1,12)

    for A in [rand(1,2,3,4),rand(2,2,2,2),rand(5,6,5,6),rand(1,1,1,1)]
        perm = randperm(4)
        @test isequal(A,permutedims(permutedims(A,perm),invperm(perm)))
        @test isequal(A,permutedims(permutedims(A,invperm(perm)),perm))
    end
end

@testset "circshift" begin
    @test circshift(1:5, -1) == circshift(1:5, 4) == circshift(1:5, -6) == [2,3,4,5,1]
    @test circshift(1:5, 1) == circshift(1:5, -4) == circshift(1:5, 6)  == [5,1,2,3,4]
    a = [1:5;]
    @test_throws ArgumentError Base.circshift!(a, a, 1)
    b = copy(a)
    @test Base.circshift!(b, a, 1) == [5,1,2,3,4]
end

# unique across dim

# All rows and columns unique
A = ones(10, 10)
A[diagind(A)] = shuffle!([1:10;])
@test unique(A, 1) == A
@test unique(A, 2) == A

# 10 repeats of each row
B = A[shuffle!(repmat(1:10, 10)), :]
C = unique(B, 1)
@test sortrows(C) == sortrows(A)
@test unique(B, 2) == B
@test unique(B.', 2).' == C

# Along third dimension
D = cat(3, B, B)
@test unique(D, 1) == cat(3, C, C)
@test unique(D, 3) == cat(3, B)

# With hash collisions
struct HashCollision
    x::Float64
end
Base.hash(::HashCollision, h::UInt) = h
@test map(x->x.x, unique(map(HashCollision, B), 1)) == C

@testset "large matrices transpose" begin
    for i = 1 : 3
        a = rand(200, 300)
        @test isequal(a', permutedims(a, [2, 1]))
    end
end

@testset "repmat and repeat" begin
    local A, A1, A2, A3, v, v2, cv, cv2, c, R, T
    A = ones(Int,2,3,4)
    A1 = reshape(repmat([1,2],1,12),2,3,4)
    A2 = reshape(repmat([1 2 3],2,4),2,3,4)
    A3 = reshape(repmat([1 2 3 4],6,1),2,3,4)
    @test isequal(cumsum(A),A1)
    @test isequal(cumsum(A,1),A1)
    @test isequal(cumsum(A,2),A2)
    @test isequal(cumsum(A,3),A3)

    # issue 20112
    A3 = reshape(repmat([1 2 3 4],UInt32(6),UInt32(1)),2,3,4)
    @test isequal(cumsum(A,3),A3)
    @test repmat([1,2,3,4], UInt32(1)) == [1,2,3,4]
    @test repmat([1 2], UInt32(2)) == repmat([1 2], UInt32(2), UInt32(1))

    # issue 20564
    @test_throws MethodError repmat(1, 2, 3)
    @test_throws MethodError repmat([1, 2], 1, 2, 3)


    R = repeat([1, 2])
    @test R == [1, 2]
    R = repeat([1, 2], inner=1)
    @test R == [1, 2]
    R = repeat([1, 2], outer=1)
    @test R == [1, 2]
    R = repeat([1, 2], inner=(1,))
    @test R == [1, 2]
    R = repeat([1, 2], outer=(1,))
    @test R == [1, 2]
    R = repeat([1, 2], inner=[1])
    @test R == [1, 2]
    R = repeat([1, 2], outer=[1])
    @test R == [1, 2]
    R = repeat([1, 2], inner=1, outer=1)
    @test R == [1, 2]
    R = repeat([1, 2], inner=(1,), outer=(1,))
    @test R == [1, 2]
    R = repeat([1, 2], inner=[1], outer=[1])
    @test R == [1, 2]

    R = repeat([1, 2], inner=2)
    @test R == [1, 1, 2, 2]
    R = repeat([1, 2], outer=2)
    @test R == [1, 2, 1, 2]
    R = repeat([1, 2], inner=(2,))
    @test R == [1, 1, 2, 2]
    R = repeat([1, 2], outer=(2,))
    @test R == [1, 2, 1, 2]
    R = repeat([1, 2], inner=[2])
    @test R == [1, 1, 2, 2]
    R = repeat([1, 2], outer=[2])
    @test R == [1, 2, 1, 2]

    R = repeat([1, 2], inner=2, outer=2)
    @test R == [1, 1, 2, 2, 1, 1, 2, 2]
    R = repeat([1, 2], inner=(2,), outer=(2,))
    @test R == [1, 1, 2, 2, 1, 1, 2, 2]
    R = repeat([1, 2], inner=[2], outer=[2])
    @test R == [1, 1, 2, 2, 1, 1, 2, 2]

    R = repeat([1, 2], inner = (1, 1), outer = (1, 1))
    @test R == reshape([1, 2], (2,1))
    R = repeat([1, 2], inner = (2, 1), outer = (1, 1))
    @test R == reshape([1, 1, 2, 2], (4,1))
    R = repeat([1, 2], inner = (1, 2), outer = (1, 1))
    @test R == [1 1; 2 2]
    R = repeat([1, 2], inner = (1, 1), outer = (2, 1))
    @test R == reshape([1, 2, 1, 2], (4,1))
    R = repeat([1, 2], inner = (1, 1), outer = (1, 2))
    @test R == [1 1; 2 2]

    R = repeat([1 2;
                3 4], inner = (1, 1), outer = (1, 1))
    @test R == [1 2;
                    3 4]
    R = repeat([1 2;
                3 4], inner = (1, 1), outer = (2, 1))
    @test R == [1 2;
                    3 4;
                    1 2;
                    3 4]
    R = repeat([1 2;
                3 4], inner = (1, 1), outer = (1, 2))
    @test R == [1 2 1 2;
                    3 4 3 4]
    R = repeat([1 2;
                3 4], inner = (1, 1), outer = (2, 2))
    @test R == [1 2 1 2;
                    3 4 3 4;
                    1 2 1 2;
                    3 4 3 4]
    R = repeat([1 2;
                3 4], inner = (2, 1), outer = (1, 1))
    @test R == [1 2;
                    1 2;
                    3 4;
                    3 4]
    R = repeat([1 2;
                3 4], inner = (2, 1), outer = (2, 1))
    @test R == [1 2;
                    1 2;
                    3 4;
                    3 4;
                    1 2;
                    1 2;
                    3 4;
                    3 4]
    R = repeat([1 2;
                3 4], inner = (2, 1), outer = (1, 2))
    @test R == [1 2 1 2;
                    1 2 1 2;
                    3 4 3 4;
                    3 4 3 4;]
    R = repeat([1 2;
                3 4], inner = (2, 1), outer = (2, 2))
    @test R == [1 2 1 2;
                    1 2 1 2;
                    3 4 3 4;
                    3 4 3 4;
                    1 2 1 2;
                    1 2 1 2;
                    3 4 3 4;
                    3 4 3 4]
    R = repeat([1 2;
                3 4], inner = (1, 2), outer = (1, 1))
    @test R == [1 1 2 2;
                    3 3 4 4]
    R = repeat([1 2;
                3 4], inner = (1, 2), outer = (2, 1))
    @test R == [1 1 2 2;
                    3 3 4 4;
                    1 1 2 2;
                    3 3 4 4]
    R = repeat([1 2;
                3 4], inner = (1, 2), outer = (1, 2))
    @test R == [1 1 2 2 1 1 2 2;
                    3 3 4 4 3 3 4 4]
    R = repeat([1 2;
                3 4], inner = (1, 2), outer = (2, 2))
    @test R == [1 1 2 2 1 1 2 2;
                    3 3 4 4 3 3 4 4;
                    1 1 2 2 1 1 2 2;
                    3 3 4 4 3 3 4 4]
    R = repeat([1 2;
                3 4], inner = (2, 2), outer = [1, 1])
    @test R == [1 1 2 2;
                    1 1 2 2;
                    3 3 4 4;
                    3 3 4 4]
    R = repeat([1 2;
                3 4], inner = (2, 2), outer = (2, 1))
    @test R == [1 1 2 2;
                    1 1 2 2;
                    3 3 4 4;
                    3 3 4 4;
                    1 1 2 2;
                    1 1 2 2;
                    3 3 4 4;
                    3 3 4 4]
    R = repeat([1 2;
                3 4], inner = (2, 2), outer = (1, 2))
    @test R == [1 1 2 2 1 1 2 2;
                    1 1 2 2 1 1 2 2;
                    3 3 4 4 3 3 4 4;
                    3 3 4 4 3 3 4 4]
    R = repeat([1 2;
                3 4], inner = (2, 2), outer = (2, 2))
    @test R == [1 1 2 2 1 1 2 2;
                    1 1 2 2 1 1 2 2;
                    3 3 4 4 3 3 4 4;
                    3 3 4 4 3 3 4 4;
                    1 1 2 2 1 1 2 2;
                    1 1 2 2 1 1 2 2;
                    3 3 4 4 3 3 4 4;
                    3 3 4 4 3 3 4 4]
    @test_throws ArgumentError repeat([1 2;
                                        3 4], inner=2, outer=(2, 2))
    @test_throws ArgumentError repeat([1 2;
                                        3 4], inner=(2, 2), outer=2)
    @test_throws ArgumentError repeat([1 2;
                                        3 4], inner=(2,), outer=(2, 2))
    @test_throws ArgumentError repeat([1 2;
                                        3 4], inner=(2, 2), outer=(2,))

    A = reshape(1:8, 2, 2, 2)
    R = repeat(A, inner = (1, 1, 2), outer = (1, 1, 1))
    T = reshape([1:4; 1:4; 5:8; 5:8], 2, 2, 4)
    @test R == T
    A = Array{Int}(2, 2, 2)
    A[:, :, 1] = [1 2;
                    3 4]
    A[:, :, 2] = [5 6;
                    7 8]
    R = repeat(A, inner = (2, 2, 2), outer = (2, 2, 2))
    @test R[1, 1, 1] == 1
    @test R[2, 2, 2] == 1
    @test R[3, 3, 3] == 8
    @test R[4, 4, 4] == 8
    @test R[5, 5, 5] == 1
    @test R[6, 6, 6] == 1
    @test R[7, 7, 7] == 8
    @test R[8, 8, 8] == 8

    R = repeat(1:2)
    @test R == [1, 2]
    R = repeat(1:2, inner=1)
    @test R == [1, 2]
    R = repeat(1:2, inner=2)
    @test R == [1, 1, 2, 2]
    R = repeat(1:2, outer=1)
    @test R == [1, 2]
    R = repeat(1:2, outer=2)
    @test R == [1, 2, 1, 2]
    R = repeat(1:2, inner=(3,), outer=(2,))
    @test R == [1, 1, 1, 2, 2, 2, 1, 1, 1, 2, 2, 2]

    # Arrays of arrays
    @test repeat([[1], [2]], inner=2) == [[1], [1], [2], [2]]
    @test repeat([[1], [2]], outer=2) == [[1], [2], [1], [2]]
    @test repeat([[1], [2]], inner=2, outer=2) == [[1], [1], [2], [2], [1], [1], [2], [2]]

    @test size(repeat([1], inner=(0,))) == (0,)
    @test size(repeat([1], outer=(0,))) == (0,)
    @test size(repeat([1 1], inner=(0, 1))) == (0, 2)
    @test size(repeat([1 1], outer=(1, 0))) == (1, 0)
    @test size(repeat([1 1], inner=(2, 0), outer=(2, 1))) == (4, 0)
    @test size(repeat([1 1], inner=(2, 0), outer=(0, 1))) == (0, 0)

    A = rand(4,4)
    for s in Any[A[1:2:4, 1:2:4], view(A, 1:2:4, 1:2:4)]
        c = cumsum(s, 1)
        @test c[1,1] == A[1,1]
        @test c[2,1] == A[1,1]+A[3,1]
        @test c[1,2] == A[1,3]
        @test c[2,2] == A[1,3]+A[3,3]

        c = cumsum(s, 2)
        @test c[1,1] == A[1,1]
        @test c[2,1] == A[3,1]
        @test c[1,2] == A[1,1]+A[1,3]
        @test c[2,2] == A[3,1]+A[3,3]
    end

    v   = [1,1e100,1,-1e100]*1000
    v2  = [1,-1e100,1,1e100]*1000

    cv  = [1,1e100,1e100,2]*1000
    cv2 = [1,-1e100,-1e100,2]*1000

    @test isequal(cumsum_kbn(v), cv)
    @test isequal(cumsum_kbn(v2), cv2)

    A = [v reverse(v) v2 reverse(v2)]

    c = cumsum_kbn(A, 1)

    @test isequal(c[:,1], cv)
    @test isequal(c[:,3], cv2)
    @test isequal(c[4,:], [2.0, 2.0, 2.0, 2.0]*1000)

    c = cumsum_kbn(A, 2)

    @test isequal(c[1,:], cv2)
    @test isequal(c[3,:], cv)
    @test isequal(c[:,4], [2.0,2.0,2.0,2.0]*1000)

    @test repeat(BitMatrix(eye(2)), inner = (2,1), outer = (1,2)) == repeat(eye(2), inner = (2,1), outer = (1,2))
end

@testset "indexing with bools" begin
    @test (1:5)[[true,false,true,false,true]] == [1,3,5]
    @test [1:5;][[true,false,true,false,true]] == [1,3,5]
    @test_throws BoundsError (1:5)[[true,false,true,false]]
    @test_throws BoundsError (1:5)[[true,false,true,false,true,false]]
    @test_throws BoundsError [1:5;][[true,false,true,false]]
    @test_throws BoundsError [1:5;][[true,false,true,false,true,false]]
    a = [1:5;]
    a[[true,false,true,false,true]] = 6
    @test a == [6,2,6,4,6]
    a[[true,false,true,false,true]] = [7,8,9]
    @test a == [7,2,8,4,9]
    @test_throws DimensionMismatch (a[[true,false,true,false,true]] = [7,8,9,10])
    A = reshape(1:15, 3, 5)
    @test A[[true, false, true], [false, false, true, true, false]] == [7 10; 9 12]
    @test_throws BoundsError A[[true, false], [false, false, true, true, false]]
    @test_throws BoundsError A[[true, false, true], [false, true, true, false]]
    @test_throws BoundsError A[[true, false, true, true], [false, false, true, true, false]]
    @test_throws BoundsError A[[true, false, true], [false, false, true, true, false, true]]
    A = ones(Int, 3, 5)
    @test_throws DimensionMismatch A[2,[true, false, true, true, false]] = 2:5
    A[2,[true, false, true, true, false]] = 2:4
    @test A == [1 1 1 1 1; 2 1 3 4 1; 1 1 1 1 1]
    @test_throws DimensionMismatch A[[true,false,true], 5] = [19]
    @test_throws DimensionMismatch A[[true,false,true], 5] = 19:21
    A[[true,false,true], 5] = 7
    @test A == [1 1 1 1 7; 2 1 3 4 1; 1 1 1 1 7]

    B = cat(3, 1, 2, 3)
    @test B[:,:,[true, false, true]] == reshape([1,3], 1, 1, 2)  # issue #5454
end

# issue #2342
@test isequal(cumsum([1 2 3]), [1 2 3])

@testset "set-like operations" begin
    @test isequal(union([1,2,3], [4,3,4]), [1,2,3,4])
    @test isequal(union(['e','c','a'], ['b','a','d']), ['e','c','a','b','d'])
    @test isequal(union([1,2,3], [4,3], [5]), [1,2,3,4,5])
    @test isequal(union([1,2,3]), [1,2,3])
    @test isequal(union([1,2,3], Int64[]), Int64[1,2,3])
    @test isequal(union([1,2,3], Float64[]), Float64[1.0,2,3])
    @test isequal(union(Int64[], [1,2,3]), Int64[1,2,3])
    @test isequal(union(Int64[]), Int64[])
    @test isequal(intersect([1,2,3], [4,3,4]), [3])
    @test isequal(intersect(['e','c','a'], ['b','a','d']), ['a'])
    @test isequal(intersect([1,2,3], [3,1], [2,1,3]), [1,3])
    @test isequal(intersect([1,2,3]), [1,2,3])
    @test isequal(intersect([1,2,3], Int64[]), Int64[])
    @test isequal(intersect([1,2,3], Float64[]), Float64[])
    @test isequal(intersect(Int64[], [1,2,3]), Int64[])
    @test isequal(intersect(Int64[]), Int64[])
    @test isequal(setdiff([1,2,3,4], [2,5,4]), [1,3])
    @test isequal(setdiff([1,2,3,4], [7,8,9]), [1,2,3,4])
    @test isequal(setdiff([1,2,3,4], Int64[]), Int64[1,2,3,4])
    @test isequal(setdiff([1,2,3,4], [1,2,3,4,5]), Int64[])
    @test isequal(symdiff([1,2,3], [4,3,4]), [1,2,4])
    @test isequal(symdiff(['e','c','a'], ['b','a','d']), ['e','c','b','d'])
    @test isequal(symdiff([1,2,3], [4,3], [5]), [1,2,4,5])
    @test isequal(symdiff([1,2,3,4,5], [1,2,3], [3,4]), [3,5])
    @test isequal(symdiff([1,2,3]), [1,2,3])
    @test isequal(symdiff([1,2,3], Int64[]), Int64[1,2,3])
    @test isequal(symdiff([1,2,3], Float64[]), Float64[1.0,2,3])
    @test isequal(symdiff(Int64[], [1,2,3]), Int64[1,2,3])
    @test isequal(symdiff(Int64[]), Int64[])
end

@testset "mapslices" begin
    local a,h,i
    a = rand(5,5)
    s = mapslices(sort, a, [1])
    S = mapslices(sort, a, [2])
    for i = 1:5
        @test s[:,i] == sort(a[:,i])
        @test vec(S[i,:]) == sort(vec(a[i,:]))
    end

    # issue #3613
    b = mapslices(sum, ones(2,3,4), [1,2])
    @test size(b) === (1,1,4)
    @test all(b.==6)

    # issue #5141
    ## Update Removed the version that removes the dimensions when dims==1:ndims(A)
    c1 = mapslices(x-> maximum(-x), a, [])
    @test c1 == -a

    # other types than Number
    @test mapslices(prod,["1" "2"; "3" "4"],1) == ["13" "24"]
    @test mapslices(prod,["1"],1) == ["1"]

    # issue #5177

    c = ones(2,3,4)
    m1 = mapslices(x-> ones(2,3), c, [1,2])
    m2 = mapslices(x-> ones(2,4), c, [1,3])
    m3 = mapslices(x-> ones(3,4), c, [2,3])
    @test size(m1) == size(m2) == size(m3) == size(c)

    n1 = mapslices(x-> ones(6), c, [1,2])
    n2 = mapslices(x-> ones(6), c, [1,3])
    n3 = mapslices(x-> ones(6), c, [2,3])
    n1a = mapslices(x-> ones(1,6), c, [1,2])
    n2a = mapslices(x-> ones(1,6), c, [1,3])
    n3a = mapslices(x-> ones(1,6), c, [2,3])
    @test size(n1a) == (1,6,4) && size(n2a) == (1,3,6)  && size(n3a) == (2,1,6)
    @test size(n1) == (6,1,4) && size(n2) == (6,3,1)  && size(n3) == (2,6,1)

    # mutating functions
    o = ones(3, 4)
    m = mapslices(x->fill!(x, 0), o, 2)
    @test m == zeros(3, 4)
    @test o == ones(3, 4)

    # issue #18524
    m = mapslices(x->tuple(x), [1 2; 3 4], 1)
    @test m[1,1] == ([1,3],)
    @test m[1,2] == ([2,4],)

    # issue #21123
    @test mapslices(nnz, speye(3), 1) == [1 1 1]
end

@testset "single multidimensional index" begin
    a = rand(6,6)
    I = [1 4 5; 4 2 6; 5 6 3]
    a2 = a[I]
    @test size(a2) == size(I)
    for i = 1:length(a2)
        @test a2[i] == a[I[i]]
    end
    a = [1,3,5]
    b = [1 3]
    a[b] = 8
    @test a == [8,3,8]
end

@testset "assigning an array into itself" begin
    a = [1,3,5]
    b = [3,1,2]
    a[b] = a
    @test a == [3,5,1]
    a = [3,2,1]
    a[a] = [4,5,6]
    @test a == [6,5,4]
end

@testset "lexicographic comparison" begin
    @test lexcmp([1.0], [1]) == 0
    @test lexcmp([1], [1.0]) == 0
    @test lexcmp([1, 1], [1, 1]) == 0
    @test lexcmp([1, 1], [2, 1]) == -1
    @test lexcmp([2, 1], [1, 1]) == 1
    @test lexcmp([1, 1], [1, 2]) == -1
    @test lexcmp([1, 2], [1, 1]) == 1
    @test lexcmp([1], [1, 1]) == -1
    @test lexcmp([1, 1], [1]) == 1
end

@testset "sort on arrays" begin
    local a = rand(3,3)

    asr = sortrows(a)
    @test lexless(asr[1,:],asr[2,:])
    @test lexless(asr[2,:],asr[3,:])

    asc = sortcols(a)
    @test lexless(asc[:,1],asc[:,2])
    @test lexless(asc[:,2],asc[:,3])

    # mutating functions
    o = ones(3, 4)
    m = mapslices(x->fill!(x, 0), o, 2)
    @test m == zeros(3, 4)
    @test o == ones(3, 4)

    asr = sortrows(a, rev=true)
    @test lexless(asr[2,:],asr[1,:])
    @test lexless(asr[3,:],asr[2,:])

    asc = sortcols(a, rev=true)
    @test lexless(asc[:,2],asc[:,1])
    @test lexless(asc[:,3],asc[:,2])

    as = sort(a, 1)
    @test issorted(as[:,1])
    @test issorted(as[:,2])
    @test issorted(as[:,3])

    as = sort(a, 2)
    @test issorted(as[1,:])
    @test issorted(as[2,:])
    @test issorted(as[3,:])

    local b = rand(21,21,2)

    bs = sort(b, 1)
    for i in 1:21
        @test issorted(bs[:,i,1])
        @test issorted(bs[:,i,2])
    end

    bs = sort(b, 2)
    for i in 1:21
        @test issorted(bs[i,:,1])
        @test issorted(bs[i,:,2])
    end

    bs = sort(b, 3)
    @test all(bs[:,:,1] .<= bs[:,:,2])
end

@testset "fill" begin
    @test fill!(Array{Float64}(1),-0.0)[1] === -0.0
    A = ones(3,3)
    S = view(A, 2, 1:3)
    fill!(S, 2)
    S = view(A, 1:2, 3)
    fill!(S, 3)
    @test A == [1 1 3; 2 2 3; 1 1 1]
    rt = Base.return_types(fill!, Tuple{Array{Int32, 3}, UInt8})
    @test length(rt) == 1 && rt[1] == Array{Int32, 3}
    A = Array{Union{UInt8,Int8}}(3)
    fill!(A, UInt8(3))
    @test A == [0x03, 0x03, 0x03]
    # Issue #9964
    A = Array{Vector{Float64}}(2)
    fill!(A, [1, 2])
    @test A[1] == [1, 2]
    @test A[1] === A[2]
end

@testset "splice!" begin
    for idx in Any[1, 2, 5, 9, 10, 1:0, 2:1, 1:1, 2:2, 1:2, 2:4, 9:8, 10:9, 9:9, 10:10,
                   8:9, 9:10, 6:9, 7:10]
        for repl in Any[[], [11], [11,22], [11,22,33,44,55]]
            a = [1:10;]; acopy = copy(a)
            @test splice!(a, idx, repl) == acopy[idx]
            @test a == [acopy[1:(first(idx)-1)]; repl; acopy[(last(idx)+1):end]]
        end
    end
end

@testset "filter!" begin
    # base case w/ Vector
    a = collect(1:10)
    filter!(x -> x > 5, a)
    @test a == collect(6:10)

    # different subtype of AbstractVector
    ba = rand(10) .> 0.5
    @test isa(ba, BitArray)
    filter!(x -> x, ba)
    @test all(ba)

    # empty array
    ea = []
    filter!(x -> x > 5, ea)
    @test isempty(ea)

    # non-1-indexed array
    oa = OffsetArray(collect(1:10), -5)
    filter!(x -> x > 5, oa)
    @test oa == OffsetArray(collect(6:10), -5)

    # empty non-1-indexed array
    eoa = OffsetArray([], -5)
    filter!(x -> x > 5, eoa)
    @test isempty(eoa)
end


@testset "deleteat!" begin
    for idx in Any[1, 2, 5, 9, 10, 1:0, 2:1, 1:1, 2:2, 1:2, 2:4, 9:8, 10:9, 9:9, 10:10,
                   8:9, 9:10, 6:9, 7:10]
        # integer indexing with AbstractArray
        a = [1:10;]; acopy = copy(a)
        @test deleteat!(a, idx) == [acopy[1:(first(idx)-1)]; acopy[(last(idx)+1):end]]

        # integer indexing with non-AbstractArray iterable
        a = [1:10;]; acopy = copy(a)
        @test deleteat!(a, (i for i in idx)) == [acopy[1:(first(idx)-1)]; acopy[(last(idx)+1):end]]

        # logical indexing
        a = [1:10;]; acopy = copy(a)
        @test deleteat!(a, map(i -> i in idx, 1:length(a))) == [acopy[1:(first(idx)-1)]; acopy[(last(idx)+1):end]]
    end
    a = [1:10;]
    @test deleteat!(a, 11:10) == [1:10;]
    @test deleteat!(a, [1,3,5,7:10...]) == [2,4,6]
    @test_throws BoundsError deleteat!(a, 13)
    @test_throws BoundsError deleteat!(a, [1,13])
    @test_throws ArgumentError deleteat!(a, [5,3])
    @test_throws BoundsError deleteat!(a, 5:20)
    @test_throws BoundsError deleteat!(a, Bool[])
    @test_throws BoundsError deleteat!(a, [true])
    @test_throws BoundsError deleteat!(a, falses(11))
end

@testset "comprehensions" begin
    X = [ i+2j for i=1:5, j=1:5 ]
    @test X[2,3] == 8
    @test X[4,5] == 14
    @test isequal(ones(2,3) * ones(2,3)', [3. 3.; 3. 3.])
    # @test isequal([ [1,2] for i=1:2, : ], [1 2; 1 2])
    # where element type is a Union. try to confuse type inference.
    foo32_64(x) = (x<2) ? Int32(x) : Int64(x)
    boo32_64() = [ foo32_64(i) for i=1:2 ]
    let a36 = boo32_64()
        @test a36[1]==1 && a36[2]==2
    end
    @test isequal([1,2,3], [a for (a,b) in enumerate(2:4)])
    @test isequal([2,3,4], [b for (a,b) in enumerate(2:4)])

    @testset "comprehension in let-bound function" begin
        let x⊙y = sum([x[i]*y[i] for i=1:length(x)])
            @test [1,2] ⊙ [3,4] == 11
        end

        @test_throws DomainError (10.^[-1])[1] == 0.1
        @test (10.^[-1.])[1] == 0.1
    end
end

# issue #24002
module I24002
s1() = 1
y = Int[i for i in 1:10]
end
@test I24002.y == [1:10;]
@test I24002.s1() == 1

@testset "eachindexvalue" begin
    A14 = [11 13; 12 14]
    R = CartesianRange(indices(A14))
    @test [a for (a,b) in enumerate(IndexLinear(),    A14)] == [1,2,3,4]
    @test [a for (a,b) in enumerate(IndexCartesian(), A14)] == vec(collect(R))
    @test [b for (a,b) in enumerate(IndexLinear(),    A14)] == [11,12,13,14]
    @test [b for (a,b) in enumerate(IndexCartesian(), A14)] == [11,12,13,14]
end

@testset "reverse" begin
    @test reverse([2,3,1]) == [1,3,2]
    @test reverse([1:10;],1,4) == [4,3,2,1,5,6,7,8,9,10]
    @test reverse([1:10;],3,6) == [1,2,6,5,4,3,7,8,9,10]
    @test reverse([1:10;],6,10) == [1,2,3,4,5,10,9,8,7,6]
    @test reverse(1:10,1,4) == [4,3,2,1,5,6,7,8,9,10]
    @test reverse(1:10,3,6) == [1,2,6,5,4,3,7,8,9,10]
    @test reverse(1:10,6,10) == [1,2,3,4,5,10,9,8,7,6]
    @test reverse!([1:10;]) == [10,9,8,7,6,5,4,3,2,1]
    @test reverse!([1:10;],1,4) == [4,3,2,1,5,6,7,8,9,10]
    @test reverse!([1:10;],3,6) == [1,2,6,5,4,3,7,8,9,10]
    @test reverse!([1:10;],6,10) == [1,2,3,4,5,10,9,8,7,6]
    @test reverse!([1:10;], 11) == [1:10;]
    @test_throws BoundsError reverse!([1:10;], 1, 11)
    @test reverse!(Any[]) == Any[]
end

@testset "flipdim" begin
    @test isequal(flipdim([2,3,1], 1), [1,3,2])
    @test_throws ArgumentError flipdim([2,3,1], 2)
    @test isequal(flipdim([2 3 1], 1), [2 3 1])
    @test isequal(flipdim([2 3 1], 2), [1 3 2])
    @test_throws ArgumentError flipdim([2,3,1], -1)
    @test isequal(flipdim(1:10, 1), 10:-1:1)
    @test_throws ArgumentError flipdim(1:10, 2)
    @test_throws ArgumentError flipdim(1:10, -1)
    @test isequal(flipdim(Array{Int}(0,0),1), Array{Int}(0,0))  # issue #5872

    a = rand(5,3)
    @test flipdim(flipdim(a,2),2) == a
    @test_throws ArgumentError flipdim(a,3)
end

@testset "isdiag, istril, istriu" begin
    @test isdiag(3)
    @test istril(4)
    @test istriu(5)
    @test !isdiag([1 2; 3 4])
    @test !istril([1 2; 3 4])
    @test !istriu([1 2; 3 4])
    @test isdiag([1 0; 0 4])
    @test istril([1 0; 3 4])
    @test istriu([1 2; 0 4])
end

# issue 4228
A = [[i i; i i] for i=1:2]
@test cumsum(A) == Any[[1 1; 1 1], [3 3; 3 3]]
@test cumprod(A) == Any[[1 1; 1 1], [4 4; 4 4]]

@testset "prepend/append" begin
    # PR #4627
    A = [1,2]
    @test append!(A, A) == [1,2,1,2]
    @test prepend!(A, A) == [1,2,1,2,1,2,1,2]

    # iterators with length:
    @test append!([1,2], (9,8)) == [1,2,9,8] == push!([1,2], (9,8)...)
    @test prepend!([1,2], (9,8)) == [9,8,1,2] == unshift!([1,2], (9,8)...)
    @test append!([1,2], ()) == [1,2] == prepend!([1,2], ())
    # iterators without length:
    g = (i for i = 1:10 if iseven(i))
    @test append!([1,2], g) == [1,2,2,4,6,8,10] == push!([1,2], g...)
    @test prepend!([1,2], g) == [2,4,6,8,10,1,2] == unshift!([1,2], g...)
    g = (i for i = 1:2:10 if iseven(i)) # isempty(g) == true
    @test append!([1,2], g) == [1,2] == push!([1,2], g...)
    @test prepend!([1,2], g) == [1,2] == unshift!([1,2], g...)

    # offset array
    @test append!([1,2], OffsetArray([9,8], (-3,))) == [1,2,9,8]
    @test prepend!([1,2], OffsetArray([9,8], (-3,))) == [9,8,1,2]
end

A = [1,2]
s = Set([1,2,3])
@test sort(append!(A, s)) == [1,1,2,2,3]

@testset "cases where shared arrays can/can't be grown" begin
    A = [1 3;2 4]
    B = reshape(A, 4)
    @test push!(B,5) == [1,2,3,4,5]
    @test pop!(B) == 5
    C = reshape(B, 1, 4)
    @test_throws MethodError push!(C, 5)

    A = [NaN]; B = [NaN]
    @test !(A==A)
    @test isequal(A,A)
    @test A===A
    @test !(A==B)
    @test isequal(A,B)
    @test A!==B
end
# complete testsuite for reducedim

# Inferred types
Nmax = 3 # TODO: go up to CARTESIAN_DIMS+2 (currently this exposes problems)
for N = 1:Nmax
    #indexing with (UnitRange, UnitRange, UnitRange)
    args = ntuple(d->UnitRange{Int}, N)
    @test Base.return_types(getindex, Tuple{Array{Float32, N}, args...}) == [Array{Float32, N}]
    @test Base.return_types(getindex, Tuple{BitArray{N}, args...}) == Any[BitArray{N}]
    @test Base.return_types(setindex!, Tuple{Array{Float32, N}, Array{Int, 1}, args...}) == [Array{Float32, N}]
    # Indexing with (UnitRange, UnitRange, Int)
    args = ntuple(d->d<N ? UnitRange{Int} : Int, N)
    N > 1 && @test Base.return_types(getindex, Tuple{Array{Float32, N}, args...}) == [Array{Float32, N-1}]
    N > 1 && @test Base.return_types(getindex, Tuple{BitArray{N}, args...}) == [BitArray{N-1}]
    N > 1 && @test Base.return_types(setindex!, Tuple{Array{Float32, N}, Array{Int, 1}, args...}) == [Array{Float32, N}]
end

# issue #6645 (32-bit)
let x = Float64[]
    for i=1:5; push!(x, 1.0); end
    @test dot(zeros(5),x) == 0.0
end

# issue #6977
@test size([]') == (1,0)

# issue #6996
@test Any[ 1 2; 3 4 ]' == Any[ 1 2; 3 4 ].'

# map with promotion (issue #6541)
@test map(join, ["z", "я"]) == ["z", "я"]

# Handle block matrices
A = [randn(2,2) for i = 1:2, j = 1:2]
@test issymmetric(A.'A)
A = [complex.(randn(2,2), randn(2,2)) for i = 1:2, j = 1:2]
@test ishermitian(A'A)

# issue #7197
function i7197()
    S = [1 2 3; 4 5 6; 7 8 9]
    ind2sub(size(S), 5)
end
@test i7197() == (2,2)

# PR #8622 and general indexin test
function pr8622()
    x=[1,3,5,7]
    y=[5,4,3]
    return indexin(x,y)
end
@test pr8622() == [0,3,1,0]

#6828 - size of specific dimensions
let a = Array{Float64}(10)
    @test size(a) == (10,)
    @test size(a, 1) == 10
    @test size(a,2,1) == (1,10)
    aa = Array{Float64}(2,3)
    @test size(aa) == (2,3)
    @test size(aa,4,3,2,1) == (1,1,3,2)
    @test size(aa,1,2) == (2,3)
    aaa = Array{Float64}(9,8,7,6,5,4,3,2,1)
    @test size(aaa,1,1) == (9,9)
    @test size(aaa,4) == 6
    @test size(aaa,9,8,7,6,5,4,3,2,19,8,7,6,5,4,3,2,1) == (1,2,3,4,5,6,7,8,1,2,3,4,5,6,7,8,9)

    #18459 Test Array{T, N} constructor
    b = Array{Float64, 1}(10)
    @test size(a) == size(b)
    bb = Array{Float64, 2}(2,3)
    @test size(aa) == size(bb)
    bbb = Array{Float64, 9}(9,8,7,6,5,4,3,2,1)
    @test size(aaa) == size(bbb)
end

# Cartesian
function cartesian_foo()
    Base.@nexprs 2 d->(a_d_d = d)
    a_2_2
end
@test cartesian_foo() == 2

@testset "Multidimensional iterators" begin
    for a in ([1:5;], reshape([2]))
        counter = 0
        for I in eachindex(a)
            counter += 1
        end
        @test counter == length(a)
        counter = 0
        for aa in a
            counter += 1
        end
        @test counter == length(a)
    end
end

function mdsum(A)
    s = 0.0
    for a in A
        s += a
    end
    s
end

function mdsum2(A)
    s = 0.0
    @inbounds for I in eachindex(A)
        s += A[I]
    end
    s
end

@testset "linear indexing" begin
    a = [1:5;]
    @test isa(Base.IndexStyle(a), Base.IndexLinear)
    b = view(a, :)
    @test isa(Base.IndexStyle(b), Base.IndexLinear)
    @test isa(Base.IndexStyle(trues(2)), Base.IndexLinear)
    @test isa(Base.IndexStyle(BitArray{2}), Base.IndexLinear)
    aa = fill(99, 10)
    aa[1:2:9] = a
    shp = [5]
    for i = 1:10
        A = reshape(a, tuple(shp...))
        @test mdsum(A) == 15
        @test mdsum2(A) == 15
        AA = reshape(aa, tuple(2, shp...))
        B = view(AA, 1:1, ntuple(i->Colon(), i)...)
        @test isa(Base.IndexStyle(B), Base.IteratorsMD.IndexCartesian)
        @test mdsum(B) == 15
        @test mdsum2(B) == 15
        unshift!(shp, 1)
    end

    a = [1:10;]
    shp = [2,5]
    for i = 2:10
        A = reshape(a, tuple(shp...))
        @test mdsum(A) == 55
        @test mdsum2(A) == 55
        B = view(A, ntuple(i->Colon(), i)...)
        @test mdsum(B) == 55
        @test mdsum2(B) == 55
        insert!(shp, 2, 1)
    end

    a = reshape([2])
    @test mdsum(a) == 2
    @test mdsum2(a) == 2

    a = ones(0,5)
    b = view(a, :, :)
    @test mdsum(b) == 0
    a = ones(5,0)
    b = view(a, :, :)
    @test mdsum(b) == 0
end
@testset "CartesianIndex" begin
    for a in (copy(reshape(1:60, 3, 4, 5)),
              view(copy(reshape(1:60, 3, 4, 5)), 1:3, :, :),
              view(copy(reshape(1:60, 3, 4, 5)), CartesianIndex.(1:3, (1:4)'), :),
              view(copy(reshape(1:60, 3, 4, 5)), :, CartesianIndex.(1:4, (1:5)')))
        @test a[CartesianIndex{3}(2,3,4)] == 44
        a[CartesianIndex{3}(2,3,3)] = -1
        @test a[CartesianIndex{3}(2,3,3)] == -1
        @test a[2,CartesianIndex{2}(3,4)] == 44
        a[1,CartesianIndex{2}(3,4)] = -2
        @test a[1,CartesianIndex{2}(3,4)] == -2
        @test a[CartesianIndex{1}(2),3,CartesianIndex{1}(4)] == 44
        a[CartesianIndex{1}(2),3,CartesianIndex{1}(3)] = -3
        @test a[CartesianIndex{1}(2),3,CartesianIndex{1}(3)] == -3

        @test a[:, :, CartesianIndex((1,))] == (@view a[:, :, CartesianIndex((1,))]) == a[:,:,1]
        @test a[CartesianIndex((1,)), [1,2], :] == (@view a[CartesianIndex((1,)), [1,2], :]) == a[1,[1,2],:]
        @test a[CartesianIndex((2,)), 3:4, :] == (@view a[CartesianIndex((2,)), 3:4, :]) == a[2,3:4,:]
        @test a[[CartesianIndex(1,3),CartesianIndex(2,4)],3:3] ==
              (@view a[[CartesianIndex(1,3),CartesianIndex(2,4)],3:3]) == reshape([a[1,3,3]; a[2,4,3]], 2, 1)

        @test a[[CartesianIndex()], :, :, :] == (@view a[[CartesianIndex()], :, :, :]) == reshape(a, 1, 3, 4, 5)
        @test a[:, [CartesianIndex()], :, :] == (@view a[:, [CartesianIndex()], :, :]) == reshape(a, 3, 1, 4, 5)
        @test a[:, :, [CartesianIndex()], :] == (@view a[:, :, [CartesianIndex()], :]) == reshape(a, 3, 4, 1, 5)
        @test a[:, :, :, [CartesianIndex()]] == (@view a[:, :, :, [CartesianIndex()]]) == reshape(a, 3, 4, 5, 1)
        a2 = reshape(a, Val{2})
        @test a2[[CartesianIndex()], :, :]   == (@view a2[[CartesianIndex()], :, :])   == reshape(a, 1, 3, 20)
        @test a2[:, [CartesianIndex()], :]   == (@view a2[:, [CartesianIndex()], :])   == reshape(a, 3, 1, 20)
        @test a2[:, :, [CartesianIndex()]]   == (@view a2[:, :, [CartesianIndex()]])   == reshape(a, 3, 20, 1)
        a1 = reshape(a, Val{1})
        @test a1[[CartesianIndex()], :]      == (@view a1[[CartesianIndex()], :])      == reshape(a, 1, 60)
        @test a1[:, [CartesianIndex()]]      == (@view a1[:, [CartesianIndex()]])      == reshape(a, 60, 1)

        @test_throws BoundsError a[[CartesianIndex(1,5),CartesianIndex(2,4)],3:3]
        @test_throws BoundsError a[1:4, [CartesianIndex(1,3),CartesianIndex(2,4)]]
        @test_throws BoundsError @view a[[CartesianIndex(1,5),CartesianIndex(2,4)],3:3]
        @test_throws BoundsError @view a[1:4, [CartesianIndex(1,3),CartesianIndex(2,4)]]
    end

    for a in (view(zeros(3, 4, 5), :, :, :),
              view(zeros(3, 4, 5), 1:3, :, :))
        a[CartesianIndex{3}(2,3,3)] = -1
        @test a[CartesianIndex{3}(2,3,3)] == -1
        a[1,CartesianIndex{2}(3,4)] = -2
        @test a[1,CartesianIndex{2}(3,4)] == -2
        a[CartesianIndex{1}(2),3,CartesianIndex{1}(3)] = -3
        @test a[CartesianIndex{1}(2),3,CartesianIndex{1}(3)] == -3
        a[[CartesianIndex(1,3),CartesianIndex(2,4)],3:3] = -4
        @test a[1,3,3] == -4
        @test a[2,4,3] == -4
    end

    I1 = CartesianIndex((2,3,0))
    I2 = CartesianIndex((-1,5,2))
    @test -I1 == CartesianIndex((-2,-3,0))
    @test I1 + I2 == CartesianIndex((1,8,2))
    @test I2 + I1 == CartesianIndex((1,8,2))
    @test I1 - I2 == CartesianIndex((3,-2,-2))
    @test I2 - I1 == CartesianIndex((-3,2,2))
    @test I1 + 1 == CartesianIndex((3,4,1))
    @test I1 - 2 == CartesianIndex((0,1,-2))

    @test zero(CartesianIndex{2}) == CartesianIndex((0,0))
    @test zero(CartesianIndex((2,3))) == CartesianIndex((0,0))
    @test one(CartesianIndex{2}) == CartesianIndex((1,1))
    @test one(CartesianIndex((2,3))) == CartesianIndex((1,1))

    @test min(CartesianIndex((2,3)), CartesianIndex((5,2))) == CartesianIndex((2,2))
    @test max(CartesianIndex((2,3)), CartesianIndex((5,2))) == CartesianIndex((5,3))

    # CartesianIndex allows construction at a particular dimensionality
    @test length(CartesianIndex{3}()) == 3
    @test length(CartesianIndex{3}(1,2)) == 3
    @test length(CartesianIndex{3}((1,2))) == 3
    @test length(CartesianIndex{3}(1,2,3)) == 3
    @test length(CartesianIndex{3}((1,2,3))) == 3
    @test_throws ArgumentError CartesianIndex{3}(1,2,3,4)
    @test_throws ArgumentError CartesianIndex{3}((1,2,3,4))

    @test length(I1) == 3

    @test isless(CartesianIndex((1,1)), CartesianIndex((2,1)))
    @test isless(CartesianIndex((1,1)), CartesianIndex((1,2)))
    @test isless(CartesianIndex((2,1)), CartesianIndex((1,2)))
    @test !isless(CartesianIndex((1,2)), CartesianIndex((2,1)))

    a = spzeros(2,3)
    @test CartesianRange(size(a)) == eachindex(a)
    a[CartesianIndex{2}(2,3)] = 5
    @test a[2,3] == 5
    b = view(a, 1:2, 2:3)
    b[CartesianIndex{2}(1,1)] = 7
    @test a[1,2] == 7
    @test 2*CartesianIndex{3}(1,2,3) == CartesianIndex{3}(2,4,6)

    R = CartesianRange(CartesianIndex{2}(2,3),CartesianIndex{2}(5,5))
    @test eltype(R) <: CartesianIndex{2}
    @test eltype(typeof(R)) <: CartesianIndex{2}
    indexes = collect(R)
    @test indexes[1] == CartesianIndex{2}(2,3)
    @test indexes[2] == CartesianIndex{2}(3,3)
    @test indexes[4] == CartesianIndex{2}(5,3)
    @test indexes[5] == CartesianIndex{2}(2,4)
    @test indexes[12] == CartesianIndex{2}(5,5)
    @test length(indexes) == 12
    @test length(R) == 12
    @test ndims(R) == 2
    @test in(CartesianIndex((2,3)), R)
    @test in(CartesianIndex((3,3)), R)
    @test in(CartesianIndex((3,5)), R)
    @test in(CartesianIndex((5,5)), R)
    @test !in(CartesianIndex((1,3)), R)
    @test !in(CartesianIndex((3,2)), R)
    @test !in(CartesianIndex((3,6)), R)
    @test !in(CartesianIndex((6,5)), R)

    @test @inferred(convert(NTuple{2,UnitRange}, R)) === (2:5, 3:5)
    @test @inferred(convert(Tuple{Vararg{UnitRange}}, R)) === (2:5, 3:5)

    @test CartesianRange((3:5,-7:7)) == CartesianRange(CartesianIndex{2}(3,-7),CartesianIndex{2}(5,7))
    @test CartesianRange((3,-7:7)) == CartesianRange(CartesianIndex{2}(3,-7),CartesianIndex{2}(3,7))
end

# All we really care about is that we have an optimized
# implementation, but the seed is a useful way to check that.
@test hash(CartesianIndex()) == Base.IteratorsMD.cartindexhash_seed
@test hash(CartesianIndex(1, 2)) != hash((1, 2))

@testset "itr, start, done, next" begin
    r = 2:3
    itr = eachindex(r)
    state = start(itr)
    @test !done(itr, state)
    _, state = next(itr, state)
    @test !done(itr, state)
    val, state = next(itr, state)
    @test done(itr, state)
    @test r[val] == 3
    r = sparse(collect(2:3:8))
    itr = eachindex(r)
    state = start(itr)
    @test !done(itr, state)
    _, state = next(itr, state)
    _, state = next(itr, state)
    @test !done(itr, state)
    val, state = next(itr, state)
    @test r[val] == 8
    @test done(itr, state)
end

R = CartesianRange((1,3))
@test done(R, start(R)) == false
R = CartesianRange((0,3))
@test done(R, start(R)) == true
R = CartesianRange((3,0))
@test done(R, start(R)) == true

@test @inferred(eachindex(Base.IndexCartesian(),zeros(3),zeros(2,2),zeros(2,2,2),zeros(2,2))) == CartesianRange((3,2,2))
@test @inferred(eachindex(Base.IndexLinear(),zeros(3),zeros(2,2),zeros(2,2,2),zeros(2,2))) == 1:8
@test @inferred(eachindex(zeros(3),view(zeros(3,3),1:2,1:2),zeros(2,2,2),zeros(2,2))) == CartesianRange((3,2,2))
@test @inferred(eachindex(zeros(3),zeros(2,2),zeros(2,2,2),zeros(2,2))) == 1:8


@testset "rotates" begin
    a = [1 0 0; 0 0 0]
    @test rotr90(a,1) == [0 1; 0 0; 0 0]
    @test rotr90(a,2) == rot180(a,1)
    @test rotr90(a,3) == rotl90(a,1)
    @test rotl90(a,3) == rotr90(a,1)
    @test rotl90(a,1) == rotr90(a,3)
    @test rotl90(a,4) == a
    @test rotr90(a,4) == a
    @test rot180(a,2) == a
end

# issue #9648
let x = fill(1.5f0, 10^7)
    @test abs(1.5f7 - cumsum(x)[end]) < 3*eps(1.5f7)
    @test cumsum(x) == cumsum!(similar(x), x)
end

# PR #10164
@test eltype(Array{Int}) == Int
@test eltype(Array{Int,1}) == Int

# PR #11080
let x = fill(0.9, 1000)
    @test prod(x) ≈ cumprod(x)[end]
end

@testset "binary ops on bool arrays" begin
    A = Array(trues(5))
    @test A + true == [2,2,2,2,2]
    A = Array(trues(5))
    @test A + false == [1,1,1,1,1]
    A = Array(trues(5))
    @test true + A == [2,2,2,2,2]
    A = Array(trues(5))
    @test false + A == [1,1,1,1,1]
    A = Array(trues(5))
    @test A - true == [0,0,0,0,0]
    A = Array(trues(5))
    @test A - false == [1,1,1,1,1]
    A = Array(trues(5))
    @test true - A == [0,0,0,0,0]
    A = Array(trues(5))
    @test false - A == [-1,-1,-1,-1,-1]
end

@testset "simple transposes" begin
    a = ones(Complex,1,5)
    b = zeros(Complex,5)
    c = ones(Complex,2,5)
    d = ones(Complex,6)
    @test_throws DimensionMismatch transpose!(a,d)
    @test_throws DimensionMismatch transpose!(d,a)
    @test_throws DimensionMismatch ctranspose!(a,d)
    @test_throws DimensionMismatch ctranspose!(d,a)
    @test_throws DimensionMismatch transpose!(b,c)
    @test_throws DimensionMismatch ctranspose!(b,c)
    @test_throws DimensionMismatch transpose!(c,b)
    @test_throws DimensionMismatch ctranspose!(c,b)
    transpose!(b,a)
    @test b == ones(Complex,5)
    b = ones(Complex,5)
    a = zeros(Complex,1,5)
    transpose!(a,b)
    @test a == ones(Complex,1,5)
    b = zeros(Complex,5)
    ctranspose!(b,a)
    @test b == ones(Complex,5)
    a = zeros(Complex,1,5)
    ctranspose!(a,b)
    @test a == ones(Complex,1,5)
end

@testset "bounds checking for copy!" begin
    a = rand(5,3)
    b = rand(6,7)
    @test_throws BoundsError copy!(a,b)
    @test_throws ArgumentError copy!(a,2:3,1:3,b,1:5,2:7)
    @test_throws ArgumentError Base.copy_transpose!(a,2:3,1:3,b,1:5,2:7)
end

module RetTypeDecl
    using Base.Test
    import Base: +, *, broadcast, convert

    struct MeterUnits{T,P} <: Number
        val::T
    end
    MeterUnits{T}(val::T, pow::Int) = MeterUnits{T,pow}(val)

    m  = MeterUnits(1.0, 1)   # 1.0 meter, i.e. units of length
    m2 = MeterUnits(1.0, 2)   # 1.0 meter^2, i.e. units of area

    (+){T,pow}(x::MeterUnits{T,pow}, y::MeterUnits{T,pow}) = MeterUnits{T,pow}(x.val+y.val)
    (*){T,pow}(x::Int, y::MeterUnits{T,pow}) = MeterUnits{typeof(x*one(T)),pow}(x*y.val)
    (*){T}(x::MeterUnits{T,1}, y::MeterUnits{T,1}) = MeterUnits{T,2}(x.val*y.val)
    broadcast{T}(::typeof(*), x::MeterUnits{T,1}, y::MeterUnits{T,1}) = MeterUnits{T,2}(x.val*y.val)
    convert{T,pow}(::Type{MeterUnits{T,pow}}, y::Real) = MeterUnits{T,pow}(convert(T,y))

    @test @inferred(m+[m,m]) == [m+m,m+m]
    @test @inferred([m,m]+m) == [m+m,m+m]
    @test @inferred(broadcast(*,m,[m,m])) == [m2,m2]
    @test @inferred(broadcast(*,[m,m],m)) == [m2,m2]
    @test @inferred([m 2m; m m]*[m,m]) == [3m2,2m2]
    @test @inferred(broadcast(*,[m m],[m,m])) == [m2 m2; m2 m2]
end

# range, range ops
A = 1:5
B = 1.5:5.5
@test A + B == 2.5:2.0:10.5

@testset "slicedim" begin
    for A in (reshape(collect(1:20), 4, 5),
              reshape(1:20, 4, 5))
        @test slicedim(A, 1, 2) == collect(2:4:20)
        @test slicedim(A, 2, 2) == collect(5:8)
        @test_throws ArgumentError slicedim(A,0,1)
        @test slicedim(A, 3, 1) == A
        @test_throws BoundsError slicedim(A, 3, 2)
        @test @inferred(slicedim(A, 1, 2:2)) == collect(2:4:20)'
    end
end

###
### IndexCartesian workout
###
struct LinSlowMatrix{T} <: DenseArray{T,2}
    data::Matrix{T}
end

# This is the default, but just to be sure
Base.IndexStyle{A<:LinSlowMatrix}(::Type{A}) = Base.IndexCartesian()

Base.size(A::LinSlowMatrix) = size(A.data)

Base.getindex(A::LinSlowMatrix, i::Integer) = error("Not defined")
Base.getindex(A::LinSlowMatrix, i::Integer, j::Integer) = A.data[i,j]

Base.setindex!(A::LinSlowMatrix, v, i::Integer) = error("Not defined")
Base.setindex!(A::LinSlowMatrix, v, i::Integer, j::Integer) = A.data[i,j] = v

A = rand(3,5)
B = LinSlowMatrix(A)
S = view(A, :, :)

@test A == B
@test B == A
@test isequal(A, B)
@test isequal(B, A)

for (a,b) in zip(A, B)
    @test a == b
end
for (a,s) in zip(A, S)
    @test a == s
end

C = copy(B)
@test A == C
@test B == C

@test vec(A) == vec(B) == vec(S)
@test minimum(A) == minimum(B) == minimum(S)
@test maximum(A) == maximum(B) == maximum(S)

a, ai = findmin(A)
b, bi = findmin(B)
s, si = findmin(S)
@test a == b == s
@test ai == bi == si

a, ai = findmax(A)
b, bi = findmax(B)
s, si = findmax(S)
@test a == b == s
@test ai == bi == si

fill!(B, 2)
@test all(x->x==2, B)

iall = (1:size(A,1)).*ones(Int,size(A,2))'
jall = ones(Int,size(A,1)).*(1:size(A,2))'
i,j = findn(B)
@test vec(i) == vec(iall)
@test vec(j) == vec(jall)
fill!(S, 2)
i,j = findn(S)
@test vec(i) == vec(iall)
@test vec(j) == vec(jall)

copy!(B, A)
copy!(S, A)

@test cat(1, A, B, S) == cat(1, A, A, A)
@test cat(2, A, B, S) == cat(2, A, A, A)

@test cumsum(A, 1) == cumsum(B, 1) == cumsum(S, 1)
@test cumsum(A, 2) == cumsum(B, 2) == cumsum(S, 2)

@test mapslices(sort, A, 1) == mapslices(sort, B, 1) == mapslices(sort, S, 1)
@test mapslices(sort, A, 2) == mapslices(sort, B, 2) == mapslices(sort, S, 2)

@test flipdim(A, 1) == flipdim(B, 1) == flipdim(S, 2)
@test flipdim(A, 2) == flipdim(B, 2) == flipdim(S, 2)

@test A + 1 == B + 1 == S + 1
@test 2*A == 2*B == 2*S
@test A/3 == B/3 == S/3

# issue #13250
x13250 = zeros(3)
x13250[UInt(1):UInt(2)] = 1.0
@test x13250[1] == 1.0
@test x13250[2] == 1.0
@test x13250[3] == 0.0

struct SquaresVector <: AbstractArray{Int, 1}
    count::Int
end
Base.size(S::SquaresVector) = (S.count,)
Base.IndexStyle(::Type{SquaresVector}) = Base.IndexLinear()
Base.getindex(S::SquaresVector, i::Int) = i*i
foo_squares = SquaresVector(5)
@test convert(Array{Int}, foo_squares) == [1,4,9,16,25]
@test convert(Array{Int, 1}, foo_squares) == [1,4,9,16,25]

# issue #13254
let A = zeros(Int, 2, 2), B = zeros(Float64, 2, 2)
    f1() = [1]
    f2() = [1;]
    f3() = [1;2]
    f4() = [1;2.0]
    f5() = [1 2]
    f6() = [1 2.0]
    f7() = Int[1]
    f8() = Float64[1]
    f9() = Int[1;]
    f10() = Float64[1;]
    f11() = Int[1;2]
    f12() = Float64[1;2]
    f13() = Int[1;2.0]
    f14() = Int[1 2]
    f15() = Float64[1 2]
    f16() = Int[1 2.0]
    f17() = [1:2;]
    f18() = Int[1:2;]
    f19() = Float64[1:2;]
    f20() = [1:2;1:2]
    f21() = Int[1:2;1:2]
    f22() = Float64[1:2;1:2]
    f23() = [1:2;1.0:2.0]
    f24() = Int[1:2;1.0:2.0]
    f25() = [1:2 1:2]
    f26() = Int[1:2 1:2]
    f27() = Float64[1:2 1:2]
    f28() = [1:2 1.0:2.0]
    f29() = Int[1:2 1.0:2.0]
    f30() = [A;]
    f31() = Int[A;]
    f32() = Float64[A;]
    f33() = [A;A]
    f34() = Int[A;A]
    f35() = Float64[A;A]
    f36() = [A;B]
    f37() = Int[A;B]
    f38() = [A A]
    f39() = Int[A A]
    f40() = Float64[A A]
    f41() = [A B]
    f42() = Int[A B]

    for f in [f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14, f15, f16,
              f17, f18, f19, f20, f21, f22, f23, f24, f25, f26, f27, f28, f29, f30,
              f31, f32, f33, f34, f35, f36, f37, f38, f39, f40, f41, f42]
        @test isleaftype(Base.return_types(f, ())[1])
    end
end

# issue #14482
@inferred map(Int8, Int[0])

# make sure @inbounds isn't used too much
mutable struct OOB_Functor{T}; a::T; end
(f::OOB_Functor)(i::Int) = f.a[i]
let f = OOB_Functor([1,2])
    @test_throws BoundsError map(f, [1,2,3,4,5])
end


# issue 15654
@test cumprod([5], 2) == [5]
@test cumprod([1 2; 3 4], 3) == [1 2; 3 4]
@test cumprod([1 2; 3 4], 1) == [1 2; 3 8]
@test cumprod([1 2; 3 4], 2) == [1 2; 3 12]

@test cumsum([5], 2) == [5]
@test cumsum([1 2; 3 4], 1) == [1 2; 4 6]
@test cumsum([1 2; 3 4], 2) == [1 3; 3 7]
@test cumsum([1 2; 3 4], 3) == [1 2; 3 4]

# issue #18363
@test_throws DimensionMismatch cumsum!([0,0], 1:4)
@test cumsum(Any[])::Vector{Any} == Any[]
@test cumsum(Any[1, 2.3])::Vector{Any} == [1, 3.3] == cumsum(Real[1, 2.3])::Vector{Real}
@test cumsum([true,true,true]) == [1,2,3]
@test cumsum(0x00:0xff)[end] === 0x80 # overflow
@test cumsum([[true], [true], [false]])::Vector{Vector{Int}} == [[1], [2], [2]]

#issue #18336
@test cumsum([-0.0, -0.0])[1] === cumsum([-0.0, -0.0])[2] === -0.0
@test cumprod(-0.0im + (0:0))[1] === Complex(0.0, -0.0)

module TestNLoops15895

using Base.Cartesian
using Base.Test

# issue 15894
function f15894(d)
    s = zero(eltype(d))
    @nloops 1 i d begin
        s += @nref 1 d i
    end
    s
end
@test f15894(ones(Int, 100)) == 100
end

@testset "sign, conj, ~" begin
    A = [-10,0,3]
    B = [-10.0,0.0,3.0]
    C = [1,im,0]

    @test sign.(A) == [-1,0,1]
    @test sign.(B) == [-1,0,1]
    @test typeof(sign.(A)) == Vector{Int}
    @test typeof(sign.(B)) == Vector{Float64}

    @test conj(A) == A
    @test conj(B) == A
    @test conj(C) == [1,-im,0]
    @test typeof(conj(A)) == Vector{Int}
    @test typeof(conj(B)) == Vector{Float64}
    @test typeof(conj(C)) == Vector{Complex{Int}}

    @test .~A == [9,-1,-4]
    @test typeof(.~A) == Vector{Int}
end

@testset "issue #16247" begin
    A = zeros(3,3)
    @test size(A[:,0x1:0x2]) == (3, 2)
    @test size(A[:,UInt(1):UInt(2)]) == (3,2)
    @test size(similar(A, UInt(3), 0x3)) == size(similar(A, (UInt(3), 0x3))) == (3,3)
end

# issue 17254
module AutoRetType

using Base.Test

struct Foo end
for op in (:+, :*, :÷, :%, :<<, :>>, :-, :/, :\, ://, :^)
    @eval import Base.$(op)
    @eval $(op)(::Foo, ::Foo) = Foo()
end
A = fill(Foo(), 10, 10)
@test typeof(A+A) == Matrix{Foo}
@test typeof(A-A) == Matrix{Foo}
for op in (:.+, :.*, :.÷, :.%, :.<<, :.>>, :.-, :./, :.\, :.//, :.^)
    @eval @test typeof($(op)(A,A)) == Matrix{Foo}
end

end # module AutoRetType

@testset "concatenations of dense matrices/vectors yield dense matrices/vectors" begin
    N = 4
    densevec = ones(N)
    densemat = diagm(ones(N))
    # Test that concatenations of homogeneous pairs of either dense matrices or dense vectors
    # (i.e., Matrix-Matrix concatenations, and Vector-Vector concatenations) yield dense arrays
    for densearray in (densevec, densemat)
        @test isa(vcat(densearray, densearray), Array)
        @test isa(hcat(densearray, densearray), Array)
        @test isa(hvcat((2,), densearray, densearray), Array)
        @test isa(cat((1,2), densearray, densearray), Array)
    end
    @test isa([[1,2,3]'; [1,2,3]'], Matrix{Int})
    @test isa([[1,2,3]' [1,2,3]'], RowVector{Int, Vector{Int}})
    @test isa([Any[1.0, 2]'; Any[2.0, 2]'], Matrix{Any})
    @test isa([Any[1.0, 2]' Any[2.0, 2']'], RowVector{Any, Vector{Any}})
    # Test that concatenations of heterogeneous Matrix-Vector pairs yield dense matrices
    @test isa(hcat(densemat, densevec), Array)
    @test isa(hcat(densevec, densemat), Array)
    @test isa(hvcat((2,), densemat, densevec), Array)
    @test isa(hvcat((2,), densevec, densemat), Array)
    @test isa(cat((1,2), densemat, densevec), Array)
    @test isa(cat((1,2), densevec, densemat), Array)
end

@testset "type constructor Array{T, N}(d...) works (especially for N>3)" begin
    a = Array{Float64}(10)
    b = Array{Float64, 1}(10)
    @test size(a) == (10,)
    @test size(a, 1) == 10
    @test size(a,2,1) == (1,10)
    @test size(a) == size(b)
    a = Array{Float64}(2,3)
    b = Array{Float64, 2}(2,3)
    @test size(a) == (2,3)
    @test size(a,4,3,2,1) == (1,1,3,2)
    @test size(a,1,2) == (2,3)
    @test size(a) == size(b)
    a = Array{Float64}(9,8,7,6,5,4,3,2,1)
    b = Array{Float64, 9}(9,8,7,6,5,4,3,2,1)
    @test size(a,1,1) == (9,9)
    @test size(a,4) == 6
    @test size(a,9,8,7,6,5,4,3,2,19,8,7,6,5,4,3,2,1) == (1,2,3,4,5,6,7,8,1,2,3,4,5,6,7,8,9)
    @test size(a) == size(b)
end

@testset "accumulate, accumulate!" begin
    @test accumulate(+, [1,2,3]) == [1, 3, 6]
    @test accumulate(min, [1 2; 3 4], 1) == [1 2; 1 2]
    @test accumulate(max, [1 2; 3 0], 2) == [1 2; 3 3]
    @test accumulate(+, Bool[]) == Int[]
    @test accumulate(*, Bool[]) == Bool[]
    @test accumulate(+, Float64[]) == Float64[]

    @test accumulate(min, [1, 2, 5, -1, 3, -2]) == [1, 1, 1, -1, -1, -2]
    @test accumulate(max, [1, 2, 5, -1, 3, -2]) == [1, 2, 5, 5, 5, 5]

    @test accumulate(max, [1 0; 0 1], 1) == [1 0; 1 1]
    @test accumulate(max, [1 0; 0 1], 2) == [1 1; 0 1]
    @test accumulate(min, [1 0; 0 1], 1) == [1 0; 0 0]
    @test accumulate(min, [1 0; 0 1], 2) == [1 0; 0 0]

    @test isa(accumulate(+,     Int[]) , Vector{Int})
    @test isa(accumulate(+, 1., Int[]) , Vector{Float64})
    @test accumulate(+, 1, [1,2]) == [2, 4]
    arr = randn(4)
    @test accumulate(*, 1, arr) ≈ accumulate(*, arr)

    N = 5
    for arr in [rand(Float64, N), rand(Bool, N), rand(-2:2, N)]
        for (op, cumop) in [(+, cumsum), (*, cumprod)]
            @inferred accumulate(op, arr)
            accumulate_arr = accumulate(op, arr)
            @test accumulate_arr ≈ cumop(arr)
            @test accumulate_arr[end] ≈ reduce(op, arr)
            @test accumulate_arr[1] ≈ arr[1]
            @test accumulate(op, arr, 10) ≈ arr

            if eltype(arr) in [Int, Float64] # eltype of out easy
                out = similar(arr)
                @test accumulate!(op, out, arr) ≈ accumulate_arr
                @test out ≈ accumulate_arr
            end
        end
    end

    # exotic indexing
    arr = randn(4)
    oarr = OffsetArray(arr, (-3,))
    @test accumulate(+, oarr).parent == accumulate(+, arr)

    @inferred accumulate(+, randn(3))
    @inferred accumulate(+, 1, randn(3))

    # asymmetric operation
    op(x,y) = 2x+y
    @test accumulate(op, [10,20, 30]) == [10, op(10, 20), op(op(10, 20), 30)] == [10, 40, 110]
    @test accumulate(op, [10 20 30], 2) == [10 op(10, 20) op(op(10, 20), 30)] == [10 40 110]
end

@testset "zeros and ones" begin
    @test ones([1,2], Float64, (2,3)) == ones(2,3)
    @test ones(2) == ones(Int, 2) == ones([2,3], Float32, 2) ==  [1,1]
    @test isa(ones(2), Vector{Float64})
    @test isa(ones(Int, 2), Vector{Int})
    @test isa(ones([2,3], Float32, 2), Vector{Float32})

    function test_zeros(arr, T, s)
        @test all(arr .== 0)
        @test isa(arr, T)
        @test size(arr) == s
    end
    test_zeros(zeros(),      Array{Float64, 0}, ())
    test_zeros(zeros(2),     Vector{Float64},   (2,))
    test_zeros(zeros(2,3),   Matrix{Float64},   (2,3))
    test_zeros(zeros((2,3)), Matrix{Float64},   (2,3))

    test_zeros(zeros(Int, 6),      Vector{Int}, (6,))
    test_zeros(zeros(Int, 2, 3),   Matrix{Int}, (2,3))
    test_zeros(zeros(Int, (2, 3)), Matrix{Int}, (2,3))

    test_zeros(zeros([1 2; 3 4]), Matrix{Int}, (2, 2))
    test_zeros(zeros([1 2; 3 4], Float64), Matrix{Float64}, (2, 2))

    zs = zeros(SparseMatrixCSC([1 2; 3 4]), Complex{Float64}, (2,3))
    test_zeros(zs, SparseMatrixCSC{Complex{Float64}}, (2, 3))

    # #19265"
    @test_throws ErrorException zeros(Float64, [1.]) # TODO change to MethodError, when v0.6 deprecations are done
    x = [1.]
    test_zeros(zeros(x, Float64), Vector{Float64}, (1,))
    @test x == [1.]

    # exotic indexing
    oarr = zeros(randn(3), UInt16, 1:3, -1:0)
    @test indices(oarr) == (1:3, -1:0)
    test_zeros(oarr.parent, Matrix{UInt16}, (3, 2))
end

# issue #11053
mutable struct T11053
    a::Float64
end
Base.:*(a::T11053, b::Real) = T11053(a.a*b)
Base.:(==)(a::T11053, b::T11053) = a.a == b.a
@test [T11053(1)] * 5 == [T11053(1)] .* 5 == [T11053(5.0)]

#15907
@test typeof(Array{Int,0}()) == Array{Int,0}

@testset "issue 23629" begin
    @test_throws BoundsError zeros(2,3,0)[2,3]
    @test_throws BoundsError checkbounds(zeros(2,3,0), 2, 3)
end
