module MrPhelps
    using Revise

    greet() = print("Your mission, should you choose to accept it, is to distribute all the tasks..."*
                    "As always, should you or any of your IM Force be caught or " *
                    "killed, The Secretary will disavow any knowledge of your" *
                    "actions. This tape will self-destruct in ten seconds.\n" *
                    "Good luck,")

    using Distributed, ClusterManagers
    using LightGraphs, MetaGraphs
    using Dates

    include("MetaUtils.jl")
    export WorkerMetaData, worker_meta

    include("ConvenienceIterators.jl")
    export interleavestrings, Expand

    include("NodeManager.jl")
    export NodeManager, update!, availablemachines

    include("ActionGraph.jl")
    export  PlanNode, Agent, Stash, PlanGraph, query_metadata, machines,
            add_node!, attach_node!, addbookmark!, attach_node!, connect!

end # module
