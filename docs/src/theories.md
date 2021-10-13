# Rules and Theories


## Theories are Collections and Composable

Theories are just collections, precisely *vectors of the `Rule` object*, and can
be composed as regular Julia collections. The most
useful way of composing theories is unioning
them with the '∪' operator.
You are not limited to composing theories, you can
manipulate and create them at both runtime and compile time
as regular vectors.

```@example 2
using Metatheory
using Metatheory.Library

comm_monoid = @commutative_monoid (*) 1
comm_group = @theory a b c begin
    a + 0 --> a
    a + b --> b + a
    a + inv(a) --> 0 # inverse
    a + (b + c) --> (a + b) + c
end
distrib = @theory a b c begin
    a * (b + c) => (a * b) + (a * c)
end
t = comm_monoid ∪ comm_group ∪ distrib
```



