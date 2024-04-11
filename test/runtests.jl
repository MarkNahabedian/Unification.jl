using Unification
using Logging
using Test

using Unification: merge_expr_tuples, splatted_exprs_lookup

@testset "merge_expr_tuples" begin
    @test merge_expr_tuples((Expr(:(=), :a, 3),
                             Expr(:(=), :b, 4)),
                            (Expr(:(=), :a, 0),
                             Expr(:(=), :c, 5),)) ==
                                 [:(a = 3), :(b = 4), :(c = 5)]
end

@testset "splatted_exprs_lookup" begin
    se = (:(a = 3), :(b = 1))
    @test splatted_exprs_lookup(se, :a) == 3
    @test splatted_exprs_lookup(se, :b) == 1
    @test splatted_exprs_lookup(se, :c) isa Missing
end

include("test_bindings.jl")
include("test_unify.jl")

