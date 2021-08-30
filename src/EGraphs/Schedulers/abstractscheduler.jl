using DocStringExtensions

"""
Represents a rule scheduler for the equality saturation process

"""
abstract type AbstractScheduler end

"""
Should return `true` if the e-graph can be said to be saturated
```
cansaturate(s::AbstractScheduler)
```
"""
function cansaturate end 

"""
Should return `false` if the rule `r` should be skipped
```
cansearch(s::AbstractScheduler, r::Rule)
```
"""
function cansearch end

"""
This function is called **after** pattern matching on the e-graph,
informs the scheduler about the yielded matches.
Returns `false` if the matches should not be yielded and ignored. 
```
inform!(s::AbstractScheduler, r::AbstractRule, n_matches)
```
"""
function inform! end

function setiter! end