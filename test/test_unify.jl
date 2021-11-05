
trace_unifications = false

function test_unify(thing1, thing2)
    unified = 0
    unify(thing1, thing2) do bindings
        unified += 1
        if trace_unifications
            println(stacktrace())
        end
    end
    @assert(unified <= 1, "$unified results")
    return unified == 1
end

@testset "simple unify" begin
    @test test_unify(1, 2) == false
    @test test_unify(1, 1) == true
    @test test_unify(1, 1.0) == true
    @test test_unify(:a, :b) == false
    @test test_unify(:a, :a) == true
    @test test_unify('a', 'a') == true
    @test test_unify('a', 'b') == false
    @test test_unify("foo", "foo") == true
    @test test_unify("foo", "foob") == false
end

@testset "Unify Fields" begin
    struct Struct1
        a
        b
    end
    struct Struct2
        a
        b
    end
    @test test_unify(Struct1(1, 2), Struct1(1, 2)) == true
    @test test_unify(Struct1(1, 2), Struct1(1, 3)) == false
    @test test_unify(Struct1(1, 2), Struct2(1, 2)) == false
    @test test_unify(Struct1(Struct1(4, 5), 2), Struct1(Struct1(4, 5), 2)) == true
    @test test_unify(Struct1(Struct1(4, 5), 2), Struct1(Struct1(4, 0), 2)) == false
    # Pair has fields:
    @tewt test_unify(:a => 1, :a => 1) == true
    @tewt test_unify(:a => 1, :a => 2) == false
    @tewt test_unify(:b => 1, :a => 1) == false
end
