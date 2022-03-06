#### Pattern matching
### Matching procedures
# A matcher is a function which takes 3 arguments
# 1. Callback: takes arguments Dictionary × Number of elements matched
# 2. Expression
# 3. Vector of matches debrujin-indexed by pattern variables
#

using Metatheory: islist, car, cdr, assoc, drop_n, take_n

function matcher(val::Any)
    function literal_matcher(next, data, bindings)
        islist(data) && isequal(car(data), val) ? next(bindings, 1) : nothing
    end
end

function matcher(slot::PatVar)
    pred = slot.predicate
    if slot.predicate isa Type
        pred = x -> typeof(x) <: slot.predicate
    end
    function slot_matcher(next, data, bindings)
        !islist(data) && return
        val = get(bindings, slot.idx, nothing)
        if val !== nothing
            if isequal(val, car(data))
                return next(bindings, 1)
            end
        else
            # Variable is not bound, first time it is found
            # check the predicate            
            if pred(car(data))
                next(assoc(bindings, slot.idx, car(data)), 1)
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
        val = get(bindings, segment.idx, nothing)
        if val !== nothing
            n = trymatchexpr(data, val, 0)
            if !isnothing(n)
                success(bindings, n)
            end
        else
            res = nothing

            for i = length(data):-1:0
                subexpr = take_n(data, i)

                if segment.predicate(subexpr)
                    res = success(assoc(bindings, segment.idx, subexpr), i)
                    !isnothing(res) && break
                end
            end

            return res
        end
    end
end

# TODO REVIEWME
# Try to match both against a function symbol or a function object at the same time.
# Slows things down a bit but lets this matcher work at the same time on both purely symbolic Expr-like object
# and SymbolicUtils-like objects that store function references as operations.
function head_matcher(f::Symbol, mod)
    checkhead = try
        fobj = getproperty(mod, f)
        (x) -> (isequal(x, f) || isequal(x, fobj))
    catch e
        if e isa UndefVarError
            (x) -> isequal(x, f)
        else
            rethrow(e)
        end
    end

    function head_matcher(next, data, bindings)
        h = car(data)
        if islist(data) && checkhead(h)
            next(bindings, 1)
        else
            nothing
        end
    end
end

head_matcher(x, mod) = matcher(x)

function matcher(term::PatTerm)
    op = operation(term)
    matchers = (head_matcher(op, term.mod), map(matcher, arguments(term))...,)
    function term_matcher(success, data, bindings)
        !islist(data) && return nothing
        !istree(car(data)) && return nothing

        function loop(term, bindings′, matchers′) # Get it to compile faster
            # Base case, no more matchers
            if !islist(matchers′)
                # term is empty
                if !islist(term)
                    # we have correctly matched the term
                    return success(bindings′, 1)
                end
                return nothing
            end
            car(matchers′)(term, bindings′) do b, n
                # recursion case:
                # take the first matcher, on success,
                # keep looping by matching the rest 
                # by removing the first n matched elements 
                # from the term, with the bindings, 
                loop(drop_n(term, n), b, cdr(matchers′))
            end
        end

        loop(car(data), bindings, matchers) # Try to eat exactly one term
    end
end


# TODO REVIEWME
function instantiate(left, pat::PatTerm, mem)
    ar = arguments(pat)
    args = [instantiate(left, p, mem) for p in ar]
    T = istree(left) ? typeof(left) : Expr
    similarterm(T, operation(pat), args; exprhead = exprhead(pat))
end

instantiate(left, pat::Any, mem) = pat

instantiate(left, pat::AbstractPat, mem) = error("Unsupported pattern ", pat)

function instantiate(left, pat::PatVar, mem)
    mem[pat.idx]
end

function instantiate(left, pat::PatSegment, mem)
    mem[pat.idx]
end

