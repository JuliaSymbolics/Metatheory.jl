use egg::{*, rewrite as rw};
//use std::time::Duration;
fn main() {
    let rules : &[Rewrite<SymbolLang, ()>] = &vec![
    	vec![rw!( "p ∨ q ∨ r => p ∨ q ∨ r" ; "(∨ (∨ ?p ?q) ?r)" => "(∨ ?p (∨ ?q ?r))" )],
	vec![rw!( "p ∨ q => q ∨ p" ; "(∨ ?p ?q)" => "(∨ ?q ?p)" )],
	vec![rw!( "p ∨ p => p" ; "(∨ ?p ?p)" => "?p" )],
	vec![rw!( "p ∨ true => true" ; "(∨ ?p true)" => "true" )],
	vec![rw!( "p ∨ false => p" ; "(∨ ?p false)" => "?p" )],
	vec![rw!( "p ∧ q ∧ r => p ∧ q ∧ r" ; "(∧ (∧ ?p ?q) ?r)" => "(∧ ?p (∧ ?q ?r))" )],
	vec![rw!( "p ∧ q => q ∧ p" ; "(∧ ?p ?q)" => "(∧ ?q ?p)" )],
	vec![rw!( "p ∧ p => p" ; "(∧ ?p ?p)" => "?p" )],
	vec![rw!( "p ∧ true => p" ; "(∧ ?p true)" => "?p" )],
	vec![rw!( "p ∧ false => false" ; "(∧ ?p false)" => "false" )],
	vec![rw!( "¬p ∨ q => ¬p ∧ ¬q" ; "(¬ (∨ ?p ?q))" => "(∧ (¬ ?p) (¬ ?q))" )],
	vec![rw!( "¬p ∧ q => ¬p ∨ ¬q" ; "(¬ (∧ ?p ?q))" => "(∨ (¬ ?p) (¬ ?q))" )],
	vec![rw!( "p ∧ q ∨ r => p ∧ q ∨ p ∧ r" ; "(∧ ?p (∨ ?q ?r))" => "(∨ (∧ ?p ?q) (∧ ?p ?r))" )],
	vec![rw!( "p ∨ q ∧ r => p ∨ q ∧ p ∨ r" ; "(∨ ?p (∧ ?q ?r))" => "(∧ (∨ ?p ?q) (∨ ?p ?r))" )],
	vec![rw!( "p ∧ p ∨ q => p" ; "(∧ ?p (∨ ?p ?q))" => "?p" )],
	vec![rw!( "p ∨ p ∧ q => p" ; "(∨ ?p (∧ ?p ?q))" => "?p" )],
	vec![rw!( "p ∧ ¬p ∨ q => p ∧ q" ; "(∧ ?p (∨ (¬ ?p) ?q))" => "(∧ ?p ?q)" )],
	vec![rw!( "p ∨ ¬p ∧ q => p ∨ q" ; "(∨ ?p (∧ (¬ ?p) ?q))" => "(∨ ?p ?q)" )],
	vec![rw!( "p ∧ ¬p => false" ; "(∧ ?p (¬ ?p))" => "false" )],
	vec![rw!( "p ∨ ¬p => true" ; "(∨ ?p (¬ ?p))" => "true" )],
	vec![rw!( "¬¬p => p" ; "(¬ (¬ ?p))" => "?p" )],
	vec![rw!( "p == ¬p => false" ; "(== ?p (¬ ?p))" => "false" )],
	vec![rw!( "p == p => true" ; "(== ?p ?p)" => "true" )],
	vec![rw!( "p == q => ¬p ∨ q ∧ ¬q ∨ p" ; "(== ?p ?q)" => "(∧ (∨ (¬ ?p) ?q) (∨ (¬ ?q) ?p))" )],
	vec![rw!( "p => q => ¬p ∨ q" ; "(=> ?p ?q)" => "(∨ (¬ ?p) ?q)" )],
	vec![rw!( "true == false => false" ; "(== true false)" => "false" )],
	vec![rw!( "false == true => false" ; "(== false true)" => "false" )],
	vec![rw!( "true == true => true" ; "(== true true)" => "true" )],
	vec![rw!( "false == false => true" ; "(== false false)" => "true" )],
	vec![rw!( "true ∨ false => true" ; "(∨ true false)" => "true" )],
	vec![rw!( "false ∨ true => true" ; "(∨ false true)" => "true" )],
	vec![rw!( "true ∨ true => true" ; "(∨ true true)" => "true" )],
	vec![rw!( "false ∨ false => false" ; "(∨ false false)" => "false" )],
	vec![rw!( "true ∧ true => true" ; "(∧ true true)" => "true" )],
	vec![rw!( "false ∧ true => false" ; "(∧ false true)" => "false" )],
	vec![rw!( "true ∧ false => false" ; "(∧ true false)" => "false" )],
	vec![rw!( "false ∧ false => false" ; "(∧ false false)" => "false" )],
	vec![rw!( "¬true => false" ; "(¬ true)" => "false" )],
	vec![rw!( "¬false => true" ; "(¬ false)" => "true" )]
    ].concat();

    let start = "(∨ (¬ (∧ (∧ (∨ (¬ p) q) (∨ (¬ r) s)) (∨ p r))) (∨ q s))".parse().unwrap();
    let runner = Runner::default().with_expr(&start)
        // More options here https://docs.rs/egg/0.6.0/egg/struct.Runner.html
        .with_iter_limit(22)
        .with_node_limit(15000)
        .run(rules);
    runner.print_report();
    let mut extractor = Extractor::new(&runner.egraph, AstSize);
    let (best_cost, best_expr) = extractor.find_best(runner.roots[0]);
    println!("best cost: {}, best expr {}", best_cost, best_expr);
}
