using Pkg
using Metatheory
using Metatheory.EGraphs

to_sexpr_pattern(p::PatLiteral) = p.val
to_sexpr_pattern(p::PatVar) = "?$(p.name)"
function to_sexpr_pattern(p::PatTerm)
    e1 = join([p.head ;  to_sexpr_pattern.(p.args)], ' ')
    "($e1)"
end

to_sexpr(e::Symbol) = e
to_sexpr(e::Expr) = "($(join(to_sexpr.(e.args),' ')))"

function eggify(rules)
    egg_rules = []
    for rule in rules
        l = to_sexpr_pattern(rule.left)
        r = to_sexpr_pattern(rule.right)
        if rule.mode == :symbolic
            push!(egg_rules,"\tvec![rw!( \"$(rule.expr)\" ; \"$l\" => \"$r\" )]")
        elseif rule.mode == :equational
            push!(egg_rules,"\trw!( \"$(rule.expr)\" ; \"$l\" <=> \"$r\" )")
        else
            println("Unsupported Rewrite Mode")
            @assert false
        end

    end
    return join(egg_rules, ",\n")
end
##########################################
# REPLACE WITH YOUR THEORY AND QUERY HERE

theory = @theory begin
    :a * b => :a
    a * b == b * a
end

query = :(a * (b * c))

###########################################

G = EGraph( query )
@time saturate!(G, theory)
ex = extract!(G, astsize)
println( "Best found: $ex")

rust_code =
"""
use egg::{*, rewrite as rw};
//use std::time::Duration;

fn main() {
    let rules : &[Rewrite<SymbolLang, ()>] = &vec![
    $(eggify(theory))
    ].concat();

    let start = "$(to_sexpr(query))".parse().unwrap();
    let runner = Runner::default().with_expr(&start)
        // More options here https://docs.rs/egg/0.6.0/egg/struct.Runner.html
        //.with_iter_limit(10)
        //.with_node_limit(1_000_000)
        //.with_time_limit(Duration::new(30,0))
        .run(rules);
    runner.print_report();
    let mut extractor = Extractor::new(&runner.egraph, AstSize);
    let (best_cost, best_expr) = extractor.find_best(runner.roots[0]);
    println!("best cost: {}, best expr {}", best_cost, best_expr);
}
"""
open("src/main.rs", "w") do f
    write(f, rust_code)
end
