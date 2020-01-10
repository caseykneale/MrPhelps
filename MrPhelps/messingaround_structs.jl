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

#                        Connect Machines!
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

#                        Define Some Tasks
function load_data(src::String)
    println("I read the file \n pscyhe I do nothing!")
end

actiongraph = PlanGraph()
#Add an unconnected node to the graph
add_node!(actiongraph, Stash("/home/caseykneale/Desktop/megacsv.csv", ["SSH"] ) )
#Add a new node to the graph but connect it to the last node laid down
attach_node!(actiongraph, Agent( load_data, ["SSH"] ) )
attach_node!(actiongraph, :Prod1 => Agent( prod, ["SSH","Local"] ) )

#basically repeat the same chain but this is isolated...
add_node!(actiongraph, Stash("/home/caseykneale/Desktop/megacsv2.csv", ["SSH"] ) )
attach_node!(actiongraph, Agent( load_data, ["SSH"] ) )
attach_node!(actiongraph, :Prod2 => Agent( prod, ["SSH","Local"] ) )

connect!(actiongraph, :Prod1, :Prod2)

#display final result
attach_node!(actiongraph, :final => Agent( println, ["Local"] ) )

message = Dict( [1,2,3,4] .=> ["why", "is", "julia", "great?"])
result = join(map(x -> message[x], [ 3, 2, 4 ] ), " ")
println(result[1:(end-1)])


#well we basically have a graph now...


struct Sensor
    fn::Function
    worker_id::Int
    performance::Dict
end

#val, t, bytes, gctime, memallocs = @timed rand(10^6)

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
