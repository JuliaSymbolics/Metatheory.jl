## Theory for CAS
using Metatheory
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.EGraphs.Schedulers
using TermInterface

mult_t = @commutative_monoid (*) 1
plus_t = @commutative_monoid (+) 0

minus_t = @theory begin
    # TODO Jacques Carette's post in zulip chat
    a - a       => 0
    a - b       => a + (-1*b)
    -a          => -1 * a
    a + (-b)    => a + (-1*b)
end


mulplus_t = @theory begin
    # TODO FIXME this rules improves performance and avoids commutative
    # explosion of the egraph
    a + a => 2 * a
    0 * a => 0
    a * 0       => 0
    a * (b + c) == ((a*b) + (a*c))
    a + (b * a) => ((b+1)*a)
end

pow_t = @theory begin
    (y^n) * y   => y^(n+1)
    x^n * x^m   == x^(n+m)
    (x * y)^z   == x^z * y^z
    (x^p)^q     == x^(p*q)
    x^0         => 1
    0^x         => 0
    1^x         => 1
    x^1         => x
    x * x       => x^2
    inv(x)      == x^(-1)
end

div_t = @theory begin
    x / 1 => x
    # x / x => 1 TODO SIGN ANALYSIS
    x / (x / y) => y
    x * (y / x) => y
    x * (y / z) == (x * y) / z
    x^(-1)      == 1 / x
end

trig_t = @theory begin 
    sin(θ)^2 + cos(θ)^2     => 1
    sin(θ)^2 - 1            => cos(θ)^2
    cos(θ)^2 - 1            => sin(θ)^2
    tan(θ)^2 - sec(θ)^2     => 1
    tan(θ)^2 + 1            => sec(θ)^2
    sec(θ)^2 - 1            => tan(θ)^2

    cot(θ)^2 - csc(θ)^2     => 1
    cot(θ)^2 + 1            => csc(θ)^2
    csc(θ)^2 - 1            => cot(θ)^2
end

# Dynamic rules
fold_t = @theory begin
    -(a::Number)            |> -a
    a::Number + b::Number   |> a + b
    a::Number * b::Number   |> a * b
    a::Number ^ b::Number   |> begin b < 0 && a isa Int && (a = float(a)) ; a^b end
    a::Number / b::Number   |> a/b
end

using Calculus: differentiate
diff_t = @theory begin
    ∂(y, x::Symbol) |> begin 
        z = extract!(_egraph, simplcost; root=y.id)
        @show z
        zd = differentiate(z, x)
        @show zd
        zd
    end
end

cas = fold_t ∪ mult_t ∪ plus_t ∪ minus_t ∪
    mulplus_t ∪ pow_t ∪ div_t ∪ trig_t ∪ diff_t
