using GraphViz
using TermInterface

function dot(g::EGraph, diff = Set(), report = nothing)
  tmpl = """digraph {
    compound=true
    clusterrank=local
"""
  report !== nothing && canonicalize!(g, report.cause)
  for (id, eclass) in g.classes
    sg = """    subgraph cluster_$id {
                style="dotted,rounded,filled";
                colorscheme="set132";
                rank=same;
                label="#$id. Smallest: $(extract!(g, astsize; root=id))"
                fontcolor = gray
                fontsize  = 8
          """
    for (os, node) in enumerate(eclass.nodes)
      label = operation(node)
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
        cluster_id = find(g, child)
        nid = if cluster_id == id # graphviz的限制，无法指向eclass外框，所以当指向自己这个框时，退而求其次 ，指向自己这个node。
          "$os"
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
        line = "    $id.$os$dir -> $cluster_id.$nid [arrowsize=0.5 lhead=cluster_$cluster_id $linelabel]\n"
        sg *= line
      end
    end
    tmpl *= "\n"
    tmpl *= sg
  end
  tmpl *= "\n}\n"
  println(tmpl)
  graph = GraphViz.Graph(tmpl)
  GraphViz.layout!(graph, engine = "dot")
  graph
end
