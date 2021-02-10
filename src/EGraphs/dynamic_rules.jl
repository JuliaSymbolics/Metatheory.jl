# example theory for auto generation
example_theory = @theory begin
    a::Number |> a
    a::Number * b::Number |> a * b
    a::Number + b::Number |> a + b 
end
