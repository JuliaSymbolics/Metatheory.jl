
# SHARED PATTERN SYNTAX STUFF 

# function Pattern(p::Pattern, mod=@__MODULE__, resolve_fun=false)
#     p 
# end

macro pat(ex)
    :(Pattern($(esc(ex)), $__module__, false))
end

macro pat(ex, resolve_fun::Bool)
    :(Pattern($(esc(ex)), $__module__, $resolve_fun))
end
