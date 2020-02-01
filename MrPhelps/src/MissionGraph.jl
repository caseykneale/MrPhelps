abstract type MissionNode ; end

#Base.@kwdef 
mutable struct Agent <: MissionNode
    fn                  ::Union{ Thunk, Function }
    machines            ::Vector{String}
    priority            ::Int
    min_workers         ::Int
    max_workers         ::Int
    dispatched_workers  ::Vector{Int}
end
Agent( fn::Union{Thunk,Function}, machines::Vector{String} ) = Agent( fn, machines, 1, 1, 1, [] )
Agent( fn::Union{Thunk,Function}, machines::Vector{String}, maxworkers::Int ) = Agent( fn, machines, 1, 1, maxworkers, [] )

mutable struct Stash <: MissionNode
    src                 ::String
    fn                  ::Union{Nothing, Thunk, Function}
    machines            ::Vector{ String }
    priority            ::Int
    min_workers         ::Int
    max_workers         ::Int
    dispatched_workers  ::Vector{ Int }
end

Stash( src::String, machines::Vector{String} ) = Stash( src, nothing, machines, 1, 1, 1, [] )
Stash( src::String, machines::Vector{String}, maxworkers::Int ) = Stash( src, nothing, machines, 1, 1, maxworkers,[] )
Stash( src::String, fn::Union{Thunk,Function}, machines::Vector{String} ) = Stash( src, fn, machines, 1, 1, 1, [] )
Stash( src::String, fn::Union{Thunk,Function}, machines::Vector{String}, maxworkers::Int ) = Stash( src, fn, machines, 1, 1, maxworkers,[] )

mutable struct StashIterator <: MissionNode
    iter            ::Union{FileIterator, Vector{ String } }
    iteratorstate   ::Any
    stash           ::Stash
end
function StashIterator( src_iterator::Union{FileIterator,Vector{String}}, stash::Stash )
    result, state = src_iterator
    stash.src = result
    return StashIterator( src_iterator, state, stash )
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

machines( MG::MissionGraph, vtx::Int ) = MG.meta[ vtx ].machines

"""
    add_node!( graph::MissionGraph, item::Union{Agent, Stash} )

Add a node to a graph without any connections.

"""
function add_node!( graph::MissionGraph, item::MissionNode)
    add_vertex!( graph.g )
    graph.nv += 1
    graph.meta[ graph.nv ] = item
end

function add_node!( graph::MissionGraph, item::Pair{Symbol, T} ) where {T<:MissionNode}
    add_vertex!( graph.g )
    graph.nv += 1
    addbookmark!( graph, first( item ) )
    graph.meta[ graph.nv ] = last(item)
end

"""
    attach_node!( graph::MissionGraph, item::Union{Agent, Stash} )

Attach node to current path in a graph.

"""
function attach_node!( graph::MissionGraph, item::MissionNode )
    @assert( graph.nv > 0, "Cannot attach node to an empty graph. use add_node!( graph, item ) instead.")
    add_vertex!( graph.g )
    graph.nv += 1
    graph.meta[ graph.nv ] = item
    add_edge!( graph.g, graph.nv - 1, graph.nv )
    enforceDAG(graph.g)#ensure we have a DAG
end

"""
    addbookmark!( graph::MissionGraph, marker::Symbol )

Adds a bookmark or tag to the last placed node.

"""
function addbookmark!( graph::MissionGraph, marker::Symbol )
    haskey(graph.bookmarks, marker) && @warn("Bookmark $marker already exists - it has been overwritten.")
    graph.bookmarks[ marker ] = graph.nv
end

"""
    attach_node!( graph::MissionGraph, nameitempair::Pair{Symbol, T} ) where {T<:MissionNode}

Adds a new node or bookmarked node with an edge from the last placed node and this one.

"""
function attach_node!( graph::MissionGraph, nameitempair::Pair{Symbol, T} ) where {T<:MissionNode}
    @assert( graph.nv > 0, "Cannot attach node to an empty graph. Use add_node!( graph, item ) instead.")
    add_vertex!( graph.g )
    graph.nv += 1
    addbookmark!( graph, first( nameitempair ) )
    graph.meta[ graph.nv ] = last( nameitempair )
    add_edge!( graph.g, graph.nv - 1, graph.nv )
    enforceDAG(graph.g)#ensure we have a DAG
end

"""
    connect!( graph::MissionGraph, from_str::Symbol, to_str::Symbol )

Adds an edge between `from_str` to `to_str` in a MissionGraph (`graph`)

"""
function connect!( graph::MissionGraph, from_str::Symbol, to_str::Symbol )
    sharedmachines = intersect( graph.meta[ graph.bookmarks[ to_str ] ].machines, graph.meta[ graph.bookmarks[from_str] ].machines )
    @assert( length( sharedmachines ) > 0, "Cannot connect bookmarked nodes($from_str & $to_str) which have no shared machines")
    graph.meta[ graph.bookmarks[to_str] ].machines = sharedmachines
    add_edge!( graph.g, graph.bookmarks[from_str], graph.bookmarks[to_str] )
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
terminatingnodes( G::SimpleDiGraph ) =  Dict(   :parentnodes    => parentnodes(   G ),
                                                :terminalnodes  => terminalnodes( G ) )

"""
    execution_paths( mission::MissionGraph )

Given an input MissionGraph, return a vector of (`source`, `sink`) 2-tuples.

"""
function execution_paths( mission::MissionGraph )
    sources = parentnodes(mission.g)
    sinks   = terminalnodes(mission.g)
    srclen, sinklen = length(sources), length(sinks)
    distanceuppertrimatrix = spzeros(mission.nv, mission.nv )
    for (r, src) in enumerate(sources), (k,sink) in enumerate(sinks)
        distanceuppertrimatrix[src,sink] = has_path( mission.g, src , sink )
    end
    #find all possible execution paths
    return Tuple.( findall( distanceuppertrimatrix .> 0) )
end
