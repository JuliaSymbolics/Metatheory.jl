# # The MU Puzzle 
# The puzzle cannot be solved: it is impossible to change the string MI into MU
# by repeatedly applying the given rules. In other words, MU is not a theorem of
# the MIU formal system. To prove this, one must step "outside" the formal system
# itself. 
# https://en.wikipedia.org/wiki/MU_puzzle#Solution

using Metatheory, Test

# Here are the axioms of MU:
# * Composition of the string monoid is associative
# * Add a uf to the end of any string ending in I
# * Double the string after the M
# * Replace any III with a U
# * Remove any UU
function ⋅ end
miu = @theory x y z begin
  x ⋅ (y ⋅ z) --> (x ⋅ y) ⋅ z
  x ⋅ :I ⋅ :END --> x ⋅ :I ⋅ :U ⋅ :END
  :M ⋅ x ⋅ :END --> :M ⋅ x ⋅ x ⋅ :END
  :I ⋅ :I ⋅ :I --> :U
  x ⋅ :U ⋅ :U ⋅ y --> x ⋅ y
end


# No matter the timeout we set here,
# MU is not a theorem of the MIU system 
params = SaturationParams(timeout = 12, eclasslimit = 8000)
start = :(M ⋅ I ⋅ END)
g = EGraph(start)
saturate!(g, miu)
@test false == areequal(g, miu, start, :(M ⋅ U ⋅ END); params = params)

