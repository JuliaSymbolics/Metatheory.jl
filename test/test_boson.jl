boson = @theory begin :c * :cdag => :cdag * :c + 1 end

distr_assoc = Library.distrib(:*, :+) ∪ Library.associativity(:*)

ident = @theory begin
    1 * x => x
end

function boson_expand(ex)
    G = EGraph(ex)
    saturate!(G, boson ∪ distr_assoc, timeout=4)
    extractor = addanalysis!(G, ExtractionAnalysis, astsize_inv)
    ex = extract!(G, extractor)

    G = EGraph(ex)
    saturate!(G, distr_assoc ∪ ident, timeout=4)
    extractor = addanalysis!(G, ExtractionAnalysis, astsize)
    ex = extract!(G, extractor)
    # ex = rewrite(ex, ident)
    println(ex)
    return ex
end

e1 = :(c * c * cdag * cdag)
println(boson_expand(e1))

println(normalize_nocycle(boson_expand, e1))
