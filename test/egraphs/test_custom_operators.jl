using Test
using Metatheory
using Metatheory.EGraphs

@testset "Custom Operators" begin
    # Define custom operators as user would in domain-specific language
    CustomAdd(x, y) = :(CustomAdd($x, $y))
    CustomMul(x, y) = :(CustomMul($x, $y))
    CustomNeg(x) = :(CustomNeg($x))
    CustomSqrt(x) = :(CustomSqrt($x))
    
    @testset "Unary Custom Operator" begin
        theory = @theory begin
            CustomNeg(CustomNeg(~x)) --> ~x
        end
        
        eg = EGraph(:(CustomNeg(CustomNeg(a))))
        saturate!(eg, theory)
        result = extract!(eg, astsize)
        
        @test result == :a
    end
    
    @testset "Binary Custom Operator" begin
        theory = @theory begin
            CustomAdd(~x, 0) --> ~x
            CustomAdd(0, ~x) --> ~x
        end
        
        eg1 = EGraph(:(CustomAdd(a, 0)))
        saturate!(eg1, theory)
        result1 = extract!(eg1, astsize)
        @test result1 == :a
        
        eg2 = EGraph(:(CustomAdd(0, b)))
        saturate!(eg2, theory)
        result2 = extract!(eg2, astsize)
        @test result2 == :b
    end
    
    @testset "Custom Operator Composition" begin
        theory = @theory begin
            CustomMul(~x, 1) --> ~x
            CustomMul(~x, 0) --> 0
            CustomAdd(~x, ~x) --> CustomMul(2, ~x)
        end
        
        eg = EGraph(:(CustomAdd(a, a)))
        saturate!(eg, theory)
        result = extract!(eg, astsize)
        
        # Should transform a + a => 2 * a
        @test result == :(CustomMul(2, a))
    end
    
    @testset "Custom vs Built-in Mixing" begin
        theory = @theory begin
            CustomSqrt(~x * ~x) --> ~x
            ~x * ~x --> CustomSqrt(~x) * CustomSqrt(~x)
        end
        
        eg = EGraph(:(a * a))
        saturate!(eg, theory)
        
        # Both forms should be in the e-graph
        @test length(eg.classes) >= 2
    end
    
    @testset "Extraction Cost Functions" begin
        # Define a custom operator that is "larger" than built-in
        LargeOp(x, y) = :(LargeOp($x, $y))
        SmallOp(x) = :(SmallOp($x))
        
        theory = @theory begin
            SmallOp(~x) --> LargeOp(~x, 0)
        end
        
        eg = EGraph(:(SmallOp(a)))
        saturate!(eg, theory)
        
        # astsize should prefer smaller expression
        result_small = extract!(eg, astsize)
        @test result_small == :(SmallOp(a))
        
        # astsize_inv should prefer "larger" expression
        eg2 = EGraph(:(SmallOp(a)))
        saturate!(eg2, theory)
        result_large = extract!(eg2, astsize_inv)
        @test result_large == :(LargeOp(a, 0))
    end
    
    @testset "Directed Rules with Custom Operators" begin
        MyFunc(x) = :(MyFunc($x))
        MyOther(x, y) = :(MyOther($x, $y))
        
        theory = @theory begin
            MyFunc(~x) --> MyOther(~x, 0)
        end
        
        eg = EGraph(:(MyFunc(test)))
        saturate!(eg, theory)
        result = extract!(eg, astsize_inv)
        
        @test result == :(MyOther(test, 0))
    end
    
    @testset "Equality Rules with Custom Operators" begin
        OpA(x) = :(OpA($x))
        OpB(x) = :(OpB($x))
        
        theory = @theory begin
            OpA(~x) == OpB(~x)
        end
        
        eg = EGraph(:(OpA(value)))
        saturate!(eg, theory)
        
        # Both should be in same e-class
        classes = collect(values(eg.classes))
        @test any(eclass -> length(eclass.nodes) > 1, classes)
    end
    
    @testset "Regression: Custom Operators with Multiple Arguments" begin
        # Test the fix works for various arities
        Nullary() = :(Nullary())
        Unary(x) = :(Unary($x))
        Binary(x, y) = :(Binary($x, $y))
        Ternary(x, y, z) = :(Ternary($x, $y, $z))
        
        theory = @theory begin
            Binary(~x, Nullary()) --> Unary(~x)
            Ternary(~x, ~y, ~z) --> Binary(~x, Binary(~y, ~z))
        end
        
        eg1 = EGraph(:(Binary(a, Nullary())))
        saturate!(eg1, theory)
        result1 = extract!(eg1, astsize)
        @test result1 == :(Unary(a))
        
        eg2 = EGraph(:(Ternary(a, b, c)))
        saturate!(eg2, theory)
        # Should flatten to nested binary
        @test length(eg2.classes) >= 3
    end
end
