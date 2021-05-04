using Catlab
using Catlab.Theories
using Catlab.Syntax
using Metatheory, Metatheory.EGraphs

# ============================================================

# GATExpr => normal Expr in MT
function gat_to_expr(ex::ObExpr{:generator})
    @assert length(ex.args) == 1
    return ex.args[1]
end
function gat_to_expr(ex::ObExpr{H}) where {H}
    return Expr(:call, head(ex), map(gat_to_expr, ex.args)...)
end
function gat_to_expr(ex::HomExpr{H}) where {H}
    @assert length(ex.type_args) == 2
    expr = Expr(:call, head(ex), map(gat_to_expr, ex.args)...)
    type_ex = Expr(:call, :Hom, map(gat_to_expr, ex.type_args)...)
    return Expr(:call, :~, expr, type_ex)
end
function gat_to_expr(ex::HomExpr{:generator})
    f = ex.args[1]
    type_ex = Expr(:call, :Hom, map(gat_to_expr, ex.type_args)...)
    return Expr(:call, :~, f, type_ex)
end


const Code = Union{Symbol, Expr}

# ============================================================

# infer type of morphisms and objects
# a morphism f: A → B will be typed as f ~ Hom(A, B)
# an object A will be typed as Ob(A)
function get_concrete_type_expr(theory, x::Symbol, ctx, type_tags = Dict{Code, Code}())
    t = ctx[x]
    t === :Ob && (t = Expr(:call, :Ob, x))
    type_tags[x] = t
    return t
end
function get_concrete_type_expr(theory, x::Expr, ctx, type_tags = Dict{Code, Code}())
    @assert x.head == :call
    f = x.args[1]
    rest = x.args[2:end]
    # recursion case - inductive step (?)
    for a in rest
        t = get_concrete_type_expr(theory, a, ctx, type_tags)
        type_tags[a] = t
        # println("$a ~ $t")
    end
    # get the corresponding TermConstructor from theory.terms
    # for each arg in `rest`, instantiate the term.params with term.context
    # instantiate term.typ

    type_tags[x] = gat_type_inference(theory, f, [type_tags[a] for a in rest])
    # println("$x ~ $(type_tags[x])")
    return type_tags[x]
end

function is_context_match(t, head, args)
    # t isa TermConstructor
    println(repeat("=", 30))
    println("is_context_match")
    @show t 
    @show head
    @show args
    println(repeat("=", 30))

    t.name !== head && return false
    n = length(t.params)
    n != length(args) && return false
    for i = 1:n
        if t.context[t.params[i]] === :Ob 
            if (args[i] isa Symbol) || args[i].args[1] !== :Ob
                return false
            end
        else
            if !(args[i] isa Symbol) && args[i].args[1] === :Ob
                return false
            end
        end
    end
    return true
end

function gat_type_inference(theory, head, args)
    for t in theory.terms
        if is_context_match(t, head, args)
            @show t, head, args
            return gat_type_inference(t, head, args)
        end
    end
    @show theory, head, args
    @error "can not find $(Expr(:call, head, args...)) in the theory"
end

function gat_type_inference(t::GAT.TermConstructor, head, args)
    @assert length(t.params) == length(args) && t.name === head
    bindings = Dict()
    for i = 1:length(args)
        template = t.context[t.params[i]]
        template === :Ob && (template = t.params[i])
        # @show template
        update_bindings!(bindings, template, args[i])
    end
    # @show bindings
    r = GAT.replace_types(bindings, t)
    if r.typ == :Ob 
        return Expr(:call, :Ob, Expr(:call, head, args...))
    else 
        return r.typ
    end
end
function update_bindings!(bindings, template::Expr, target::Expr)
    for i = 1:length(template.args)
        update_bindings!(bindings, template.args[i], target.args[i])
    end
end
function update_bindings!(bindings, template, target)
    bindings[template] = target
end


function tag_expr(x::Expr, axiom, theory)
    t = get_concrete_type_expr(theory, x, axiom.context)
    start = x.head == :call ? 2 : 1 

    nargs = Any[tag_expr(y, axiom, theory) for y in x.args[start:end]]

    if start == 2
        pushfirst!(nargs, x.args[1])
    end

    z = Expr(x.head, nargs...)

    (t === :Ob || t == x) && (return z)
    :($z ~ $t)
end

function tag_expr(x::Symbol, axiom, theory)
    t = get_concrete_type_expr(theory, x, axiom.context)
    (t === :Ob || t == x) && (return x)
    return (t == x ? x : :($x ~ $t))
    # :($x ~ $t)
end

# ============================================================
# Convert Catlab Axioms to rules
# ============================================================

function axiom_to_rule(theory, axiom)
    op = axiom.name
    @assert op == :(==)
    lhs = tag_expr(axiom.left, axiom, tt) |> Pattern
    rhs = tag_expr(axiom.right, axiom, tt) |> Pattern

    pvars = patvars(lhs) ∪ patvars(rhs)
    extravars = setdiff(pvars, patvars(lhs) ∩ patvars(rhs))
    if !isempty(extravars)
        if extravars ⊆ patvars(lhs)
            println(lhs)
            println(rhs)
            return RewriteRule(lhs, rhs)
        else 
            return RewriteRule(rhs, lhs)
        end
    end
    # println("$lhs == $rhs")
    EqualityRule(lhs, rhs)
end


function gen_theory(t::Catlab.GAT.Theory)
    [axiom_to_rule(t, ax) for ax in t.axioms]
end


