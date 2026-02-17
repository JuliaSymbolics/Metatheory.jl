# Custom Operators Example

This example demonstrates how to use custom domain-specific operators with Metatheory.jl's e-graph based rewriting.

## Overview

As of version 3.0, Metatheory.jl supports custom operators defined by users, not just built-in Julia functions. This enables domain-specific optimization languages.

## Defining Custom Operators

Custom operators are typically defined as functions that return expressions:

```julia
using Metatheory
using Metatheory.EGraphs

# Define custom operators for your domain
MyAdd(x, y) = :(MyAdd($x, $y))
MyMul(x, y) = :(MyMul($x, $y))
MyNeg(x) = :(MyNeg($x))
```

## Creating Rewrite Rules

You can use custom operators in `@theory` blocks just like built-in functions:

```julia
theory = @theory begin
    # Algebraic identities for custom operators
    MyAdd(~x, 0) --> ~x
    MyMul(~x, 1) --> ~x
    MyMul(~x, 0) --> 0
    
    # Composition rules
    MyNeg(MyNeg(~x)) --> ~x
    MyAdd(~x, ~x) --> MyMul(2, ~x)
end
```

## Running Rewrites

Create an e-graph and apply the rules:

```julia
# Start with an expression using custom operators
expr = :(MyAdd(MyMul(a, 1), 0))

# Create e-graph and saturate with rules
eg = EGraph(expr)
saturate!(eg, theory)

# Extract simplified result
result = extract!(eg, astsize)
println(result)  # Output: a
```

## Extraction Cost Functions

When extracting from an e-graph, the cost function determines which equivalent expression to choose.

### Default: `astsize`

The `astsize` cost function prefers smaller expressions (fewer characters):

```julia
SmallOp(x) = :(SmallOp($x))
LargeOp(x, y) = :(LargeOp($x, $y))

theory = @theory begin
    SmallOp(~x) --> LargeOp(~x, 0)
end

eg = EGraph(:(SmallOp(a)))
saturate!(eg, theory)

# Chooses smaller expression
result = extract!(eg, astsize)  
# => SmallOp(a)
```

### Inverse: `astsize_inv`

The `astsize_inv` cost function prefers larger/more complex expressions:

```julia
# Same e-graph as above
result = extract!(eg, astsize_inv)
# => LargeOp(a, 0)
```

### Custom Cost Functions

You can define domain-specific cost functions:

```julia
function prefer_my_ops(node, egraph, child_costs)
    if !Metatheory.VecExprModule.v_isexpr(node)
        return 1.0
    end
    
    op_hash = Metatheory.VecExprModule.v_head(node)
    op = Metatheory.EGraphs.get_constant(egraph, op_hash)
    
    # Prefer certain operators
    if op == :MyAdd
        return 1.0 + sum(child_costs)
    elseif op == :MyMul
        return 2.0 + sum(child_costs)  # Slightly discourage
    else
        return 10.0 + sum(child_costs)  # Heavily discourage others
    end
end

result = extract!(eg, prefer_my_ops)
```

## Complete Example: Vector Operations

```julia
using Metatheory
using Metatheory.EGraphs

# Define vector operation operators
VAdd(x, y) = :(VAdd($x, $y))
VSub(x, y) = :(VSub($x, $y))
VScale(s, v) = :(VScale($s, $v))
VZero() = :(VZero())

# Define optimization rules
vector_rules = @theory begin
    # Identity
    VAdd(~v, VZero()) --> ~v
    VAdd(VZero(), ~v) --> ~v
    
    # Inverse
    VSub(~v, ~v) --> VZero()
    VAdd(~v, VSub(VZero(), ~v)) --> VZero()
    
    # Distributivity
    VScale(~s, VAdd(~v1, ~v2)) --> VAdd(VScale(~s, ~v1), VScale(~s, ~v2))
    
    # Constant folding
    VScale(0, ~v) --> VZero()
    VScale(1, ~v) --> ~v
end

# Optimize an expression
expr = :(VAdd(VScale(1, v), VZero()))
eg = EGraph(expr)
saturate!(eg, vector_rules)
optimized = extract!(eg, astsize)

println("Original:  ", expr)
println("Optimized: ", optimized)  # => v
```

## Key Points

1. **Custom operators work exactly like built-ins** after the v3.0 fix
2. **Choose appropriate cost functions** for your domain:
   - `astsize`: Minimize expression size
   - `astsize_inv`: Maximize expression size  
   - Custom: Define domain-specific preferences
3. **Mix custom and built-in operators** freely in rules
4. **Use directed (`-->`) or equality (`==`) rules** as appropriate

## More Examples

See the test suite in `test/egraphs/test_custom_operators.jl` for comprehensive examples.
