using Pkg, Revise
Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path="/home/caseykneale/Desktop/Playground/MrPhelps/"))
using MrPhelps

#Test Case
# tst = "simulation{number}awesome{name}.csv"
# semantics = Dict( "name"    => [ "great", "okay", "bad" ],
#                   "number"  => [ "1", "2", "3" ] )
#
# for s in Expand( tst, semantics )
#   println( s )
# end

using Distributed, ClusterManagers, SharedArrays
using LightGraphs, MetaGraphs
using Dates, Logging

"""
                        Connect Machines!
"""
#First a user needs to define machines it has access too...
MrPhelps.greet()
#Define NodeManager - to keep track of Distributed Hooks to all machines
nm = NodeManager()
#Connect to a remote box and use a core/thread on the local machine!
LocalNode   = @async addprocs( 1; restrict = true )
RemoteNode  = @async addprocs( [ ( "optics@192.168.0.14", 2 ) ], tunnel = true, max_parallel = 4,
                              exename = "/home/optics/julia-1.3.0/bin/julia", sshflags = "-vvv" )
#Update our node manager, we've added connections
update!(nm);
#Grok the machines we have available to our node manager...
machine_to_ids = availablemachines( nm )

"""
                        Define Some Tasks
"""
mutable struct PlanGraph
    g::SimpleDiGraph
    nv::Int
    meta::Dict
end
PlanGraph() = PlanGraph( SimpleDiGraph(), 0, Dict() )

function query_metadata( PG::PlanGraph, category::Symbol, valuestr::String )
    return [ vtx for ( vtx, nn ) in PG.meta if nn[ category ] == valuestr]
end

nickname( PG::PlanGraph, vtx::Int )     = PG.meta[ vtx ][ :nickname ]
process_id( PG::PlanGraph, vtx::Int )   = PG.meta[ vtx ][ :id ]
machines( PG::PlanGraph, vtx::Int )     = PG.meta[ vtx ][ :machines ]
nicknames( PG ) = [ nn[ :nickname ] for ( vtx, nn ) in PG.meta ]

actiongraph = PlanGraph()

function add_agent!(graph::PlanGraph, fn::Function, nickname::String, machines::Vector{ String } )
    @assert( !any(nickname .== nicknames(graph)), "Nickname has already been defined.")
    add_vertex!( graph.g )
    graph.nv += 1
    graph.meta[ graph.nv ] = Dict(  :fn => fn,     :nickname => nickname,
                                    :id => :none,  :machines => machines )
    return nothing
end

function add_stash!(graph::PlanGraph, src::String, nickname::String, machines::Vector{ String } )
    @assert( !any(nickname .== nicknames(graph)), "Nickname has already been defined.")
    add_vertex!( graph.g )
    graph.nv += 1
    graph.meta[ graph.nv ] = Dict(  :source => src,    :nickname => nickname,
                                    :id => :none,      :machines => machines )
    return nothing
end

function (PG::PlanGraph)(from_str::String, to_str::String; idxby = :nickname)
    @assert( ( idxby != :source ) && ( idxby != :fn ), "Cannot index a PlanGraph by `:source` or `:fn`." )
    from_vtx    = query_metadata(PG, idxby, from_str)
    to_vtx      = query_metadata(PG, idxby, to_str)
    add_edge!( PG.g, from_str, to_str )
end

nicknames(actiongraph)
add_agent!(actiongraph, prod, "node1", ["cookie","applies"] )
nicknames(actiongraph)
add_agent!(actiongraph, prod, "node1", ["cookie","applies"] )
nicknames(actiongraph)

query_metadata(actiongraph, :nickname, "node1")

length(actiongraph.g.ne)

dump(actiongraph.g)

add_agent!(actiongraph, sum, "node1", [1,2,3] )

# Chains,
# Sensors/Listeners
# Sources/Sinks


Dict(:nickname => 123)

struct Sensor
    fn::Function
    worker_id::Int
    performance::Dict
end

val, t, bytes, gctime, memallocs = @timed rand(10^6)

a(10)

output = @timev println("cookies")
typeof(output)

fn(x) = x + 3
typeof( fn ) <: Function
typeof( x -> x + 3 ) <: Function

struct TaskGraph

end

#Sys.cpu_info()
# @sync @distributed for i in 1:nprocs()
#     println(Sys.cpu_info())
# end
#
# @distributed Sys.cpu_info()
#
# println("...")

# @everywhere coin_toss() = rand() > 0.5
# f = @spawnat 5 coin_toss()
# fetch(f)
#
# procs()
# nprocs()
# procs()
# workers()
# nworkers()
# myid()
# Base.@kwdef mutable struct Foo
#     x::Int = 0
#     y::Int = 1
# end

if nprocs() > 1   # Ensure at least one new worker is available
    # perform distributed execution
    #@distributed coin_toss()
    pmap(i -> println("I'm worker $(myid()), working on i=$i"), 1:10)
    @sync @distributed for i in 1:10
        println("I'm worker $(myid()), working on i=$i")
    end
end
