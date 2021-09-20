using Metatheory
using Metatheory.EGraphs
using Metatheory.Library

using Metatheory: @rule


boson = @theory begin :c * :cdag => :cdag * :c + 1 end

distr_assoc = distrib(:*, :+) ∪ associativity(:*)

ident = @rule 1 * x => x 

ident_comm = @rule 1 * x => x * 1


function boson_expand(ex)
    params = SaturationParams(timeout=4)
    G = EGraph(ex)
    saturate!(G, boson ∪ distr_assoc ∪ [ident_comm], params)
    ex = extract!(G, astsize_inv)

    G = EGraph(ex)
    rep = saturate!(G, distr_assoc ∪ [ident], params)
    println(rep)
    ex = extract!(G, astsize)
    return ex
end

e1 = :(c * c * cdag * cdag)

# TODO add expected result
println(boson_expand(e1))
println(normalize_nocycle(boson_expand, e1))
