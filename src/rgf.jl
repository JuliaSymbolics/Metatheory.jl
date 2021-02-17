using RuntimeGeneratedFunctions
const RGF = RuntimeGeneratedFunctions

# see https://github.com/SciML/RuntimeGeneratedFunctions.jl/issues/28
function closure_generator(mod::Module, expr)
    (mod != @__MODULE__) && !isdefined(mod, RGF._tagname) && RGF.init(mod)
    RuntimeGeneratedFunction(mod, mod, expr)
end

# TODO ugly initialization hack?
init(mod) = closure_generator(mod, :(x -> x))


macro metatheory_init()
    quote Metatheory.init($__module__) end
end
