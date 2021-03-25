"""
This module contains classical rewriting functions and utilities
"""
module Classic

using ..Rules
import ..patvars
# import ..gettheory
import ..closure_generator
import ..@metatheory_init
using ..Util
using Base.Meta

@metatheory_init

include("matchcore_compiler.jl")
include("rewrite.jl")
include("match.jl")

export rewrite
export @rewrite
export @esc_rewrite
export @compile_theory
export @matcher
export @rewriter


end
