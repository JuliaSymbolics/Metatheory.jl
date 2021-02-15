"Represents a rule scheduler for the equality saturation process"
abstract type AbstractScheduler end

"Should return true if the e-graph can be said to be saturated"
cansaturate(s::AbstractScheduler) = error("not implemented")
"Should return true if the rule `r` should be skipped"
shouldskip(s::AbstractScheduler, r::Rule) = error("not implemented")

"This function is called **before** pattern matching on the e-graph"
readstep!(s::AbstractScheduler) = nothing
"This function is called **after** pattern matching on the e-graph"
writestep!(s::AbstractScheduler, r::Rule) = nothing
