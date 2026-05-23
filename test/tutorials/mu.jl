# # The MU Puzzle 
# The puzzle cannot be solved: it is impossible to change the string MI into MU
# by repeatedly applying the given rules. In other words, MU is not a theorem of
# the MIU formal system. To prove this, one must step "outside" the formal system
# itself. [Wikipedia](https://en.wikipedia.org/wiki/MU_puzzle#Solution)
#

using Metatheory, Test

include("../../examples/prove.jl")

#
# Original source: Douglas Hofstadter: Gödel, Escher, Bach: An Eternal Golden Braid, 1999, pp 42-43
# Rule 1: If you possess a string whose last letter is I, you can add a U at the end.
# Rule 2: Suppose you have Mx. Then you may add Mxx to your collection.
# Rule 3: If III occurs in one of the strings in your collection, you may make a 
#         new string with U in place of III.
# Rule 4: If UU occurs in one of your strings, you can drop it.

# Here are the axioms of MU for equality saturation:
# * Composition of the string monoid is associative
# * Add a U to the end of any string ending in I
# * Double the string after the M
# * Replace any III with a U
# * Remove any UU
# We enforce an :END symbol, so that we do not need to handle the empty chain in UU --> \eps.
function ⋅ end
miu = @theory x y z begin
  (x ⋅ y) ⋅ z == x ⋅ (y ⋅ z)
  :I ⋅ :END --> :I ⋅ :U ⋅ :END
  :M ⋅ x ⋅ :END --> :M ⋅ x ⋅ x ⋅ :END
  :I ⋅ :I ⋅ :I --> :U
  :U ⋅ :U ⋅ y --> y
end


# No matter the timeout we set here,
# MU is not a theorem of the MIU system 
params = SaturationParams(timeout = 20, eclasslimit = 20000)
start = :(M ⋅ I ⋅ END)
@test false == test_equality(miu, start, :(M ⋅ U ⋅ END); params)

# Examples given in Douglas Hofstadter: Gödel, Escher, Bach: An Eternal Golden Braid, 1999, page 44
@test true == test_equality(miu, start, :(M ⋅ I ⋅ END); params) # (1) inital axiom
@test true == test_equality(miu, start, :(M ⋅ I ⋅ I ⋅ END); params) # (2) from (1) by Rule 2
@test true == test_equality(miu, start, :(M ⋅ I ⋅ I ⋅ I ⋅ I ⋅ END); params) # (3) from (2) by Rule 2 [this is incorrectly given as MIII in the book]
@test true == test_equality(miu, start, :(M ⋅ I ⋅ I ⋅ I ⋅ I ⋅ U ⋅ END); params) # (4) from (3) by Rule 1
@test true == test_equality(miu, start, :(M ⋅ U ⋅ I ⋅ U ⋅ END); params) # (5) from (4) by Rule 3
@test true == test_equality(miu, start, :(M ⋅ U ⋅ I ⋅ U ⋅ U ⋅ I ⋅ U ⋅ END); params) # (6) from (5) by Rule 2
@test true == test_equality(miu, start, :(M ⋅ U ⋅ I ⋅ I ⋅ U ⋅ END); params) # (7) from (6) by Rule 4
