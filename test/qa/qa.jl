using JET
using Metatheory
using SciMLTesting

run_qa(
  Metatheory;
  aqua_kwargs = (; piracies = (; treat_as_own = (Expr,))),
  reexports_allow = (:EClassId, :arity, :merge!),
)
