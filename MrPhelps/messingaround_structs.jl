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
function clean_data(src::String)
    println("I read the file \n pscyhe I do nothing!")
end

Local  = "127.0.0.1"
Remote = "optics@192.168.0.14"

mission = MissionGraph()
#Add an unconnected node to the graph
add_node!(mission, Stash("/home/caseykneale/Desktop/megacsv.csv", [ Remote ] ) )
#Add a new node to the graph but connect it to the last node laid down
attach_node!(mission, Agent( clean_data, [ Remote ] ) )
attach_node!(mission, :Prod1 => Agent( prod, [ Remote ] ) )

println( keys( nm.machinenodemap ) )

#basically repeat the same chain but this is isolated...
# add_node!(mission, Stash("/home/caseykneale/Desktop/megacsv2.csv", [ Remote ] ) )
# attach_node!(mission, Agent( clean_data, [ Remote ] ) )
# attach_node!(mission, :Prod2 => Agent( prod, [ Remote ] ) )
# connect!(mission, :Prod1, :Prod2)

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

nm.machinenodemap

#4) Something in the middle: User constrains resources to machines, user dictates
#   minimum & maximum allowance for parallelism on a given taskset, user chooses
#   to memoize data transforms or pass them to new locations, user writes good code
#   that is parallel enough. When resources free up, or a new task is emitted, workers
#   will greedily scramble to finish that task. All tasks are of equal importance.

#Need a handler to emit that a task should start
#Need a distributed File Reading thing...
#Need a handler to emit when a task is done
#Need an error handler...
#Need a way to coelesce data




mission
