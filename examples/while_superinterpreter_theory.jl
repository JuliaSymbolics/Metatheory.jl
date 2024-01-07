## A Very Tiny Turing Complete Programming Language defined with denotational semantics

import Base.ImmutableDict
Mem = Dict{Symbol,Union{Bool,Int}}

read_mem = @theory v σ begin
  (v::Symbol, σ::Mem) => if v == :skip
    σ
  else
    σ[v]
  end
end


arithm_rules = @theory a b σ begin
  (a + b, σ::Mem) --> (a, σ) + (b, σ)
  (a * b, σ::Mem) --> (a, σ) * (b, σ)
  (a - b, σ::Mem) --> (a, σ) - (b, σ)
  (a::Int, σ::Mem) --> a
  (a::Int + b::Int) => a + b
  (a::Int * b::Int) => a * b
  (a::Int - b::Int) => a - b
end


# don't need to access memory
bool_rules = @theory a b σ begin
  (a < b, σ::Mem) --> (a, σ) < (b, σ)
  (a || b, σ::Mem) --> (a, σ) || (b, σ)
  (a && b, σ::Mem) --> (a, σ) && (b, σ)
  (!(a), σ::Mem) --> !((a, σ))

  (a::Bool, σ::Mem) => a
  (!a::Bool) => !a
  (a::Bool || b::Bool) => (a || b)
  (a::Bool && b::Bool) => (a && b)
  (a::Int < b::Int) => (a < b)
end

if_rules = @theory guard t f σ begin
  (
    if guard
      t
    end
  ) --> (
    if guard
      t
    else
      :skip
    end
  )

  (if guard
    t
  else
    f
  end, σ::Mem) --> (if (guard, σ)
    t
  else
    f
  end, σ)

  (if true
    t
  else
    f
  end, σ::Mem) --> (t, σ)

  (if false
    t
  else
    f
  end, σ::Mem) --> (f, σ)
end

if_language = read_mem ∪ arithm_rules ∪ bool_rules ∪ if_rules


while_rules = @theory a b σ begin
  (:skip, σ::Mem) --> σ
  ((a; b), σ::Mem) --> ((a, σ); b)
  (a::Int; b) --> b
  (a::Bool; b) --> b
  (σ::Mem; b) --> (b, σ)
  (while a
    b
  end, σ::Mem) --> (if a
    (b;
    while a
      b
    end)
  else
    :skip
  end, σ)
end


write_mem = @theory sym val σ begin
  (sym::Symbol = val, σ::Mem) --> (sym = (val, σ), σ)
  (sym::Symbol = val::Int, σ::Mem) => merge(σ, Dict(sym => val))
end

while_language = if_language ∪ write_mem ∪ while_rules;