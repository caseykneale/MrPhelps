mutable struct NodeManager
    masterID::Union{ Missing, Int }
    localmeta::Union{ Missing, Dict{Int64, MrPhelps.WorkerMetaData} }
    computemeta::Union{ Missing, Dict{Int64, MrPhelps.WorkerMetaData} }
end

"""
    NodeManager()

Constructs a NodeManager objects. This object contains metadata about the processes
available to Distributed.jl.

"""
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

"""
    update!(nm::NodeManager)

Updates a NodeManager instance `nm` via the processes present in Distributed.jl .

"""
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

"""
    availablemachines( nm::NodeManager )

Takes a NodeManager(`nm`) as input and returns a dictionary of whose keys are
unique hosts and whose values are vectors of their Process ID numbers.

"""
function availablemachines( nm::NodeManager )
    addresses = unique( [ worker_meta.address for ( id, worker_meta ) in nm.computemeta ] )
    groupedby = Dict()
    for addr in addresses
        groupedby[addr] = [ meta.address for (k, meta) in nm.computemeta if ( meta.address == addr ) ]
    end
    return groupedby
end
