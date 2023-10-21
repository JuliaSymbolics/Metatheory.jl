using Metatheory
using Metatheory.EGraphs
using TermInterface
using Test

# TODO update

function EGraphs.make(::Val{:sign_analysis}, g::EGraph, n::ENodeLiteral)
  if n.value isa Real
    if n.value == Inf
      Inf
    elseif n.value == -Inf
      -Inf
    elseif n.value isa Real # in Julia NaN is a Real
      sign(n.value)
    else
      nothing
    end
  elseif n.value isa Symbol
    s = n.value
    s == :x && return 1
    s == :y && return -1
    s == :z && return 0
    s == :k && return Inf
    return nothing
  end
end

function EGraphs.make(::Val{:sign_analysis}, g::EGraph, n::ENodeTerm)
  # Let's consider only binary function call terms.
  if exprhead(n) == :call && arity(n) == 2
    # get the symbol name of the operation
    op = operation(n)
    op = op isa Function ? nameof(op) : op

    # Get the left and right child eclasses
    child_eclasses = arguments(n)
    l = g[child_eclasses[1]]
    r = g[child_eclasses[2]]

    # Get the corresponding SignAnalysis value of the children
    # defaulting to nothing 
    lsign = getdata(l, :sign_analysis, nothing)
    rsign = getdata(r, :sign_analysis, nothing)

    (lsign == nothing || rsign == nothing) && return nothing

    if op == :*
      return lsign * rsign
    elseif op == :/
      return lsign / rsign
    elseif op == :+
      s = lsign + rsign
      iszero(s) && return nothing
      (isinf(s) || isnan(s)) && return s
      return sign(s)
    elseif op == :-
      s = lsign - rsign
      iszero(s) && return nothing
      (isinf(s) || isnan(s)) && return s
      return sign(s)
    end
  end
  return nothing
end

function EGraphs.join(::Val{:sign_analysis}, a, b)
  return a == b ? a : nothing
end


# we are cautious, so we return false by default 
isnotzero(x::EClass) = getdata(x, :sign_analysis, false)

# t = @theory a b c begin 
#   a * (b * c) == (a * b) * c
#   a + (b + c) == (a + b) + c
#   a * b == b * a
#   a + b == b + a
#   a * (b + c) == (a * b) + (a * c)
#   a::isnotzero / a::isnotzero  --> 1 
# end


function custom_analysis(expr)
  g = EGraph(expr)
  # saturate!(g, t)
  analyze!(g, :sign_analysis)
  return getdata(g[g.root], :sign_analysis)
end

custom_analysis(:(3 * x)) # :odd
custom_analysis(:(3 * (2 + a) * 2)) # :even
custom_analysis(:(-3y * (2x * y))) # :even
custom_analysis(:(k / k)) # :even


#===========================================================================================#

# pattern variables can be specified before the block of rules
comm_monoid = @theory a b c begin
  a * b == b * a # commutativity
  a * 1 --> a    # identity
  a * (b * c) == (a * b) * c   # associativity
end;

# theories are just vectors of rules
comm_group = [
  @rule a b (a + b == b + a) # commutativity
  # pattern variables can also be written with the prefix ~ notation
  @rule ~a + 0 --> ~a   # identity
  @rule a b c (a + (b + c) == (a + b) + c)   # associativity
  @rule a (a + (-a) => 0) # inverse
];

# dynamic rules are defined with the `=>` operator
folder = @theory a b begin
  a::Real + b::Real => a + b
  a::Real * b::Real => a * b
  a::Real / b::Real => a / b
end;

div_sim = @theory a b c begin
  (a * b) / c == a * (b / c)
  a::isnotzero / a::isnotzero --> 1
end;

t = vcat(comm_monoid, comm_group, folder, div_sim);

g = EGraph(:(a * (2 * 3) / 6));
saturate!(g, t)

@test :a == extract!(g, astsize)
# :a
