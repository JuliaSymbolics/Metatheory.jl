using GraphViz
using Metatheory
using TermInterface

function render_egraph!(io::IO, g::EGraph)
  print(
    io,
    """digraph {
    compound=true
    clusterrank=local
    remincross=false
    ranksep=0.9
""",
  )
  for (_, eclass) in g.classes
    render_eclass!(io, g, eclass)
  end
  println(io, "\n}\n")
end

function render_eclass!(io::IO, g::EGraph, eclass::EClass)
  print(
    io,
    """    subgraph cluster_$(eclass.id) {
         style="dotted,rounded";
         rank=same;
         label="#$(eclass.id). Smallest: $(extract!(g, astsize; root=eclass.id))"
         fontcolor = gray
         fontsize  = 8
   """,
  )

  # if g.root == find(g, eclass.id)
  #   println(io, "         penwidth=2")
  # end

  for (i, node) in enumerate(eclass.nodes)
    render_enode_node!(io, g, eclass.id, i, node)
  end
  print(io, "\n    }\n")

  for (i, node) in enumerate(eclass.nodes)
    render_enode_edges!(io, g, eclass.id, i, node)
  end
  println(io)
end


function render_enode_node!(io::IO, g::EGraph, eclass_id, i::Int, node::AbstractENode)
  label = operation(node)
  # (mr, style) = if node in diff && get(report.cause, node, missing) !== missing
  #   pair = get(report.cause, node, missing)
  #   split(split("$(pair[1].rule) ", "=>")[1], "-->")[1], " color=\"red\""
  # else
  #   " ", ""
  # end
  # sg *= "      $id.$os [label=<$label<br /><font point-size=\"8\" color=\"gray\">$mr</font>> $style];"
  println(io, "      $eclass_id.$i [label=<$label> shape=box style=rounded]")
end

render_enode_edges!(io::IO, g::EGraph, eclass_id, i, node::ENodeLiteral)
function render_enode_edges!(io::IO, g::EGraph, eclass_id, i, node::ENodeTerm)
  len = length(arguments(node))
  for (ite, child) in enumerate(arguments(node))
    cluster_id = find(g, child)
    # The limitation of graphviz is that it cannot point to the eclass outer frame, 
    # so when pointing to the same e-class, the next best thing is to point to the same e-node.
    target_id = "$cluster_id" * (cluster_id == eclass_id ? ".$i" : ".1")

    # In order from left to right, if there are more than 3 children, label the order.
    dir = if len == 2
      ite == 1 ? ":sw" : ":se"
    elseif len == 3
      ite == 1 ? ":sw" : (ite == 2 ? ":s" : ":se")
    else
      ""
    end

    linelabel = len > 3 ? " label=$ite" : " "
    println(io, "    $eclass_id.$i$dir -> $target_id [arrowsize=0.5 lhead=cluster_$cluster_id $linelabel]")
  end
end

function Base.convert(::Type{GraphViz.Graph}, g::EGraph)::GraphViz.Graph
  io = IOBuffer()
  render_egraph!(io, g)
  gs = String(take!(io))
  g = GraphViz.Graph(gs)
  GraphViz.layout!(g; engine = "dot")
  g
end

function Base.show(io::IO, mime::MIME"image/svg+xml", g::EGraph)
  show(io, mime, convert(GraphViz.Graph, g))
end