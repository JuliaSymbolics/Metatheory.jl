using Metatheory
using Metatheory.EGraphs

to_sexpr_pattern(p::PatLiteral) = "$(p.val)"
to_sexpr_pattern(p::PatVar) = "?$(p.name)"
function to_sexpr_pattern(p::PatTerm)
  e1 = join([p.head; to_sexpr_pattern.(p.args)], ' ')
  "($e1)"
end

to_sexpr(e::Symbol) = e
to_sexpr(e::Int64) = e
to_sexpr(e::Expr) = "($(join(to_sexpr.(e.args),' ')))"

function eggify(rules)
  egg_rules = []
  for rule in rules
    l = to_sexpr_pattern(rule.left)
    r = to_sexpr_pattern(rule.right)
    if rule isa SymbolicRule
      push!(egg_rules, "\tvec![rw!( \"$(rule.left) => $(rule.right)\" ; \"$l\" => \"$r\" )]")
    elseif rule isa EqualityRule
      push!(egg_rules, "\trw!( \"$(rule.left) == $(rule.right)\" ; \"$l\" <=> \"$r\" )")
    else
      println("Unsupported Rewrite Mode")
      @assert false
    end

  end
  return join(egg_rules, ",\n")
end

function rust_code(theory, query, params = SaturationParams())
  """
  use egg::{*, rewrite as rw};
  //use std::time::Duration;
  fn main() {
      let rules : &[Rewrite<SymbolLang, ()>] = &vec![
      $(eggify(theory))
      ].concat();

      let start = "$(to_sexpr(cleanast(query)))".parse().unwrap();
      let runner = Runner::default().with_expr(&start)
          // More options here https://docs.rs/egg/0.6.0/egg/struct.Runner.html
          .with_iter_limit($(params.timeout))
          .with_node_limit($(params.enodelimit))
          .run(rules);
      runner.print_report();
      let mut extractor = Extractor::new(&runner.egraph, AstSize);
      let (best_cost, best_expr) = extractor.find_best(runner.roots[0]);
      println!("best cost: {}, best expr {}", best_cost, best_expr);
  }
  """
end
