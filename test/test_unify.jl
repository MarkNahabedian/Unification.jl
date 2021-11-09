
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
    struct Struct0 end
    struct Struct0a end
    struct Struct1
        a
        b
    end
    struct Struct2
        a
        b
    end
    @test test_unify(Struct1(1, Struct0()), Struct1(1, Struct0())) == true
    @test test_unify(Struct1(1, 2), Struct1(1, 3)) == false
    @test test_unify(Struct1(1, 2), Struct2(1, 2)) == false
    @test test_unify(Struct1(Struct1(4, 5), 2), Struct1(Struct1(4, 5), 2)) == true
    @test test_unify(Struct1(Struct1(4, 5), 2), Struct1(Struct1(4, 0), 2)) == false
    # Pair has fields:
    @test test_unify(:a => 1, :a => 1) == true
    @test test_unify(:a => 1, :a => 2) == false
    @test test_unify(:b => 1, :a => 1) == false
end

@testset "unify ignore" begin
    @test test_unify(1, V"") == true
    @test test_unify(V"", 2) == true
    struct Struct1
        a
        b
    end
    @test test_unify(Struct1(V"", 2), Struct1(1, 2)) == true
    @test test_unify(Struct1(2, V""), Struct1(2, 1)) == true
    @test test_unify(Struct0(), Struct0a()) == false
end

@testset "unify indexable" begin
    r1 = 3:8
    v1 = collect(r1)
    t1 = Tuple(r1)
    @test test_unify(r1, v1) == true
    @test test_unify(r1, t1) == true
    @test test_unify(t1, v1) == true
    v2 = [1, 2, 3]
    @test test_unify(v1, v2) == false
end

