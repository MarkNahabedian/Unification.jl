
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
end

#=
@testset "circular bindings" begin
    a = V"a"
    b = V"b"
    c = V"c"
    bindings = Bindings(a, b,
                        Bindings(b, c,
                                 Bindings(c, a,
                                          EmptyBindings())))
    @test lookup(bindings, a) == (nothing, false, :exhausted)
    @test lookup(bindings, b) == (nothing, false, :exhausted)
    @test lookup(bindings, c) == (nothing, false, :exhausted)
    ubind(b, 4, bindings) do bindings
        println("***", bindings)
        @test lookup(bindings, b) == (4, true)
        @test lookup(bindings, a) == (4, true)
        @test lookup(bindings, c) == (4, true)
    end
end
=#

#=
@testset "test_bindings" begin
    a = V"a"
    b = V"b"
    c = V"c"
    d = V"d"
    ubind(
        function(bindings)
            println(bindings)
            @test lookup(bindings, a) == (2, true)
            @test lookup(bindings, b) == (nothing, false)
            ubind(
                function(bindings)
                    ubind(
                        function(bindings)
                            ubind(
                                function(bindings)
                                    @test lookup(bindings, a) == (2, true)
                                    @test lookup(bindings, b) == (2, true)
                                    @test lookup(bindings, c) == (2, true)
                                    @test lookup(bindings, d) == (3, true)
                                    dict = toDict(bindings)
                                    @test dict[a] == 2
                                    @test dict[b] == 2
                                    @test dict[c] == 2
                                    @test dict[d] == 3
                                end,
                                c, a, bindings)
                        end,
                        b, c, bindings)
                end
                ,d, 3, bindings)
        end,
        a, 2)
end
=#
#=
@testset "test_bindings" begin
    a = V"a"
    b = V"b"
    c = V"c"
    d = V"d"
    ubind(a, 2) do bindings
        @test lookup(bindings, a) == (2, true)
        @test lookup(bindings, b) == (nothing, false)
        ubind(d, 3, bindings) do bindings
            ubind(b, c, bindings) do bindings
                ubind(c, a, bindings) do bindings
                    @test lookup(bindings, a) == (2, true)
                    @test lookup(bindings, b) == (2, true)
                    @test lookup(bindings, c) == (2, true)
                    @test lookup(bindings, d) == (3, true)
                    dict = toDict(bindings)
                    @test dict[a] == 2
                    @test dict[b] == 2
                    @test dict[c] == 2
                    @test dict[d] == 3
                end
            end
        end
    end
end
=#

