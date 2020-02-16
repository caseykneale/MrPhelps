module MrPhelps
    #using Revise
    greet() = print("Your mission, should you choose to accept it, is to distribute all the tasks..."*
                    "As always, should you or any of your nodes be interrupted or " *
                    "killed, The Secretary will log any knowledge of your actions. This program" *
                    " will hopefully not self-destruct in ten seconds.\n Good luck,")

    using Distributed, ClusterManagers, OnlineStats, LightGraphs, LightGraphsFlows, JLSO
    using Glob, Dates

    include("Thunks.jl")
    export JobStatistics, JobStatisticsSample, WORKER_STATE, WorkerCommunication,
            Thunk, @thunk, dispatch_task, reset_worker

    include("MetaUtils.jl")
    export WorkerMetaData, worker_meta

    include("ConvenienceIterators.jl")
    export FileIterator, interleavestrings, Expand, VariableGlob, length

    include("Caching.jl")
    #ToDo: Add functionality
    #export

    include("NodeManager.jl")
    export NodeManager, update!, availablemachines, machinenames, worker_count,
            total_worker_counts

    include("MissionNodes.jl")
    export MissionNode, MissionNodeIterator, Agent, Stash, StashIterator, next!, length

    include("MissionGraph.jl")
    export  MissionGraph, machines, add_node!, attach_node!,
        addbookmark!, attach_node!, connect!, terminalnodes,
        terminatingnodes, parentnodes, execution_paths

    include("TaskManager.jl")
    export world_age, Scheduler, execute_mission, spawn_listeners,
                initial_task_assignments

end # module
