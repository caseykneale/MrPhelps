abstract type MissionNode ; end
abstract type MissionNodeIterator <: MissionNode; end

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

mutable struct StashIterator <: MissionNodeIterator
    iterator            ::Union{FileIterator, Vector{ String } }
    iteratorstate       ::Any
    #below matches exactly with Stash constructor...
    src                 ::String
    fn                  ::Union{Nothing, Thunk, Function}
    machines            ::Vector{ String }
    priority            ::Int
    min_worker_constant ::Int
    min_workers         ::Int
    max_workers         ::Int
    dispatched_workers  ::Vector{ Int }
end

function StashIterator( src_iterator::Union{FileIterator,Vector{String}},
                        fn::Union{Thunk,Function},
                        machines::Vector{String},
                        priority::Int = 1,
                        min_workers_per_iter::Int = 1,
                        max_workers_per_iter::Int = 1 )
    result, state   = iterate( src_iterator )
    return StashIterator(   src_iterator, state, result, fn, machines,
                            priority,
                            copy(min_workers_per_iter),
                            min_workers_per_iter, max_workers_per_iter,
                            Vector{Int}(undef, 0) )
end

"""
    next!( si::MissionNodeIterator )

Updates a MissionNodeIterator's source parameter by updating the internal iterator

"""
function next!( si::MissionNodeIterator )
    result = iterate( si.iterator, si.iteratorstate )
    if isnothing( result )
        si.src = nothing
    else
        si.src, si.iteratorstate = result
    end
end
