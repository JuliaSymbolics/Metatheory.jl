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

function matcher(slot::PatVar)
    pred = slot.predicate 
    if slot.predicate isa Type 
        pred = x -> typeof(x) <: slot.predicate
    end
    function slot_matcher(next, data, bindings)
        !islist(data) && return
        if isassigned(bindings, slot.idx)
            val = bindings[slot.idx]
            if isequal(val, car(data))
                return next(1)
            end
        else
            # Variable is not bound, first time it is found
            # check the predicate            
            if pred(car(data))
                bindings[slot.idx] = car(data)
                next(1)
            end
        end
    end
end

# FIXME implement
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

# FIXME implement
function matcher(segment::PatSegment)
    function segment_matcher(success, data, bindings)
        if isassigned(bindings, segment.idx)
            val = bindings[segment.idx]
            n = trymatchexpr(data, val, 0)
            if !isnothing(n)
                success(n)
            end
        else
            res = nothing

            for i = length(data):-1:0
                subexpr = take_n(data, i)

                if segment.predicate(subexpr)
                    bindings[segment.idx] = subexpr
                    res = success(i)
                    !isnothing(res) && break
            end
            end

            return res
        end
    end
end

function matcher(term::PatTerm)
    matchers = (matcher(operation(term)), map(matcher, arguments(term))...,)
    function term_matcher(success, data, bindings)
        !islist(data) && return nothing
        !istree(car(data)) && return nothing

        function loop(term, matchers′) # Get it to compile faster
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



    

# TODO revise
function instantiate(left, pat::PatTerm, mem)
    ar = arguments(pat)
    args = [ instantiate(left, p, mem) for p in ar] 
    similarterm(typeof(left), operation(pat), args; exprhead=exprhead(pat))
end

instantiate(left, pat::Any, mem) = pat

instantiate(left, pat::AbstractPat, mem) = error("Unsupported pattern ", pat)

function instantiate(left, pat::PatVar, mem)
    # println(left)
    # println(pat)
    # println(mem)
    mem[pat.idx]
end

function instantiate(left, pat::PatSegment, mem)
    # println(left)
    # println(pat)
    # println(mem)
    mem[pat.idx]
end

