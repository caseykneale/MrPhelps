"""
    world_age()

Get the julia world age. Borrowed from Signals.jl.

"""
world_age() = ccall( :jl_get_world_counter, Int, () )

mutable struct Scheduler
    mission              ::MissionGraph
    nm                   ::NodeManager
    worker_communications::Dict{ Int, RemoteChannel{ Channel{ WorkerCommunication } } }
    task_stats           ::Dict{ Int, JobStatistics }
    worker_channels      ::Dict{ Int, RemoteChannel{ Channel{ Any } } }
end

"""
    Scheduler( nm::NodeManager, mission::MissionGraph )

Constructs a Scheduler object from a NodeManager and MissionGraph. From a high level
the Scheduler contains mappings from which nodes pertain to which machines, and
which tasks can be assigned to which workers. This constructor initializes the DAG, by
finding all parent nodes in a DAG, and allocating as many resources to them as possible.

"""
function Scheduler( nm::NodeManager, mission::MissionGraph )
    # Find each flow from each parent to it's respective terminal
    sinks = terminalnodes( mission.g )
    #map out initial worker to task relationships - naively
    worker_task_map = initial_task_assignments( nm, mission )
    #now lets make channels for these workers to talk to the local thread!
    worker_comm_map = Dict{ Int, RemoteChannel{ Channel{ WorkerCommunication } } }()
    worker_channels = Dict{ Int, RemoteChannel{ Channel{ Any } } }()    #everyworker needs their own channel to save state of tasks in.
    task_stats      = Dict{ Int, Any }( [ node => JobStatistics() for (node, other) in mission.meta])
    @sync for (worker, metadata) in nm.computemeta
        worker_comm_map[ worker ] = RemoteChannel( () -> Channel{WorkerCommunication}(1), worker )
        worker_channels[ worker ] = RemoteChannel( () -> Channel{Any}(1), worker )
        @spawnat worker put!( worker_comm_map[ worker ], WorkerCommunication(   JobStatisticsSample(),
                                                                                worker_task_map[ worker ],
                                                                                available ) )
    end
    @info("Global states assigned to workers.")
    return Scheduler( mission, nm, worker_comm_map, task_stats, worker_channels )
end

"""
    execute_mission( sc::Scheduler )

Begins the interpretation of a mission/DAG. This is the part where work
actually get's done.

"""
function execute_mission( sc::Scheduler )
    #ToDo: Add defensive programming to ensure that all of these channels exist.
    @sync for ( worker, comm ) in sc.worker_communications
        task = take!( sc.worker_communications[ worker ] )
        if task.last_task > 0
            try
                @async begin
                    #make a single buffer to get job statistics from a called and finished fn
                    if isa( sc.mission.meta[ task.last_task ], Stash )
                        #if the current task is a stash, we need to handle iteration over collections and their state in the scheduler.
                        @spawnat worker begin
                            sc.mission.meta[ task.last_task ].fn
                            dispatch_task(  sc.mission.meta[ task.last_task ].fn,
                                            sc.worker_channels[ worker ],
                                            sc.worker_communications[ worker ],
                                            task.last_task,
                                            sc.mission.meta[ task.last_task ].src )
                        end
                    else
                        @spawnat worker begin
                            sc.mission.meta[ task.last_task ].fn
                            dispatch_task(  sc.mission.meta[ task.last_task ].fn,
                                            sc.worker_channels[ worker ],
                                            sc.worker_communications[ worker ],
                                            task.last_task )
                        end
                    end
                end
            catch
                @error("Failed to spawn initial tasks.")
                #failure to do @spawnat means something funamentally bad happened :/
                #@async sc.worker_state[ worker ] = WORKER_STATE.failed
            end
        end
    end
    @info("Done distributing initial tasks. Good luck")
end

"""
    spawn_listeners(sc:Scheduler)

Starts an event listener and task dispatcher loop.

"""
function spawn_listeners(sc::Scheduler)
    #Kick off the event listener loop... This is a bit ugly but whatever, Observables, and Signals
    #follow this pattern. I'd like a more actor style or true event listener style but this is okay for now!
    @info("Worker communications established...")
    eventloop_world_age = world_age()
    while true
        #look for tasks that have completed!
        completion_listener( sc )

        sleep(0.0010)
    end #end never ending while loop
end #end function...

"""
    completion_listener(sc::Scheduler)

Updates the local storage of a scheduler when tasks are completed, or tasks
reach the end of a DAG.

"""
function completion_listener(sc::Scheduler)
    keyset = [k for k in keys(sc.worker_communications)]
    for worker in keyset
        if all( isready.( [sc.worker_communications[ worker ], sc.worker_channels[ worker ] ] ) )
            bufferworker = take!( sc.worker_communications[ worker ] )
            if ( bufferworker.last_task > 0 ) && ( bufferworker.state == ready )
                nexttask = neighbors(sc.mission.g, bufferworker.last_task)
                if length(nexttask) == 0
                    @info("Worker #$worker completed round trip of a DAG.")
                    reset_worker(   sc.worker_channels[ worker ],
                                    sc.worker_communications[ worker ] )
                else
                    nexttask = first(nexttask)
                    OnlineStats.fit!(   sc.task_stats[ bufferworker.last_task ].elapsed_time,
                                        bufferworker.task_stats.elapsed_time )
                    OnlineStats.fit!(   sc.task_stats[ bufferworker.last_task ].bytes_allocated,
                                        bufferworker.task_stats.bytes_allocated )
                    #assign next task
                    @spawnat worker begin
                        sc.mission.meta[ nexttask ].fn
                        dispatch_task(  sc.mission.meta[ nexttask ].fn,
                                        sc.worker_channels[ worker ],
                                        sc.worker_communications[ worker ],
                                        nexttask )
                    end
                    bufferworker.last_task
                end
            elseif bufferworker.state == failed
                @error("Srs error") #ToDo: handle errors
            end
        end
    end #end for workers
end

"""
    initial_task_assignments(nm::NodeManager, mission::MissionGraph)

Naively assigns all available workers to all tasks immediately available.

"""
function initial_task_assignments(nm::NodeManager, mission::MissionGraph) #:< Dict{Int,Int}
    workersavailable = total_worker_counts( nm )
    worker_queue = Dict( [ worker => 0 for (worker,tmp) in nm.computemeta  ] )

    sources = parentnodes( mission.g )
    if sum( [ mission.meta[src].min_workers for src in sources ] ) < workersavailable
        @warn("More parent node workers requested ($source_demand) then workers available ($workersavailable). Some initial tasks will be unfullfilled at initialization.")
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
            if ( source_demand_by_priority[ src_idx ][ 2 ] > 0 )
                #ensure the machine the task is bound too matches the worker
                if (nm.computemeta[ worker_idx ].address in mission.meta[ src ].machines) &&
                        (worker_queue[worker_idx] == 0)
                    worker_queue[ worker_idx ] = src
                    source_demand_by_priority[ src_idx ][2] -= 1
                    #handle if this is a stash iterator.
                    if isa.( mission.meta[ src ].src, StashIterator )
                        #msnsrc, state = iterate( mission.meta[ src ].src,  )
                    end
                end
            else
                break; #go to source loop - this source has its demand met!
            end
        end #end worker loop
    end #end source loop
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
