mutable struct Scheduler
    mission              ::MissionGraph
    nm                   ::NodeManager
    worker_communications::Dict{ Int, RemoteChannel{ Channel{ WorkerCommunication } } }
    task_stats           ::Dict{ Int, JobStatistics }
end

"""
    Scheduler( nm::NodeManager, mission::MissionGraph )

Constructs a Scheduler object from a NodeManager and MissionGraph. From a high level
the Scheduler contains mapping from which nodes pertain to which machines, and
which tasks can be assigned to which workers. This constructor initializes the DAG, by
finding all parent nodes in a DAG, and allocating as many resources to them as possible.

"""
function Scheduler( nm::NodeManager, mission::MissionGraph )
    # Find each flow from each parent to it's respective terminal
    sinks = terminalnodes( mission.g )
    #find how each parent propagates to a terminal node
    #possible_paths = execution_paths( mission )
    #map out initial worker to task relationships - naively
    worker_task_map = initial_task_assignments( nm, mission )
    #now lets make channels for these workers to talk to the local thread!
    worker_comm_map = Dict{ Int, RemoteChannel{ Channel{ WorkerCommunication } } }()
    task_stats      = Dict{ Int, Any }()
    @sync for (worker, metadata) in nm.computemeta
        worker_comm_map[ worker ] = RemoteChannel( () -> Channel{WorkerCommunication}(1), worker )
        @spawnat worker put!( worker_comm_map[ worker ], WorkerCommunication(   JobStatisticsSample(),
                                                                                worker_task_map[ worker ],
                                                                                available ) )
        task_stats[ worker ] = JobStatistics()
    end
    #get all the info nice and tidy...
    #worker_state    = Dict( [ worker => available for ( worker, task ) in worker_task_map ] )
    return Scheduler( mission, nm, worker_comm_map, task_stats )
end

"""
    execute_mission( sc::Scheduler )

Begins the interpretation of a mission/DAG. This is the part where work
actually get's done.

"""
function execute_mission( sc::Scheduler )
    #everyworker needs their own channel to save state of tasks in.
    #This could be factored out to be a RemoteChannel of a Channel{Any} but its the same.
    #The main point here is this is data only on the remote machine.
    @sync for (worker, task) in sc.worker_communications
        @spawnat worker global state_channel = Channel()
    end
    @info("Global states assigned to workers")
    #ToDo: Add defensive programming to ensure that all of these channels exist.

    #Kick off the event listener loop... This is a bit ugly but whatever, Observables, and Signals
    #follow this pattern. I'd like a more actor style or true event listener style but this is okay for now!
    #@async spawn_listeners( sc )

    #lets start the actual work!
    @sync for ( worker, comm ) in sc.worker_communications
        task = take!( sc.worker_communications[ worker ] )
        if task.last_task > 0
            try
                @async begin
                    println(myid())
                    #make a single buffer to get job statistics from a called and finished fn
                    if isa( sc.mission.meta[ task.last_task ], Stash )
                        #if the current task is a stash, we need to handle iteration over collections and their state in the scheduler.
                        @spawnat worker dispatch_task(  @thunk sc.mission.meta[ task.last_task ].fn( sc.mission.meta[ task.last_task ].src,
                                                        sc.worker_communications[ worker ],
                                                        task.last_task ) )
                    else
                        @spawnat worker dispatch_task(  sc.mission.meta[ task.last_task ].fn,
                                                        sc.worker_communications[ worker ],
                                                        task.last_task )
                    end
                    println(myid())
                    #sc.task_stats[ worker ]     = fetch( sc.worker_future[ worker ] )
                    #now we know the task is completed so we gotta assign the next task to this worker
                    #continue_plan( sc, worker )
                end
            catch
                #failure to do @spawnat means something funamentally bad happened :/
                #@async sc.worker_state[ worker ] = WORKER_STATE.failed
            end
        end
    end
    @info("Done distributing initial tasks. Good luck")
end

function spawn_listeners(sc::Scheduler)
    while true
        #look for tasks that have completed!
        for ( worker, task ) in sc.worker_task_map
            if task > 0 #check for if a worker was assigned a task
                if isready( sc.worker_communications[ worker ] )
                    bufferworker = fetch( @spawnat worker take!( sc.worker_communications[ worker ] ) )
                    if bufferworker.state == ready
                        #this task is done.a
                        nexttask = neighbors(sc.g, bufferworker.last_task)
                        if length(nexttask) == 0
                            #we're at the end of our DAG!
                        else
                            fit!( sc.task_stats[ bufferworker.last_task ].elapsed_time, bufferworker.task_stats.elapsedtime )
                            fit!( sc.task_stats[ bufferworker.last_task ].bytes_allocated, bufferworker.task_stats.bytes_allocated )
                            #assign next task
                            @spawnat worker dispatch_task(  sc.mission.meta[ nexttask ].fn,
                                                            sc.worker_communications[ worker ],
                                                            nexttask )
                        end
                    elseif bufferworker.state == failed
                        #ToDo: handle errors
                    end
                end
            end
        end #end for workers
    end
end

"""
    initial_task_assignments(nm::NodeManager, mission::MissionGraph)

Naively assigns all available workers to all tasks immediately available.

"""
function initial_task_assignments(nm::NodeManager, mission::MissionGraph) #:< Dict{Int,Int}
    workersavailable = total_worker_counts( nm )
    worker_queue = Dict( [ worker => 0  for (worker,tmp) in nm.computemeta  ] )

    sources = parentnodes( mission.g )
    if sum( [ mission.meta[src].min_workers for src in sources ] ) < workersavailable
        @warn("More parent node workers requested ($source_demand) then workers available ($workersavailable).")
    end
    #Distribute jobs to workers by priority
    sources_by_priority = [ [ src, mission.meta[src].min_workers, mission.meta[src].priority ] for src in sources]
    source_demand_by_priority = sort( sources_by_priority, by = x -> last(x) )
    #Satisfy minimum number of workers
    #Loop over sources, demand their minimum requirements be met
    for src_idx in 1 : length( source_demand_by_priority )
        src, demand, priority = source_demand_by_priority[ src_idx ]
        #Loop over available workers
        for worker_idx in keys( worker_queue )
            if ( source_demand_by_priority[ src_idx ][2] > 0 )
                #ensure the machine the task is bound too matches the worker
                if (nm.computemeta[ worker_idx].address in mission.meta[ src ].machines) &&
                        (worker_queue[worker_idx] == 0)
                    worker_queue[ worker_idx ] = src
                    source_demand_by_priority[ src_idx ][2] -= 1
                end
            else
                break; #go to source loop - this source has its demand met!
            end
        end
    end
    #Untested
    source_demand = [ mission.meta[src].max_workers - mission.meta[src].min_workers for src in sources ]
    if workersavailable > sum( values( worker_queue ) .> 0 )
         source_demand_by_priority = sort( sources_by_priority, by = x -> last(x) )
         #Loop over sources, demand their minimum requirements be met
         for src_idx in 1 : length( source_demand_by_priority )
             src, demand, priority = source_demand_by_priority[ src_idx ]
             #Loop over available workers
             for worker_idx in keys( worker_queue )
                 if ( source_demand_by_priority[ src_idx ][2] > 0 )
                     #ensure the machine the task is bound too matches the worker
                     if (nm.computemeta[ worker_idx].address in mission.meta[ src ].machines) &&
                             (worker_queue[worker_idx] == 0)
                         worker_queue[ worker_idx ] = src
                         source_demand_by_priority[ src_idx ][2] -= 1
                     end
                 else
                     break; #go to source loop - this source has its demand met!
                 end
             end
         end
    end
    return worker_queue
end
