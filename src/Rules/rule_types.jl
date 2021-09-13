using Parameters
using AutoHashEquals
using ..Patterns

import Base.==

abstract type AbstractRule end
# Must override
==(a::AbstractRule, b::AbstractRule) = false


abstract type SymbolicRule <: AbstractRule end


# =============================================================================


abstract type BidirRule <: SymbolicRule end

