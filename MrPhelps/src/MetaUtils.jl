flip( a::Dict ) = Dict( Iterators.flatten( [ v .=> k for (k,v) in a ] ) )

struct WorkerMetaData
    workertype::Type
    address::Union{Missing, String}
    CPU_speed::Int32
    RAM_available::UInt64
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
                ram = Sys.free_memory()
                cpuspd = Sys.cpu_info()[1].speed
                local_metadata[ worker.id ]      = WorkerMetaData( Distributed.LocalProcess,
                                                                worker.bind_addr, cpuspd, ram )
            catch err
                if isa(err, UndefRefError)
                    ram = Sys.free_memory()
                    cpuspd = Sys.cpu_info()[1].speed
                    local_metadata[ worker.id ]   = WorkerMetaData( Distributed.LocalProcess,
                                                                    missing, cpuspd, ram  )
                end
            end
        else
            cpuspd = fetch( @spawnat worker.id Sys.cpu_info()[1].speed )
            ram = fetch( @spawnat worker.id Sys.free_memory() )
            compute_metadata[ worker.id ] = WorkerMetaData( typeof( worker.manager ),
                                                            worker.config.host, cpuspd, ram )
        end
    end
    if length(compute_metadata) == 0
        compute_metadata = missing
    end
    return local_metadata, compute_metadata
end
