abstract type SaturationGoal end

reached(g::EGraph, goal::Nothing) = false
reached(g::EGraph, goal::SaturationGoal) = false

"""
This goal is reached when the `exprs` list of expressions are in the 
same equivalence class.
"""
struct EqualityGoal <: SaturationGoal
    exprs::Vector{Any}
    ids::Vector{EClassId}
    function EqualityGoal(exprs, eclasses) 
        @assert length(exprs) == length(eclasses) && length(exprs) != 0 
        new(exprs, eclasses)
    end
end

function reached(g::EGraph, goal::EqualityGoal)
    all(x -> in_same_class(g, goal.ids[1], x), @view goal.ids[2:end])
end

"""
Boolean valued function as an arbitrary saturation goal.
User supplied function must take an [`EGraph`](@ref) as the only parameter.
"""
struct FunctionGoal <: SaturationGoal
    fun::Function
end

function reached(g::EGraph, goal::FunctionGoal)::Bool
    goal.fun(g)    
end

mutable struct Report
    reason::Union{Symbol, Nothing}
    egraph::EGraph
    iterations::Int
    to::TimerOutput
end

Report() = Report(nothing, EGraph(), 0, TimerOutput())
Report(g::EGraph) = Report(nothing, g, 0, TimerOutput())



# string representation of timedata
function Base.show(io::IO, x::Report)
    g = x.egraph
    println(io, "Equality Saturation Report")
    println(io, "=================")
    println(io, "\tStop Reason: $(x.reason)")
    println(io, "\tIterations: $(x.iterations)")
    # println(io, "\tRules applied: $(g.age)")
    println(io, "\tEGraph Size: $(g.numclasses) eclasses, $(length(g.memo)) nodes")
    print_timer(io, x.to)
end

"""
Configurable Parameters for the equality saturation process.
"""
@with_kw mutable struct SaturationParams
    timeout::Int = 8
    timelimit::Period = Second(-1)
    # default sizeout. TODO make this bytes
    # sizeout::Int = 2^14
    matchlimit::Int = 5000
    eclasslimit::Int = 5000
    enodelimit::Int = 15000
    goal::Union{Nothing, SaturationGoal} = nothing
    stopwhen::Function = ()->false
    scheduler::Type{<:AbstractScheduler} = BackoffScheduler
    schedulerparams::Tuple=()
    threaded::Bool = false
    timer::Bool = true
    printiter::Bool = false
    simterm::Function = similarterm
end

struct Match
    rule::AbstractRule 
    # the rhs pattern to instantiate 
    pat_to_inst
    # the substitution
    sub::Sub 
    # the id the matched the lhs  
    id::EClassId
end

const MatchesBuf = Vector{Match}

function cached_ids(g::EGraph, p::AbstractPat)# ::Vector{Int64}
    if isground(p)
        id = lookup_pat(g, p)
        !isnothing(id) && return [id]
    else
        return collect(keys(g.classes))
    end
    return []
end

function cached_ids(g::EGraph, p) # p is a literal
    id = lookup(g, ENodeLiteral(p))
    !isnothing(id) && return [id]
    return []
end

# FIXME 
function cached_ids(g::EGraph, p::PatTerm)
    # println("pattern $p, $(p.head)")
    # println("all ids")
    # keys(g.classes) |> println
    # println("cached symbols")
    # cached = get(g.symcache, p.head, Set{Int64}())
    # println("symbols where $(p.head) appears")
    # appears = Set{Int64}() 
    # for (id, class) ∈ g.classes 
    #     for n ∈ class 
    #         if n.head == p.head
    #             push!(appears, id) 
    #         end
    #     end
    # end
    # # println(appears)
    # if !(cached == appears)
    #     @show cached 
    #     @show appears
    # end

    collect(keys(g.classes))
    # cached
    # get(g.symcache, p.head, [])
end

# function cached_ids(g::EGraph, p::PatLiteral)
#     get(g.symcache, p.val, [])
# end

function (r::SymbolicRule)(g::EGraph, id::EClassId)
    ematch(g, r.ematch_program, id) .|> sub -> Match(r, r.right, sub, id)
end

function (r::DynamicRule)(g::EGraph, id::EClassId)
    ematch(g, r.ematch_program, id) .|> sub -> Match(r, nothing, sub, id)
end

function (r::BidirRule)(g::EGraph, id::EClassId)
    vcat(ematch(g, r.ematch_program_l, id) .|> sub -> Match(r, r.right, sub, id),
        ematch(g, r.ematch_program_r, id) .|> sub -> Match(r, r.left, sub, id))
end


"""
Returns an iterator of `Match`es.
"""
function eqsat_search!(egraph::EGraph, theory::Vector{<:AbstractRule},
    scheduler::AbstractScheduler, report; threaded=false)
    match_groups = Vector{Match}[]
    function pmap(f, xs) 
        # const propagation should be able to optimze one of the branch away
        if threaded
            # # try to divide the work evenly between threads without adding much overhead
            # chunks = Threads.nthreads() * 10
            # basesize = max(length(xs) ÷ chunks, 1)
            # ThreadsX.mapi(f, xs; basesize=basesize) 
            ThreadsX.map(f, xs)
        else
            map(f, xs)
        end
    end

    inequalities = filter(Base.Fix2(isa, UnequalRule), theory)
    # never skip contradiction checks
    append_time = TimerOutput()
    for rule ∈ inequalities
        @timeit report.to repr(rule) begin
            ids = cached_ids(egraph, rule.left)
            rule_matches = pmap(i -> rule(egraph, i), ids)
            @timeit append_time "appending matches" begin
                append!(match_groups, rule_matches)
            end
        end
    end

    other_rules = filter(theory) do rule 
        !(rule isa UnequalRule)
    end
    for rule ∈ other_rules 
        @timeit report.to repr(rule) begin
            # don't apply banned rules
            if !cansearch(scheduler, rule)
                # println("skipping banned rule $rule")
                continue
            end
            ids = cached_ids(egraph, rule.left)
            rule_matches = pmap(i -> rule(egraph, i), ids)

            n_matches = isempty(rule_matches) ? 0 : sum(length, rule_matches)
            # @show (rule, n_matches)
            can_yield = inform!(scheduler, rule, n_matches)
            if can_yield
                @timeit append_time "appending matches" begin
                    append!(match_groups, rule_matches)
                end
            end
        end
    end

    # @timeit append_time "appending matches" begin
    #     result = reduce(vcat, match_groups) # this should be more efficient than multiple appends
    # end
    merge!(report.to, append_time, tree_point=["Search"])

    return Iterators.flatten(match_groups)
    # return result
end
    

function (rule::UnequalRule)(g::EGraph, match::Match; simterm=similarterm)
    lc = match.id
    rinst = instantiate(g, match.pat_to_inst, match.sub, rule; simterm=simterm)
    rc, node = addexpr!(g, rinst)

    if find(g, lc) == find(g, rc)
        @log "Contradiction!" rule
        return :contradiction
    end
    return nothing
end

function (rule::SymbolicRule)(g::EGraph, match::Match; simterm=similarterm)
    rinst = instantiate(g, match.pat_to_inst, match.sub, rule; simterm=simterm)
    rc, node = addexpr!(g, rinst)
    merge!(g, match.id, rc.id)
    return nothing
end


function (rule::DynamicRule)(g::EGraph, match::Match; simterm=similarterm)
    f = rule.rhs_fun
    actual_params = [instantiate(g, PatVar(v, i, alwaystrue), match.sub, rule) for (i, v) in enumerate(rule.patvars)]
    r = f(g[match.id], match.sub, g, actual_params...)
    isnothing(r) && return nothing
    rc, node = addexpr!(g, r)
    merge!(g, match.id, rc.id)
    return nothing
end


function eqsat_apply!(g::EGraph, matches, rep::Report, params::SaturationParams)
    i = 0
    # println.(matches)
    for match ∈ matches
        i += 1

        # if params.eclasslimit > 0 && g.numclasses > params.eclasslimit
        #     @log "E-GRAPH SIZEOUT"
        #     rep.reason = :eclasslimit
        #     return
        # end

        if reached(g, params.goal)
            @log "Goal reached"
            rep.reason = :goalreached
            return
        end


        rule = match.rule
        # println("applying $rule")

        halt_reason = rule(g, match; simterm=params.simterm)
        if (halt_reason !== nothing)
            rep.reason = halt_reason
            return 
        end 

        # println(rule)
        # println(sub)
        # println(l); println(r)
        # display(egraph.classes); println()
    end
end

import ..@log


"""
Core algorithm of the library: the equality saturation step.
"""
function eqsat_step!(g::EGraph, theory::Vector{<:AbstractRule}, curr_iter,
        scheduler::AbstractScheduler, match_hist::MatchesBuf, 
        params::SaturationParams, report)

    instcache = Dict{AbstractRule, Dict{Sub, EClassId}}()

    setiter!(scheduler, curr_iter)

    matches = @timeit report.to "Search" eqsat_search!(g, theory, scheduler, report; threaded=params.threaded)

    # matches = setdiff!(matches, match_hist)

    @timeit report.to "Apply" eqsat_apply!(g, matches, report, params)
    

    # union!(match_hist, matches)

    if report.reason === nothing && cansaturate(scheduler) && isempty(g.dirty)
        report.reason = :saturated
    end
    @timeit report.to "Rebuild" rebuild!(g)
   
    return report, g
end

"""
Given an [`EGraph`](@ref) and a collection of rewrite rules,
execute the equality saturation algorithm.
"""
function saturate!(g::EGraph, theory::Vector{<:AbstractRule}, params=SaturationParams())
    curr_iter = 0

    sched = params.scheduler(g, theory, params.schedulerparams...)
    match_hist = MatchesBuf()
    report = Report(g)

    start_time = Dates.now().instant

    !params.timer && disable_timer!(report.to)
    timelimit = params.timelimit > Second(0)
    

    while true
        curr_iter+=1

        params.printiter && @info("iteration ", curr_iter)

        report, egraph = eqsat_step!(g, theory, curr_iter, sched, match_hist, params, report)

        elapsed = Dates.now().instant - start_time

        if timelimit && params.timelimit <= elapsed
            report.reason = :timelimit
            break
        end

        # report.reason == :matchlimit && break
        if !(report.reason isa Nothing)
            break
        end

        if curr_iter >= params.timeout 
            report.reason = :timeout
            break
        end

        if params.eclasslimit > 0 && g.numclasses > params.eclasslimit 
            # println(params.eclasslimit)
            report.reason = :eclasslimit
            break
        end

        if reached(g, params.goal)
            report.reason = :goalreached
            break
        end
    end
    report.iterations = curr_iter
    @log report

    return report
end

function areequal(theory::Vector, exprs...; params=SaturationParams())
    g = EGraph(exprs[1])
    areequal(g, theory, exprs...; params=params)
end

function areequal(g::EGraph, t::Vector{<:AbstractRule}, exprs...; params=SaturationParams())
    @log "Checking equality for " exprs
    if length(exprs) == 1; return true end
    # rebuild!(G)

    @log "starting saturation"

    n = length(exprs)
    ids = Vector{EClassId}(undef, n)
    nodes = Vector{AbstractENode}(undef, n)
    for i ∈ 1:n
        ec, node = addexpr!(g, exprs[i])
        ids[i] = ec.id
        nodes[i] = node
    end

    goal = EqualityGoal(collect(exprs), ids)
    
    # alleq = () -> (all(x -> in_same_set(G.uf, ids[1], x), ids[2:end]))

    params.goal = goal
    # params.stopwhen = alleq

    report = saturate!(g, t, params)

    # display(g.classes); println()
    if !(report.reason === :saturated) && !reached(g, goal)
        return missing # failed to prove
    end
    return reached(g, goal)
end

macro areequal(theory, exprs...)
    esc(:(areequal($theory, $exprs...))) 
end

macro areequalg(G, theory, exprs...)
    esc(:(areequal($G, $theory, $exprs...)))
end
