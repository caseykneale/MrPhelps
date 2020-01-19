struct Scheduler
    mission        ::MissionGraph
    nm             ::NodeManager
    possible_paths ::Any #ToDo dont be lazy
    worker_state   ::Dict
    worker_future  ::Dict{ Int, Future }
end

@enum WORKER_STATE begin
    available   = 0
    ready       = 1
    launched    = 2
    hasdata     = 3
    failed      = 4
end

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
    return Scheduler( mission, nm, possible_paths, worker_state, worker_future )
end

function StartJob( sc::Scheduler )
    @sync for ( worker, task ) in sc.worker_task_map
        if task > 0
            worker_state[ worker ] = WORKER_STATE.ready
            try
                @async worker_state[ future ] = @spawnat worker myid()
                worker_state[ worker ] = WORKER_STATE.launched
            catch
                worker_state[ worker ] = WORKER_STATE.failed
            end
        end
    end

end

function initial_task_assignments(nm::NodeManager, mission::MissionGraph)
    workersavailable = total_worker_counts( nm )
    worker_queue = Dict( [ worker => 0  for (worker,tmp) in nm.computemeta  ] )

    sources = parentnodes( mission.g )
    if sum( [ mission.meta[src].min_workers for src in sources ] ) < workersavailable
        @warn("More parent node workers requested ($source_demand) then workers available($workersavailable)")
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
