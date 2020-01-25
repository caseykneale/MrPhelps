mutable struct Scheduler
    mission        ::MissionGraph
    nm             ::NodeManager
    possible_paths ::Any #ToDo dont be lazy get the type list of 2 int tuples? Do I even need this?
    worker_task_map::Dict
    worker_state   ::Dict
    worker_future  ::Dict{ Int, Future }
    task_stats     ::Dict{ Int, JobStatistics }#ToDo don't be lazy get the online stats type
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
    possible_paths = execution_paths( mission )
    #map out initial tasks naively
    worker_task_map = initial_task_assignments( nm, mission )
    #get all the info nice and tidy...
    worker_state    = Dict( [ worker => available for ( worker, task ) in worker_task_map ] )
    worker_future   = Dict{ Int, Future }()
    task_stats      = Dict{ Int, Any }()
    return Scheduler(   mission, nm, possible_paths,
                        worker_task_map, worker_state, worker_future, task_stats )
end

"""
    execute_mission( sc::Scheduler )

Begins the interpretation of a mission/DAG. This is the part where work
actually get's done.

"""
function execute_mission( sc::Scheduler )
    #everyworker needs their own channel to communicate messages through
    @sync for (worker, task) in sc.worker_task_map
        @spawnat worker global channel = Channel()
    end
    @sync for ( worker, task ) in sc.worker_task_map
        if task > 0
            @sync sc.worker_state[ worker ] = WORKER_STATE.ready
            try
                @async begin
                    #make a single buffer to get job statistics from a called and finished fn
                    if isa( sc.mission.meta[ task ], Stash )
                        #if the current task is a stash, we need to handle iteration over collections and their state in the scheduler.
                        sc.worker_future[ worker ] = @spawnat worker recieved_task( @thunk sc.mission.meta[ task ].fn( sc.mission.meta[ task ].src ) )
                    else
                        sc.worker_future[ worker ] = @spawnat worker recieved_task( sc.mission.meta[ task ].fn )
                    end
                    sc.worker_state[ worker ]   = WORKER_STATE.launched
                    sc.task_stats[ worker ]     = fetch( sc.worker_future[ worker ] )
                    sc.worker_state[ worker ]   = WORKER_STATE.ready
                    #now we know the task is completed so we gotta assign the next task to this worker
                    continue_plan( sc, worker )
                end
            catch
                #failure to do @spawnat means something funamentally bad happened :/
                @async sc.worker_state[ worker ] = WORKER_STATE.failed
            end
        end
    end
end

function continue_plan( sc::Scheduler, worker::Int )
    #Get next task
    worker_paths = LightGraphs.neighbors( mission.g, sc.worker_task_map[worker] )
    if length(worker_paths) == 1
        #Hey let's assign and execute that task
        sc.worker_task_map[worker]  = worker_paths
        sc.worker_future[ worker ]  = @spawnat worker recieved_task( sc.mission.meta[ task ].fn )
        sc.worker_state[ worker ]   = WORKER_STATE.launched
        sc.task_stats[ worker ]     = fetch( sc.worker_future[ worker ] )
        sc.worker_state[ worker ]   = WORKER_STATE.ready
    end
end

"""
    initial_task_assignments(nm::NodeManager, mission::MissionGraph)

Naively assigns all available workers to all tasks immediately available.

"""
function initial_task_assignments(nm::NodeManager, mission::MissionGraph)
    workersavailable = total_worker_counts( nm )
    worker_queue = Dict( [ worker => 0  for (worker,tmp) in nm.computemeta  ] )

    sources = parentnodes( mission.g )
    if sum( [ mission.meta[src].min_workers for src in sources ] ) < workersavailable
        @warn("More parent node workers requested ($source_demand) then workers available ($workersavailable)")
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
