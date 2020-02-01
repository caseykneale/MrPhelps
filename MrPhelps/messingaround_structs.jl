using Pkg
Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path="/home/caseykneale/Desktop/Playground/MrPhelps/"))
using MrPhelps, Distributed, Dates

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
add_node!(mission, Stash(   "/home/caseykneale/Desktop/megacsv.csv",
                            @thunk( string ), [ Local ], 1 ) )
#Add a new node to the graph but connect it to the last node laid down
attach_node!(mission, Agent( @thunk( uppercase ), [ Local ] ) )
#Add another new node, but give it a bookmark so we can find it later!
attach_node!(mission, :prod => Agent( @thunk( lowercase ), [ Local ] ) )
#Look we can add another new node to the graph unattached to anything
add_node!(mission, :final => Agent( @thunk( println ), [Local] ) )
#And now we can connect it to something else we bookmarked!
connect!(mission, :prod, :final)
#We made a very simple linear chain. Yay!
add_node!(mission, :references => Stash("/home/caseykneale/Desktop/refcsv.csv",
                                    @thunk( string ), [ Local ], 1 ) )
connect!( mission, :references, :prod )

#begin tasking...
sc = Scheduler( nm, mission )
execute_mission( sc )

@async spawn_listeners( sc )

#for debugging
#sc.worker_communications
isready(sc.worker_communications[2])
isready(sc.worker_communications[3])
isready(sc.worker_channels[2])
isready(sc.worker_channels[3])



mission = MissionGraph()

data_file_fomat = "data_{year}-{month}-{day}.csv"
expansion = Dict(   "year"  => [2020],
                    "month" => [7,11],
                    "day"   => collect(1:30))

n = Expand(data_file_fomat, expansion)


for i in Expand(data_file_fomat, expansion)
    println(i)
end

add_node!(mission, StashIterator(  Expand(data_file_fomat, expansion),
                                    Stash("", @thunk( string ), [ Local ], 1 ) ) )
attach_node!(mission, Agent( @thunk( uppercase ), [ Local ] ) )
attach_node!(mission, :prod => Agent( @thunk( lowercase ), [ Local ] ) )
add_node!(mission, :final => Agent( @thunk( println ), [Local] ) )
connect!(mission, :prod, :final)
add_node!(mission, :references => Stash("/home/caseykneale/Desktop/refcsv.csv",
                                    @thunk( string ), [ Local ], 1 ) )
connect!( mission, :references, :prod )




##########################################################################
# Most naive scheme
#   Worker starts process at a source
#   Finishes process, alerts, scheduler, and gets next task (stay or move)
#       After each alert, the scheduler decides what to do next.
#       Are there available nodes for open tasks?
#       Do we need to wait for a worker to open to complete a task?
##########################################################################
# ===============================================
#               Below is all WIP
# ===============================================
# Graph     <->     Tasks       <->     Machine
# Node      <->     Machine
# Assign:
#   - Find parent task
#   - Find nodes to meet requirements
# Execute:
#   - (async) Dispatch task thunks to nodes and run
#   - (async) Result is stored to a channel & statistics sent back to local
#   - Local decides the next task for the jobs available
# More fleshed out...
#   - Every worker gets a communication remotechannel!
#   - Dispatch thunks
#   - Thunks wrapped in a function which
#       :wraps thunks and deploys args
#       :computes runtime stats
#       :ferries results to remote channel

macro ift(ex...)
    @assert( length(ex) == 3, "malformed if/then statement.")
    @assert( ex[ 2 ] == :then, "malformed if/then statement.")
    quote
        local conditional   = $(esc( ex[1] ))
        local trueresponse  = $(esc( ex[3] ))
        return conditional  ? trueresponse : nothing
    end
end

abc() = "dfg"
innerfun1() = @ift 1==1 then abc()
innerfun3(a, b) = @ift a ==1 then b
