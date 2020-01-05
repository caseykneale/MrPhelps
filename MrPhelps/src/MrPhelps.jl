module MrPhelps
    using Revise

    greet() = print("Your mission, should you choose to accept it, ...\n"*
                    "As always, should you or any of your IM Force be caught or \n" *
                    "killed, the Secretary will disavow any knowledge of your \n" *
                    "actions. This tape/disc will self-destruct in five/ten seconds.\n" *
                    "Good luck,")

    using Distributed, ClusterManagers
    using LightGraphs, MetaGraphs
    using Dates

    include("MetaUtils.jl")
    export WorkerMetaData, worker_meta

    include("ConvenienceIterators.jl")
    export interleavestrings, Expand

    include("NodeManager.jl")
    export NodeManager, update!, determinemachines

end # module
