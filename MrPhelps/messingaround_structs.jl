using Pkg
Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path="/home/caseykneale/Desktop/Playground/MrPhelps/"))
using MrPhelps
using Distributed, ClusterManagers, SharedArrays
using Dates

localonly = true

#                        Connect Machines!
#First a user needs to define machines it has access too...
MrPhelps.greet()
if !localonly
    run(`scp -r /home/caseykneale/Desktop/Playground optics@192.168.0.14:/home/optics/`)
end
#Define NodeManager - to keep track of Distributed Hooks to all machines
nm = NodeManager()
#Connect to a remote box and use a core/thread on the local machine!
LocalNode   = @async addprocs( 2; restrict = true )
if !localonly
    RemoteNode  = @async addprocs( [ ( "optics@192.168.0.14", 2 ) ], tunnel = true, max_parallel = 4,
                                    exename = "/home/optics/julia-1.3.0/bin/julia") #, sshflags = "-vvv" )
end

@everywhere begin
    using Pkg
    pth = "/home/caseykneale/Desktop/Playground/MrPhelps/"
    pth = isdir( "/home/caseykneale/" ) ? pth : "/home/optics/Playground/MrPhelps/"
    if !isdir( "/home/caseykneale/" )
        #run(`cd /home/optics/Playground/`)
        #run(`git pull`)
        #run(`cd`)
    end
    Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path=pth))
end
@everywhere using MrPhelps

#Update our node manager, we've added connections
update!(nm)

#Grok the machines we have available to our node manager...
nm.machinenodemap

#                        Define Some Tasks
function load_data(src::String)
    println("I read the file \n pscyhe I do nothing!")
end

mission = MissionGraph()
#Add an unconnected node to the graph
add_node!(mission, Stash("/home/caseykneale/Desktop/megacsv.csv", ["SSH"] ) )
#Add a new node to the graph but connect it to the last node laid down
attach_node!(mission, Agent( load_data, ["SSH"] ) )
attach_node!(mission, :Prod1 => Agent( prod, ["SSH","Local"] ) )

#basically repeat the same chain but this is isolated...
add_node!(mission, Stash("/home/caseykneale/Desktop/megacsv2.csv", ["SSH"] ) )
attach_node!(mission, Agent( load_data, ["SSH"] ) )
attach_node!(mission, :Prod2 => Agent( prod, ["SSH","Local"] ) )

connect!(mission, :Prod1, :Prod2)

#display final result
attach_node!(mission, :final => Agent( println, ["Local"] ) )

#well we basically have a graph now...
# struct MissionManager
#     mission::MissionGraph
#     workman::WorkManager
#     nodeman::NodeManager
# end

#lets crawl the graph!find all parent/source nodes
sources = terminalnodes( mission.g )[ :parentnodes ]

#Need a handler to emit that a task should start
#Need a distributed File Reading thing...
#Need a handler to emit when a task is done
#Need an error handler...
#Need a way to coelesce data


mission
