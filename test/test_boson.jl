boson = @theory begin
    :c * :cdag => :cdag * :c + 1
    a * (b + c) => (a * b) + (a * c)
    (b + c) * a => (b * a) + (c * a)
    (a * b) * c => a * (b * c)
    a * (b * c) => (a * b) * c
end
# you can also use Library.associativity(:*)
# and Library.distrib(:*, :+)

ident = @theory begin
    1 * x => x
    x * 1 => x
end

function boson_expand(ex)
    G = EGraph(:(c * c * cdag * cdag))
    saturate!(G,boson, timeout=4)
    extractor = addanalysis!(G, ExtractionAnalysis, astsize_inv)
    ex = extract!(G, extractor)
end
