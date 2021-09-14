#### Pattern matching
### Matching procedures
# A matcher is a function which takes 3 arguments
# 1. Callback: takes arguments Dictionary × Number of elements matched
# 2. Expression
# 3. Vector of matches debrujin-indexed by pattern variables
#

function matcher(val::Any)
    function literal_matcher(next, data, bindings)
        islist(data) && isequal(car(data), val) ? next(1) : nothing
    end
end

function matcher(slot::PatVar{<:Function})
    function slot_matcher(next, data, bindings)
        println("============ Matching patvar ===========")
        @show slot
        @show data
        @show bindings

        !islist(data) && return
        if isassigned(bindings, slot.idx)
            println("============ Already BOUND ===========")
            val = bindings[slot.idx]
            if isequal(val, car(data))
                return next(1)
            end
        else
            # Variable is not bound, first time it is found
            # check the predicate
            @show slot.predicate
            if slot.predicate(car(data))
                bindings[slot.idx] = car(data)
                next(1)
            end
        end
    end
end


function matcher(slot::PatVar{Type{T}}) where {T}
    function slot_matcher(next, data, bindings)
        println("============ Matching patvar ===========")
        @show slot
        @show data
        @show bindings

        !islist(data) && return
        if isassigned(bindings, slot.idx)
            println("============ Already BOUND ===========")
            val = bindings[slot.idx]
            if isequal(val, car(data))
                return next(1)
            end
        else
            # Variable is not bound, first time it is found
            # check the predicate
            @show T
            if typeof(car(data)) <: T
                bindings[slot.idx] = car(data)
                next(1)
            end
        end
    end
end
# returns n == offset, 0 if failed
function trymatchexpr(data, value, n)
    if !islist(value)
        return n
    elseif islist(value) && islist(data)
        if !islist(data)
            # didn't fully match
            return nothing
        end

        while isequal(car(value), car(data))
            n += 1
            value = cdr(value)
            data = cdr(data)

            if !islist(value)
                return n
            elseif !islist(data)
                return nothing
            end
        end

        return !islist(value) ? n : nothing
    elseif isequal(value, data)
        return n + 1
    end
end

function matcher(segment::PatSegment)
    function segment_matcher(success, data, bindings)
        if isassigned(bindings, segment.idx)
            val = bindings[segment.idx]
            n = trymatchexpr(data, val, 0)
            if n !== nothing
                success(bindings, n)
            end
        else
            res = nothing

            for i = length(data):-1:0
                subexpr = take_n(data, i)

                if segment.predicate(subexpr)
                    res = success(assoc(bindings, segment.name, subexpr), i)
                    if !isnothing(res)
                        break
                end
            end
            end

            return res
        end
    end
end

function matcher(term::PatTerm)
    matchers = (matcher(operation(term)), map(matcher, arguments(term))...,)
    function term_matcher(success, data, bindings)
        println("============ Matching term ===========")
        @show term
        @show data
        @show bindings
    
        !islist(data) && return nothing
        !istree(car(data)) && return nothing

        function loop(term, matchers′) # Get it to compile faster
            println("   === LOOPING ===")
            @show term 
            @show bindings
            @show matchers
            # Base case, no more matchers
            if !islist(matchers′)
                # term is empty
                if !islist(term)
                    # we have correctly matched the term
                    return success(1)
                end
                return nothing
            end
            car(matchers′)(term, bindings) do n
                # recursion case:
                # take the first matcher, on success,
                # keep looping by matching the rest 
                # by removing the first n matched elements 
                # from the term, with the bindings, 
                loop(drop_n(term, n), cdr(matchers′))
            end
        end

        loop(car(data), matchers) # Try to eat exactly one term
    end
end


function (r::RewriteRule)(term)
    mem = Vector(undef, length(r.patvars))
    success(n) = n == 1 ? instantiate(term, r.right, mem) : nothing
        
    # try
        # n == 1 means that exactly one term of the input (term,) was matched
        res =  r.matcher(success, (term,), mem)
        if !isnothing(res)
            println("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅")
        end 
        return res
    # catch err
        # throw(RuleRewriteError(r, term))
    # end
end

function (r::EqualityRule)(x)
    mem = Vector(undef, length(r.patvars))
        if match(r.left, x, mem)
        return instantiate(x, r.right, mem)
    end
    return nothing
end

function (r::DynamicRule)(term)
    mem = Vector(undef, length(r.patvars))
    success(n) = n == 1 ? r.rhs_fun(term, mem, nothing, collect(mem)...) : nothing
        
    # try
        # n == 1 means that exactly one term of the input (term,) was matched
        res =  r.matcher(success, (term,), mem)
        if !isnothing(res)
            println("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅")
        end 
        return res
    # print("matching ")
    
end



# TODO revise
function instantiate(left, pat::PatTerm, mem)
    ar = arguments(pat)
similarterm(typeof(left), operation(pat), 
        [instantiate(left, ar[i], mem) for i in 1:length(ar)]; exprhead=exprhead(pat))
end

instantiate(left, pat::Any, mem) = pat

instantiate(left, pat::Pattern, mem) = error("Unsupported pattern ", pat)

function instantiate(left, pat::PatVar, mem)
    # println(left)
    # println(pat)
    # println(mem)
    mem[pat.idx]
end

