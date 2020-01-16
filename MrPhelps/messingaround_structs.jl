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

add_node!(mission, :references => Stash("/home/caseykneale/Desktop/refcsv.csv", [ Remote ], 2 ) )
connect!(mission, :references, :prod)

#well we basically have a graph now...
#it's time we formulate a plan: Note it's about to get hacky!
#lets crawl the graph! Find all parent/source nodes
sources = parentnodes( mission.g )
sinks = terminalnodes( mission.g )

srclen = length(sources)
sinklen = length(sinks)

distribution_paths = execution_paths( mission )

#Most naive scheme
#   Worker starts process at a source
#   Finishes process, alerts, scheduler, and gets next task (stay or move)
#       After each alert, the scheduler decides what to do next.
#       Are there available nodes for open tasks?
#       Do we need to wait for a worker to open to complete a task?

nm.machinenodemap

struct Scheduler
    mission::MissionGraph
    nodem::NodeManager
    nodes_tasks::Dict
end

#NodeManager maps Machines to Workers
#MissionGraph links Tasks to Tasks, and Tasks to Workers
#I need to link available machines to available tasks least effort way: make a map
flip( a::Dict ) = Dict( Iterators.flatten( [ v .=> k for (k,v) in a ] ) )
flip( nm.machinenodemap )





Pkg.add("LightGraphsFlows")
using Clp: ClpSolver # use your favorite LP solver here
using LightGraphs, LightGraphsFlows
using SparseArrays
g = DiGraph(5) # Create a flow-graph
add_edge!(g, 1, 2)
add_edge!(g, 2, 3)
add_edge!(g, 3, 4)
add_edge!(g, 5, 2)

w = zeros(5,5)
w[1,2] = 1
w[2,3] = 1.
w[3,4] = 1.
w[5,2] = 0.1
# v2 -> sink have demand of one
demand = spzeros(5,5)
demand[3,4] = 1
demand[5,4] = 1
capacity = ones(5,5)
flow = mincost_flow(g, capacity, demand, w, ClpSolver(), 1, 4)
flow = mincost_flow(g, capacity, demand, w, ClpSolver(), 5, 4)


#function taskwithany()
for ( task_number, task ) in mission.meta
    machines_for_task = task.machines
    workers_available = map( x -> nm.machinenodemap[ x ], machines_for_task )
    task.min_workers
end
#end



worker_count( nm, Local )
total_worker_counts( nm )


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
