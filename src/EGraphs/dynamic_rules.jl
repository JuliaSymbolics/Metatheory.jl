# example theory for auto generation
example_theory = @theory begin
    a::Number |> a
    a::Number * b::Number |> a * b
    a::Number + b::Number |> a + b
end


"""
Generate an Analysis
"""
function compile_analysis(t::Theory)

end

filter(r -> r.mode == :dynamic, t)

abstract type Vehicle end
drive(v::Vehicle) = println("driving")

function test(mod=@__MODULE__)
    RuntimeGeneratedFunctions.init(mod)
    sym = gensym(:Car)
    eval( quote
    struct $(sym) <: Vehicle end
    sym = $(sym)
    ex = :(x::$(sym) -> println("vroom"))
    f = @RuntimeGeneratedFunction(ex)
    drive(c::$(sym)) = f(c)
    $(sym)
    end
    )
end
