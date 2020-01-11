struct WorkerMetaData
    workertype::Type
    address::Union{Missing, String}
    CPU_speed::Int32
    #port::Int
end

"""
        worker_meta()

Returns a two dictionaries (local, and compute) containing metadata of all workers in scope.
This is for quick access to otherwise nested information and seperation of compute resources.
"""
function worker_meta()
    local_metadata, compute_metadata   = Dict(),  Dict()
    @sync for worker in Distributed.PGRP.workers
        @assert( !haskey(local_metadata, worker.id) )
        @assert( !haskey(compute_metadata, worker.id) )
        #Handle special case of master node
        if isa( worker, Distributed.LocalProcess )
            try
                cpuspd = Sys.cpu_info()[1].speed
                local_metadata[ worker.id ]   = WorkerMetaData( Distributed.LocalProcess,
                                                                worker.bind_addr,
                                                                cpuspd )
            catch err
                if isa(err, UndefRefError)
                    cpuspd = Sys.cpu_info()[1].speed
                    local_metadata[ worker.id ]   = WorkerMetaData( Distributed.LocalProcess,
                                                                    missing,
                                                                    cpuspd  )
                end
            end
        else
            cpuspd_c = @spawnat worker.id Sys.cpu_info()[1].speed
            cpuspd = fetch(cpuspd_c)
            println(cpuspd)
            compute_metadata[ worker.id ] = WorkerMetaData( typeof( worker.manager ),
                                                            worker.config.host,
                                                            cpuspd )
        end
    end
    if length(compute_metadata) == 0
        compute_metadata = missing
    end
    return local_metadata, compute_metadata
end
