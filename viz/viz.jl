using GraphViz
using Term

function dot(g::EGraph, dst, diff = Set(), report = nothing)
  tmpl = """digraph {
    compound=true
    clusterrank=local
"""
  report !== nothing && canonicalize!(g, report.cause)
  for (id, eclass) in g.classes
    sg = """    subgraph cluster_$id {
                style=dotted;
                label="EClass $id. Smallest: $(extract!(g, astsize; root=id))"
                fontcolor = gray
                fontsize  = 8
          """
    for (os, node) in enumerate(eclass.nodes)
      label = if node isa ENodeTerm
        node.operation
      else
        node.value
      end
      (mr, style) = if node in diff && get(report.cause, node, missing) !== missing
        pair = get(report.cause, node, missing)
        split(split("$(pair[1].rule) ", "=>")[1], "-->")[1], " color=\"red\""
      else
        " ", ""
      end
      sg *= "      $id.$os [label=<$label<br /><font point-size=\"8\" color=\"gray\">$mr</font>> $style];"
    end
    sg *= "        \n    }\n"

    for (os, node) in enumerate(eclass.nodes)
      node isa ENodeLiteral && continue
      len = length(arguments(node))
      for (ite, child) in enumerate(arguments(node))
        cid = find(g, child)
        nid = if cid == id # graphviz的限制，无法指向eclass外框，所以当指向自己这个框时，退而求其次 ，指向自己这个node。
          "$os:n"
        else
          "1"
        end

        dir = if len == 2 # 从左到右依次，多于3child时用label标顺序
          if ite == 1
            ":sw"
          else
            ":se"
          end
        elseif len == 3
          if ite == 1
            ":sw"
          elseif ite == 2
            ":s"
          else
            ":se"
          end
        else
          ""
        end

        linelabel = if len > 3
          " label=$ite"
        else
          " "
        end
        line = "    $id.$os$dir -> $cid.$nid [lhead=cluster_$cid $linelabel]\n"
        sg *= line
      end
    end
    tmpl *= "\n"
    tmpl *= sg
  end
  tmpl *= "\n}\n"
  graph = GraphViz.Graph(tmpl)
  GraphViz.layout!(graph, engine = "dot")
  graph
end
