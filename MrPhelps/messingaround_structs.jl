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
    pth = "/home/caseykneale/Desktop/Playground/MrPhelps/"
    pth = isdir( "/home/caseykneale/" ) ? pth : "/home/optics/Playground/MrPhelps/"
    Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path=pth))
end
@everywhere using MrPhelps

#Update our node manager, we've added connections
update!(nm)
#Grok the machines we have available to our node manager...
machine_to_ids = availablemachines( nm )
# function machine_node_map( nm::NodeManager )
#     names = availablemachines( nm )
#     ids = [ [] for i in 1:length(names) ]
#     for ( id, worker_meta ) in nm.computemeta
#         addr_idx = findfirst( worker_meta.address .== names )
#         push!( addresses[ addr_idx ], id )
#     end
#     return Dict( names .=> ids )
# end

nm.computemeta[2].address


machine_node_map(nm)
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
