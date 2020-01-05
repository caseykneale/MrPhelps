mutable struct NodeManager
    masterID::Union{ Missing, Int }
    localmeta::Union{ Missing, Dict{Int64, MrPhelps.WorkerMetaData} }
    computemeta::Union{ Missing, Dict{Int64, MrPhelps.WorkerMetaData} }
end

function NodeManager()
    if Distributed.nworkers() == 1
        @info   "NodeManager instance created with only a local worker and no Distributed.jl workers. \n " *
                "You can attach workers later, and update the NodeManager with" *
                " `update!(nm::NodeManager)`."
    end
    local_metadata, compute_metadata = MrPhelps.worker_meta()
    return NodeManager( first( [ k for (k,v) in local_metadata ] ),
                        local_metadata,
                        compute_metadata)
end

function update!(nm::NodeManager)
    if Distributed.nworkers() == 1
        @info   "NodeManager instance created with only a local worker and no Distributed.jl workers. \n " *
                "You can attach workers later, and update the NodeManager with" *
                " `update!(nm::NodeManager)`."
    end
    local_metadata, compute_metadata = MrPhelps.worker_meta()
    nm.masterID  = first( [ k for (k,v) in local_metadata ] )
    nm.localmeta = local_metadata
    nm.computemeta = compute_metadata
    return nm
end
