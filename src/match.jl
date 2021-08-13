using TermInterface

function match(p::PatVar, x, mem)
    if isassigned(mem, p.idx)
        return x == mem[p.idx]
    end 
    mem[p.idx] = x
    true
end

match(p::PatLiteral{T}, x::T, mem) where {T} = (p.val == x)
match(p::PatLiteral, x, mem) = false

function match(p::PatTypeAssertion, x::T, mem) where {T}
    if T <: p.type
        return match(p.var, x, mem)
    end 
    false
end

# TODO PatSplatVar

match(p::PatEquiv, x, mem) = error("PatEquiv can only be used in EGraphs rewriting")

function match(p::PatTerm, x, mem)
    !isterm(typeof(x)) && (return false)
    if gethead(p) == gethead(x) && arity(p) == arity(x)
        p_args, x_args = getargs(p), getargs(x)
        for i in 1:arity(p)
            !match(p_args[i], x_args[i], mem) && (return false)
        end
        return true
    end
    false
end

# =================================================

# TODO instantiate

# =================================================

function (r::RewriteRule)(x)
    mem = Vector(undef, length(r.patvars))
    if match(r.left, x, mem)
        return instantiate(x, r.right, mem)
    end
    return nothing
end

function (r::EqualityRule)(x)
    mem = Vector(undef, length(r.patvars))
    if match(r.left, x, mem)
        return instantiate(x, r.right, mem)
    end
    return nothing
end

function (r::DynamicRule)(x)
    # print("matching ")
    # display(r)
    # println(" against $x")
    mem = Vector(undef, length(r.patvars))
    if match(r.left, x, mem)
        # println("matched")
        return r.rhs_fun(x, mem, nothing, collect(mem)...)
    end
    # println("failed")
    return nothing
end

# TODO revise
function instantiate(left, pat::PatTerm, mem)
    ar = getargs(pat)
    similarterm(typeof(left), pat.head, 
        [instantiate(left, ar[i], mem) for i in 1:length(ar)])
end

instantiate(left, pat::PatLiteral, mem) = pat.val

function instantiate(left, pat::PatVar, mem)
    # println(left)
    # println(pat)
    # println(mem)
    mem[pat.idx]
end