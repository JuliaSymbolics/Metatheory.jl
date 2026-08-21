@setup_workload begin
  symbolic_rule = @rule ~x * 1 --> ~x
  dynamic_rule = @rule ~x::Number + ~y::Number => ~x + ~y
  equality_theory = @theory begin
    ~x + 0 == ~x
    ~x * 1 == ~x
  end

  @compile_workload begin
    rewrite(:(x * 1), [symbolic_rule])
    rewrite(:(1 + 2), [dynamic_rule]; order = :inner)

    egraph = EGraph(:(x + 0))
    saturate!(egraph, equality_theory, SaturationParams(timeout = 2, timer = false))
    extract!(egraph, astsize)
  end
end
