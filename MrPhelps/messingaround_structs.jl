using Pkg
Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path="/home/caseykneale/Desktop/Playground/MrPhelps/"))
using MrPhelps, Distributed, ClusterManagers, SharedArrays, Dates

localonly = true
#                        Connect Machines!
#First a user needs to define machines it has access too...
MrPhelps.greet()
if !localonly;  run(`scp -r /home/caseykneale/Desktop/Playground optics@192.168.0.14:/home/optics/`); end;
#Define NodeManager - to keep track of Distributed Hooks to all machines
nm = NodeManager()
Local  = "127.0.0.1"
Remote = "optics@192.168.0.14"
#Connect to a remote box and use a core/thread on the local machine!
LocalNode   = @async addprocs( 2; restrict = true )
if !localonly
    RemoteNode  = @async addprocs( [ ( Remote, 2 ) ], tunnel = true, max_parallel = 4,
                                    exename = "/home/optics/julia-1.3.0/bin/julia") #, sshflags = "-vvv" )
end

@everywhere begin
    using Pkg
    pth = "/home/caseykneale/Desktop/Playground/MrPhelps/"
    pth = isdir( "/home/caseykneale/" ) ? pth : "/home/optics/Playground/MrPhelps/"
    Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path=pth))
end
@everywhere using MrPhelps
#Update our node manager, because we've added connections
#Or we could make the node manager after adding the connections
update!(nm)
#Grok the machines we have available to our node manager...
println( nm.machinenodemap )

#                        Define Some Tasks
mission = MissionGraph()
#Add an unconnected node to the graph
add_node!(mission, Stash("/home/caseykneale/Desktop/megacsv.csv", [ Remote ], 2 ) )
#Add a new node to the graph but connect it to the last node laid down
attach_node!(mission, Agent( sum, [ Remote ] ) )
#Add another new node, but give it a bookmark so we can find it later!
attach_node!(mission, :prod => Agent( prod, [ Remote ] ) )
#Look we can add another new node to the graph unattached to anything
add_node!(mission, :final => Agent( println, [Local] ) )
#And now we can connect it to something else we bookmarked!
connect!(mission, :prod, :final)
#We made a very simple linear chain. Yay!

#well we basically have a graph now...
#it's time we formulate a plan: Note it's about to get hacky!
#lets crawl the graph! Find all parent/source nodes
sources = terminatingnodes( mission.g )[ :parentnodes ]
worker_count( nm, Local )
total_worker_counts( nm )

mission.meta[sources[1]]


total_worker_counts = sum( [ length( workers ) for ( name, workers ) in nm.machinenodemap ] )
nm.machinenodemap

println( nm.machinenodemap )

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

# struct MissionManager
#     mission::MissionGraph
#     workman::WorkManager
#     nodeman::NodeManager
# end
