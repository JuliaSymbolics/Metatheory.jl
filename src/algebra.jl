# basic theory to check that everything works
t = @theory begin
    a + a => 2a
    x / x => 1
    x * 1 => x
end;

# Let's extend an operator from base, for sake of example
import Base.(+)
function +(x::Symbol, y)
    :(@reduce $x + $y t) |> eval
end

:a + :a
