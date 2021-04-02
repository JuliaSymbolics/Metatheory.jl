boson = @theory begin :c * :cdag => :cdag * :c + 1 end

distr_assoc = distrib(:*, :+) ∪ associativity(:*)

ident = @theory begin
    1 * x => x
end

function boson_expand(ex)
    params = SaturationParams(timeout=4)
    G = EGraph(ex)
    saturate!(G, boson ∪ distr_assoc, params)
    ex = extract!(G, astsize_inv)

    G = EGraph(ex)
    saturate!(G, distr_assoc ∪ ident, params)
    ex = extract!(G, astsize)
    # ex = rewrite(ex, ident)
    # println(ex)
    return ex
end

e1 = :(c * c * cdag * cdag)

# TODO add expected result
# println(boson_expand(e1))
# println(normalize_nocycle(boson_expand, e1))
