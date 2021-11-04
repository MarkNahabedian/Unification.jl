
@testset "simple unify" begin
    function test_unify(thing1, thing2)
        unified = 0
        unify(thing1, thing2) do bindings
            unified += 1
        end
        @assert unified <= 1
        return unified == 1
    end

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
