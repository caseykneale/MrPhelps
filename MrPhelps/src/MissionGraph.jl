abstract type MissionNode ; end

Base.@kwdef struct Agent <: MissionNode
    fn::Function
    machines::Vector{ String }
    cores::Int = 1
end

Base.@kwdef struct Stash <: MissionNode
    src::Union{ String, FileIterator, Vector{ String } }
    machines::Vector{ String }
    cores::Int = 1
end

Base.@kwdef mutable struct MissionGraph
    g::SimpleDiGraph    = SimpleDiGraph()
    nv::Int             = 0
    meta::Dict          = Dict()
    bookmarks::Dict     = Dict()
end

"""
    enforceDAG( G::SimpleDiGraph )

Performs a quick check to test whether the graph `G` contains no cycles.

"""
enforceDAG( G::SimpleDiGraph ) = @assert( simplecyclescount(G, 10) == 0, "Graph is no longer a DAG! Please use bookmarking features to maintain your workflow." )

machines( MG::MissionGraph, vtx::Int )     = MG.meta[ vtx ].machines

"""
    add_node!( graph::MissionGraph, item::Union{Agent, Stash} )

Add a node to a graph without any connections.

"""
function add_node!( graph::MissionGraph, item::MissionNode)
    add_vertex!( graph.g )
    graph.nv += 1
end

function add_node!( graph::MissionGraph, item::Pair{Symbol, T} ) where {T<:MissionNode}
    add_vertex!( graph.g )
    graph.nv += 1
    addbookmark!( graph, first( item ) )
    graph.meta[ last(item) ] = graph.nv
end

"""
    attach_node!( graph::MissionGraph, item::Union{Agent, Stash} )

Attach node to current path in a graph.

"""
function attach_node!( graph::MissionGraph, item::MissionNode )
    @assert( graph.nv > 0, "Cannot attach node to an empty graph")
    add_vertex!( graph.g )
    graph.nv += 1
    graph.meta[ graph.nv ] = item
    add_edge!( graph.g, graph.nv - 1, graph.nv )
    enforceDAG(graph.g)#ensure we have a DAG
end

function addbookmark!( graph::MissionGraph, marker::Symbol )
    if haskey(graph.bookmarks, marker)
        @warn("Bookmark $marker already exists - it has been overwritten.")
    end
    graph.bookmarks[ marker ] = graph.nv
end

function attach_node!( graph::MissionGraph, nameitempair::Pair{Symbol, T} ) where {T<:MissionNode}
    @assert( graph.nv > 0, "Cannot attach node to an empty graph")
    add_vertex!( graph.g )
    graph.nv += 1
    addbookmark!( graph, first( nameitempair ) )
    graph.meta[ graph.nv ] = last( nameitempair )
    add_edge!( graph.g, graph.nv - 1, graph.nv )
    enforceDAG(graph.g)#ensure we have a DAG
end

function connect!( graph::MissionGraph, to_str::Symbol, from_str::Symbol )
    add_edge!( graph.g, graph.bookmarks[to_str], graph.bookmarks[from_str] )
    enforceDAG(graph.g)#ensure we have a DAG
end

"""
    terminalnodes( G::SimpleDiGraph )

Given an input SimpleDiGraph, return a vector of parent vertices.

"""
terminalnodes(g::SimpleDiGraph) = findall( outdegree(g) .== 0 )

"""
    parentnodes( G::SimpleDiGraph )

Given an input SimpleDiGraph, return a vector of parent vertices.

"""
parentnodes(g::SimpleDiGraph) = findall( indegree(g) .== 0 )

"""
    terminalnodes( G::SimpleDiGraph )

Given an input SimpleDiGraph, return a dictionary of parent and terminal vertices.

"""
terminatingnodes( G::SimpleDiGraph ) =  Dict(   :parentnodes => parentnodes( G ),
                                                :terminalnodes => terminalnodes( G ) )
