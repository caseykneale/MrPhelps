abstract type PlanNode ; end
struct Agent <: PlanNode
    fn::Function
    machines::Vector{ String }
end

struct Stash <: PlanNode
    src::String
    machines::Vector{ String }
end

mutable struct PlanGraph
    g::SimpleDiGraph
    nv::Int
    meta::Dict
    bookmarks::Dict
end
PlanGraph() = PlanGraph( SimpleDiGraph(), 0, Dict(), Dict() )

function query_metadata( PG::PlanGraph, category::Symbol, valuestr::String )
    result = [ vtx for ( vtx, nn ) in PG.meta if nn[ category ] == valuestr]
    return result
end

machines( PG::PlanGraph, vtx::Int )     = PG.meta[ vtx ].machines

"""
    add_node!( graph::PlanGraph, item::Union{Agent, Stash} )

Add a node to a graph without any connections.

"""
function add_node!( graph::PlanGraph, item::PlanNode)
    add_vertex!( graph.g )
    graph.nv += 1
end

function add_node!( graph::PlanGraph, item::Pair{Symbol, T} ) where {T<:PlanNode}
    add_vertex!( graph.g )
    graph.nv += 1
    addbookmark!( graph, first( item ) )
    graph.meta[ last(item) ] = graph.nv
end

"""
    attach_node!( graph::PlanGraph, item::Union{Agent, Stash} )

Attach node to current path in a graph.

"""
function attach_node!( graph::PlanGraph, item::PlanNode )
    @assert( graph.nv > 0, "Cannot attach node to an empty graph")
    add_vertex!( graph.g )
    graph.nv += 1
    graph.meta[ graph.nv ] = item
    add_edge!( graph.g, graph.nv - 1, graph.nv )
end

function addbookmark!( graph::PlanGraph, marker::Symbol )
    if haskey(graph.bookmarks, marker)
        @warn("Bookmark $marker already exists - it has been overwritten.")
    end
    graph.bookmarks[ marker ] = graph.nv
end

function attach_node!( graph::PlanGraph, nameitempair::Pair{Symbol, T} ) where {T<:PlanNode}
    @assert( graph.nv > 0, "Cannot attach node to an empty graph")
    add_vertex!( graph.g )
    graph.nv += 1
    addbookmark!( graph, first( nameitempair ) )
    graph.meta[ graph.nv ] = last( nameitempair )
    add_edge!( graph.g, graph.nv - 1, graph.nv )
end

function connect!( graph::PlanGraph, to_str::Symbol, from_str::Symbol )
    add_edge!( graph.g, graph.bookmarks[to_str], graph.bookmarks[from_str] )
end
