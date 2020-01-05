"""
        worker_meta()

returns a Dictionary containing metadata of all workers in scope.
"""
function worker_meta()
    metadata = Dict()
    @sync for worker in Distributed.PGRP.workers
        @assert( !haskey(metadata, worker.id) )
        #Handle special case of master node
        if isa( worker, Distributed.LocalProcess )
            metadata[worker.id] = ( worker.bind_addr, Distributed.LocalProcess )
        else
            metadata[worker.id] = ( worker.config.host, typeof( worker.manager ) )
        end
    end
    return metadata
end
