
@testset "lookup" begin
    a = V"a"
    b = V"b"
    c = V"c"
    bindings = Bindings(a, 1,
                        Bindings(b, 2,
                                 EmptyBindings()))
    @test lookup(bindings, a) == (1, true)
    @test lookup(bindings, b) == (2, true)
    @test lookup(bindings, c) == (nothing, false)
end

@testset "ubind" begin
    a = V"a"
    b = V"b"
    c = V"c"
    ubind(a, 1) do bindings
        ubind(b, 2, bindings) do bindings
            ubind(c, 3, bindings) do bindings
                @test lookup(bindings, a) == (1, true)
                @test lookup(bindings, b) == (2, true)
                @test lookup(bindings, c) == (3, true)
            end
        end
    end
    ubind([a=>b]) do bindings
        # Binding two variables together is symetric:
        @test lookup(bindings, a) == (b, true)
        @test lookup(bindings, b) == (a, true)
    end
end

@testset "lookupall" begin
    a = V"a"
    b = V"b"
    ubind([a=>1, b=>2, a=>3]) do bindings
        @test lookupall(bindings, b) == Set([2])
        @test lookupall(bindings, a) == Set([3, 1])
    end
    ubind([a=>b]) do bindings
        # Binding two variables together is symetric:
        @test lookupall(bindings, a) == Set([b])
        @test lookupall(bindings, b) == Set([a])
    end
end

@testset "lookupequiv" begin
    a = V"a"
    b = V"b"
    c = V"c"
    ubind([a=>b, b=>a, c=>3, a=>c]) do bindings
        found, vars = lookupequiv(bindings, a)
        @test found == Set{Any}(3)
        @test vars == Set{AbstractVar}([a, b, c])
    end
    ubind([a=>b, a=>c]) do bindings
        found, vars = lookupequiv(bindings, c)
        @test found == Set{Any}()
        @test vars == Set{AbstractVar}([a, b, c])
    end
end

