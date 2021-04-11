# TODO make it work for every pattern type
# TODO make it yield enodes only: ping pavel and marisa
# TODO STAGE IT! FASTER!
# TODO make it linear, use vectors and positions instead of arrays
# for register memory and for substitutions

using AutoHashEquals

const Register = Symbol

@auto_hash_equals struct ENodePat
    head::Any
    args::Vector{Register}
end

@auto_hash_equals struct Bind 
    reg::Register
    enodepat::ENodePat
end

@auto_hash_equals struct CheckClassEq
    left::Register
    right::Register
end

@auto_hash_equals struct Check
    reg::Register
    val::Any
end

@auto_hash_equals struct CheckType
    reg::Register
    type::Any
end


@auto_hash_equals struct Yield
    yields::Dict{Symbol, Symbol}
end

function compile_pat(reg, p::PatTerm, ctx)
    a = [gensym() for i in 1:length(p.args)]
    binder = Bind(reg, ENodePat(p.head, a))
    return vcat( binder, [compile_pat(reg, p2, ctx) for (reg, p2) in zip(a, p.args)]...)
end

function compile_pat(reg, p::PatVar, ctx)
    if haskey(ctx, p.name)
        return CheckClassEq(reg, ctx[p.name])
    else
        ctx[p.name] = reg
        return []
    end
end

function compile_pat(reg, p::PatTypeAssertion, ctx)
    if haskey(ctx, p.var.name)
        return CheckClassEq(reg, ctx[p.var.name])
    else
        ctx[p.var.name] = reg
        return CheckType(reg, p.type)
    end
end

# TODO works also for ground terms (?)!
# function compile_pat(reg, p::PatLiteral, ctx)
#     return Check(reg, p.val)
# end

function compile_pat(reg, p::PatLiteral, ctx)
    return Bind(reg, ENodePat(p.val, []))
end

function compile_pat(p::Pattern)
    ctx = Dict()
    insns = compile_pat(:start, p, ctx)
    # println("compiled pattern ctx is $ctx")
    return vcat(insns, Yield(ctx)), ctx
end


# =============================================================
# ================== INTERPRETER ==============================
# =============================================================



function interp_unstaged(g, instr::Yield, rest, σ, buf) 
    push!( buf, Dict([key => σ[val] for (key, val) in instr.yields]))
end

function interp_unstaged(g, instr::CheckClassEq, rest, σ, buf) 
    if σ[instr.left] == σ[instr.right]
        next(g, rest, σ, buf)
    end
end

# function interp_unstaged(g, instr::Check, rest, σ, buf) 
#     id, literal = σ[instr.reg]
#     eclass = geteclass(g, id)
#     for n in eclass.nodes 
#         if arity(n) == 0 && n.head == instr.val
#             # TODO bind literal here??
#             next(g, rest, σ, buf)
#         end
#     end 
# end

function interp_unstaged(g, instr::CheckType, rest, σ, buf) 
    id, literal = σ[instr.reg]
    eclass = geteclass(g, id)
    for (i, n) in enumerate(eclass.nodes)
        if arity(n) == 0 && typeof(n.head) <: instr.type
            # TODO bind literal here??
            σ[instr.reg] = (id, i)
            next(g, rest, σ, buf)
        end
    end 
end


function interp_unstaged(g, instr::Bind, rest, σ, buf) 
    ecid, literal = σ[instr.reg]
    for n in g[ecid] 
        if n.head == instr.enodepat.head && length(n.args) == length(instr.enodepat.args)
            for (i,v) in enumerate(instr.enodepat.args)
                σ[v] = (n.args[i], -1)
            end
            next(g, rest, σ, buf)
        end
    end
end

function next(g, rest, σ, buf)
    if length(rest) == 0 
        return nothing 
    end 
    return interp_unstaged(g, rest[1], rest[2:end], σ, buf)
end

function interp_unstaged(g::EGraph, program, id)
    buf = Sub[]
    # memory: a memory value is a tuple (eclassid, enodeposition)
    σ = Dict{Symbol,Tuple{Int64,Int64}}([:start => (id, -1)])
    
    next(g, program, σ, buf)
    return buf
end

function ematch(g::EGraph, p::Pattern, id::Int64)
    program, _ = compile_pat(p)
    out = interp_unstaged(g, program, id)
    # println(out)
    return out
end