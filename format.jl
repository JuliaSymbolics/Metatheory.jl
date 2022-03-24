using JuliaFormatter

format(file; kwargs...) = JuliaFormatter.format(joinpath(@__DIR__, file); kwargs...)

#format("src"; verbose = true)
format("test"; verbose = true)