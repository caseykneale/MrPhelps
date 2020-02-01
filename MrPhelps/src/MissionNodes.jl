abstract type MissionNode ; end

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
    result, state   = src_iterator
    stash.src       = result
    return StashIterator( src_iterator, state, stash )
end

"""
    nextstash( si::StashIterator )

Updates a stash iterators source parameter by updating the internal iterator

"""
function nextstash!( si::StashIterator )
    si.stash.src[:], si.iteratorstate[:] = iterate( src_iterator, si.iteratorstate )
end

Base.@kwdef mutable struct MissionGraph
    g::SimpleDiGraph    = SimpleDiGraph()
    nv::Int             = 0
    meta::Dict          = Dict()
    bookmarks::Dict     = Dict()
end
