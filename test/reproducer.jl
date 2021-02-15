module Foo
using RuntimeGeneratedFunctions
const RGF = RuntimeGeneratedFunctions
RGF.init(@__MODULE__)

function closure_gen(mod::Module)
    RuntimeGeneratedFunction((@__MODULE__), (@__MODULE__),
        :( body -> begin
            ($mod != @__MODULE__) && !isdefined($mod, RGF._tagname) && RGF.init($mod)
            RuntimeGeneratedFunction($mod, $mod, :(x -> $body))
        end
        ))
    end


function bar(n::Int; mod = @__MODULE__)
    f = genclosure(:(x * $n), mod)
    g = x -> 2 * f(x)
    g(3)
end

function barr(n::Int; mod = @__MODULE__)
    f = (closure_gen(mod))(:(x * $n))
    g = x -> 2 * f(x)
    g(3)
end

export bar
export barr
export genclosure

end


barr(3, mod=@__MODULE__)

# OK
julia> bar(3)
18

julia> bar(3, mod=@__MODULE__)
ERROR: MethodError: no method matching generated_callfunc(::RuntimeGeneratedFunctions.RuntimeGeneratedFunction{(:x,), var"#_RGF_ModTag", var"#_RGF_ModTag", (0x346def3e, 0x769edc98, 0x33949a6f, 0xc294c197, 0xcea7fb6f)}, ::Int64)
The applicable method may be too new: running in world age 29602, while current world is 29605.
Closest candidates are:
  generated_callfunc(::RuntimeGeneratedFunctions.RuntimeGeneratedFunction{argnames, cache_tag, var"#_RGF_ModTag", id}, ::Any...) where {argnames, cache_tag, id} at none:0 (method too new to be called from this world context.)
  generated_callfunc(::RuntimeGeneratedFunctions.RuntimeGeneratedFunction{argnames, cache_tag, Main.Foo.var"#_RGF_ModTag", id}, ::Any...) where {argnames, cache_tag, id} at none:0
Stacktrace:
 [1] (::RuntimeGeneratedFunctions.RuntimeGeneratedFunction{(:x,), var"#_RGF_ModTag", var"#_RGF_ModTag", (0x346def3e, 0x769edc98, 0x33949a6f, 0xc294c197, 0xcea7fb6f)})(args::Int64)
   @ RuntimeGeneratedFunctions ~/.julia/packages/RuntimeGeneratedFunctions/tJEmP/src/RuntimeGeneratedFunctions.jl:92
 [2] (::Main.Foo.var"#3#4"{RuntimeGeneratedFunctions.RuntimeGeneratedFunction{(:x,), var"#_RGF_ModTag", var"#_RGF_ModTag", (0x346def3e, 0x769edc98, 0x33949a6f, 0xc294c197, 0xcea7fb6f)}})(x::Int64)
   @ Main.Foo ./REPL[1]:11
 [3] bar(n::Int64; mod::Module)
   @ Main.Foo ./REPL[1]:12
 [4] top-level scope
   @ REPL[4]:1

# Calling it again works
julia> bar(3, mod=@__MODULE__)
18
