# May be really useful for category theoretic constructs

struct Arrow{X,Y}
   fun::Function
end

(-->)(a,b) = Arrow{a,b}

Int --> Int
# Arrow{Int64, Int64}

f = (Int --> Int)((x) -> x*2)

# allows for currying
Base.operator_associativity(:-->) #:right

(a::Arrow{X,Y})(x) where X where Y = begin
   !(x isa X) && error("type error")
   y = a.fun(x)
   !(y isa Y) && error("type error", typeof(y))
   return y
end

f(2) # 4

dom(a::Arrow{X,Y}) where X where Y = X
cod(a::Arrow{X,Y}) where X where Y = Y

g = (Int --> Int --> Int)((x) ->
   (Int --> Int)((y) -> (x * y)))

g(3)(4)
