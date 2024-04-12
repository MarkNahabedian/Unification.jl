
using Logging

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

@testset "Unify Fields" begin
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

@testset "unify variables" begin
    unify(Struct1(V"a", V"b"), Struct1(:a, :b)) do bindings
        @test lookup(bindings, V"a") == (:a, true)
        @test lookup(bindings, V"b") == (:b, true)
    end
    unify(Struct1(V"a", :b), Struct1(:a, V"b")) do bindings
        @test lookup(bindings, V"a") == (:a, true)
        @test lookup(bindings, V"b") == (:b, true)
    end
    @test test_unify((V"a", V"a", 3), (1, 2, 3)) == false
    unify((V"a", V"a", 3), (1, 1, 3)) do bindings
        @test lookup(bindings, V"a") == (1, true)
    end
    # Transitive circular reference:
    unify((V"a", V"b"), (V"b", V"a")) do bindings
        vals, vars = lookupequiv(bindings, V"a")
        @test isempty(vals) == true
        @test vars == Set([V"a", V"b"])
    end
    unify((V"a", 2, V"a"), (V"b", V"b", 2)) do bindings
        @test lookup(bindings, V"b") == (2, true)
        @test lookup(bindings, V"a") == (2, true)
    end
end

@testset "unify SubseqVar head 1" begin
    unified = false
    unify([V"a...", 5, 6], 1:6) do bindings
        unified = true
        @test lookup(bindings, V"a...") == (1:4, true)
    end
    @test unified == true
end

@testset "unify SubseqVar tail 1" begin
    unified = false
    unify([1, 2, V"a..."], 1:6) do bindings
        unified = true
        @test lookup(bindings, V"a...") == (3:6, true)
    end
    @test unified == true
end

@testset "unify SubseqVar middle 1" begin
    unified = false
    unify([1, 2, V"a...", 7, 8], 1:8) do bindings
        unified = true
        @test lookup(bindings, V"a...") == (3:6, true)
    end
    @test unified == true
end

@testset "unify SubseqVar head 2" begin
    unified = false
    unify(1:6, [V"a...", 5, 6]) do bindings
        unified = true
        @test lookup(bindings, V"a...") == (1:4, true)
    end
    @test unified == true
end

@testset "unify SubseqVar tail 2" begin
    unified = false
    unify(1:6, [1, 2, V"a..."]) do bindings
        unified = true
        @test lookup(bindings, V"a...") == (3:6, true)
    end
    @test unified == true
end

@testset "unify SubseqVar middle 2" begin
    unified = false
    unify(1:8, [1, 2, V"a...", 7, 8]) do bindings
        unified = true
        @test lookup(bindings, V"a...") == (3:6, true)
    end
    @test unified == true
end

@testset "unify multiple adjacent SubseqVars" begin
    found = Set()
    unify(1:6, [1, V"a...", V"b...", 5, 6]) do bindings
        @debug bindings
        va, fa = lookup(bindings, V"a...")
        vb, fb = lookup(bindings, V"b...")
        @test fa == true
        @test fb == true
        push!(found, (va, vb))
    end
    @debug found
    @test length(found) == 4
    @test found == Set([([], [2, 3, 4]),
                        ([2], [3, 4]),
                        ([2, 3], [4]),
                        ([2, 3, 4], [])])
end


@testset "unification examples" begin
    unified = false
    unify([Struct1(3, V"foo"), 12],
          [Struct1(V"bar", V"c"), V"c"]) do bindings
              unified = true
              @test lookup(bindings, V"bar") == (3, true)
              @test lookup(bindings, V"foo") == (12, true)
              @test lookup(bindings, V"c") == (12, true)
          end
    @test unified == true
end

