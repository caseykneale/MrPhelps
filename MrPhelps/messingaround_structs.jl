using Pkg, Revise
Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path="/home/caseykneale/Desktop/Playground/MrPhelps/"))
using MrPhelps
using Distributed, ClusterManagers, SharedArrays
using LightGraphs, MetaGraphs
using Dates, Logging

#                        Connect Machines!
#First a user needs to define machines it has access too...
MrPhelps.greet()
#Define NodeManager - to keep track of Distributed Hooks to all machines
nm = NodeManager()
#Connect to a remote box and use a core/thread on the local machine!
LocalNode   = @async addprocs( 2; restrict = true )
RemoteNode  = @async addprocs( [ ( "optics@192.168.0.14", 2 ) ], tunnel = true, max_parallel = 4,
                              exename = "/home/optics/julia-1.3.0/bin/julia") #, sshflags = "-vvv" )

@everywhere begin
    using Pkg
    if isdir( "/home/caseykneale/" )
        Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path="/home/caseykneale/Desktop/Playground/MrPhelps/"))
    else
        Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path="/home/optics/Playground/MrPhelps/"))
    end
end

@everywhere GetMrPhelpsDev()
#@everywhere using MrPhelps
#Update our node manager, we've added connections
update!(nm);

xy = 4
cpuspd = @spawnat xy Sys.cpu_info()[1].speed
c = fetch(cpuspd)

#Grok the machines we have available to our node manager...
machine_to_ids = availablemachines( nm )
nm
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

#well we basically have a graph now...


cpuinfo = Sys.cpu_info()
cores_available = length(Sys.cpu_info())
typeof(Sys.cpu_info()[1].speed)

@sync @distributed for i in 1:nprocs()
    println(Sys.cpu_info())
end

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
