module MrPhelps
    using Revise

    greet() = print("Your mission, should you choose to accept it, is to distribute all the tasks..."*
                    "As always, should you or any of your nodes be interrupted or " *
                    "killed, The Secretary will log any knowledge of your actions. This program" *
                    " will hopefully not self-destruct in ten seconds.\n Good luck,")

    using Distributed, ClusterManagers
    using LightGraphs, LightGraphsFlows, SparseArrays
    using Glob, Dates

    include("MetaUtils.jl")
    export WorkerMetaData, worker_meta

    include("ConvenienceIterators.jl")
    export FileIterator, interleavestrings, Expand, VariableGlob

    include("NodeManager.jl")
    export NodeManager, update!, availablemachines, machinenames, worker_count,
            total_worker_counts

    include("MissionGraph.jl")
    export  MissionNode, Agent, Stash, MissionGraph, query_metadata, machines,
            add_node!, attach_node!, addbookmark!, attach_node!, connect!,
            terminalnodes, terminatingnodes, parentnodes, execution_paths

    include("TaskManager.jl")
    export WORKER_STATE, initial_task_assignments

end # module
