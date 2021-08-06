
function next(p::Program, n, σ, pc)
    stage(p, p.instructions[pc+1], n, σ, pc+1)
end

function stage(p::Program, instr::Yield, n, σ, pc)
    quote
        sourcenode = $(n[p.first_nonground])
        ecs = [ $([σ[reg] for reg in instr.yields]...) ]
        nodes = [ $([n[reg] for reg in instr.yields]...) ]
        push!(_buf, Sub(sourcenode, ecs, nodes)) 
    end
end

function stage(p::Program, instr::CheckClassEq, n, σ, pc)
    quote
        l = $(σ[instr.left])
        r = $(σ[instr.right]) 
        if l == r 
            $(next(p, n, σ, pc))
        end
    end
end

function stage(p::Program, instr::CheckType, n, σ, pc)
    id = gensym(:id)
    eclass = gensym(:eclass)
    enode = gensym(:enode)
    quote
        $id = $(σ[instr.reg])
        $eclass = _egraph[$id]

        for $enode in $eclass 
            if arity($enode) == 0 && typeof($enode.head) <: $(instr.type)
                $(σ[instr.reg]) = $id
                $(n[instr.reg]) = $enode
                $(next(p, n, σ, pc))
            end
        end
    end
end

function stage(p::Program, instr::Lookup, n, σ, pc)
    ecid = gensym(:ecid)
    quote
        $ecid = lookup_pat(_egraph, $(instr.p))
        if $ecid isa EClassId
            # println("found $(instr.p) in $ecid")
            $(σ[instr.reg]) = $ecid
            $(next(p, n, σ, pc))
        end
    end
end


function stage(p::Program, instr::Bind, n, σ, pc)
    enode = gensym(:enode)
    quote
        ecid = $(σ[instr.reg])
        eclass = _egraph[ecid]
    
        for $enode in eclass.nodes
            if $enode.head == $(QuoteNode(instr.enodepat.head)) && length($enode.args) == $(length(instr.enodepat.args))
                $(n[instr.reg]) = $enode
                $(
                    begin
                        for (j,v) in enumerate(instr.enodepat.args)
                            σ[v] = :($enode.args[$j])
                        end
                        next(p, n, σ, pc) 
                    end
                )
            end
        end
    end
end

const Code = Union{Expr, Symbol}

function stage(p::Program)
    n = Code[gensym("node$i") for i in 1:p.memsize]
    σ = Code[gensym("reg$i") for i in 1:p.memsize]

    σ[p.first_nonground] = :_start

    staged_instructions = stage(p, p.instructions[1], n, σ, 1)
    
    :( (_egraph, _start) -> begin
            # initialize the registers 
            $(Expr(:block, [ :($(n[i]) = nothing) for i in 1:p.memsize]...))
            _buf = Sub[]
            $staged_instructions
            return _buf
        end
    )
end