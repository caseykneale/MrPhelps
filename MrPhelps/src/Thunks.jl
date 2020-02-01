struct JobStatistics{A}
    elapsed_time::A
    bytes_allocated::A
end
JobStatistics() = JobStatistics( Series( Mean(), Variance() ), Series( Mean(), Variance() ))

struct JobStatisticsSample
    elapsed_time::Union{Missing, Float64}
    bytes_allocated::Union{Missing, Float64}
end
JobStatisticsSample() = JobStatisticsSample(missing, missing)

@enum WORKER_STATE begin
    available   = 0
    ready       = 1
    launched    = 2
    hasdata     = 3
    failed      = 4
end

mutable struct WorkerCommunication
    task_stats::MrPhelps.JobStatisticsSample
    last_task::Int
    state::WORKER_STATE
end

#All thunk code was copied with only superficial changes from ChainRulesCore.jl: Permalink below.
#https://github.com/JuliaDiff/ChainRulesCore.jl/blob/47f5354191773d73a5dc372cd049b01556f6145f/src/differentials/thunks.jl#L73

struct Thunk{F}
    f::F
end
(x::Thunk)() = x.f()

"""
    @thunk expression

Define a [`Thunk`](@ref) wrapping the `expression`, to lazily defer its evaluation.
https://github.com/JuliaDiff/ChainRulesCore.jl/blob/47f5354191773d73a5dc372cd049b01556f6145f/src/differentials/thunks.jl#L73
"""
macro thunk(expression)
    func = Expr(:->, Expr(:tuple), Expr(:block, __source__, expression))
    return :(Thunk($(esc(func))))
end

"""
    dispatch_task( fn::Union{Thunk, Function},
                        remote_hook::RemoteChannel{ Channel{ Any } },
                        local_hook::RemoteChannel{ Channel{ WorkerCommunication } },
                        task_ID::Int,
                        src = nothing )

Executes a worker task on a remote machine. Statistics are sent back to the local scheduler,
data is stored locally.

"""
function dispatch_task( fn::Union{Thunk, Function},
                        remote_hook::RemoteChannel{ Channel{ Any } },
                        local_hook::RemoteChannel{ Channel{ WorkerCommunication } },
                        task_ID::Int,
                        src = nothing )
    try
        stats = Base.gc_num()
        elapsedtime = Base.time_ns()
        #if the channel is empty call the base function to add stuff too it
        #Note State_channel is a global that gets created in execute_mission() on every worker!!!!
        if !isnothing( fn )
            if !isready( remote_hook ) #channel is empty! should be our first iteration
                if isnothing(src)
                    put!( remote_hook, fn()() )
                else
                    put!( remote_hook, fn()( src ) )
                end
            else
                #if the channel is full, put the previous result into the next function...
                curval = fn()( take!( remote_hook ) )
                put!( remote_hook, curval)
                println("new thing: $curval")
            end
        else
            put!(remote_hook, src )#is actually a string or metadata?
        end
        elapsedtime = Base.time_ns() - elapsedtime
        diff = Base.GC_Diff( Base.gc_num(), stats )
        jobstats = JobStatisticsSample( elapsedtime * 1e-9, diff.allocd * 1e-6 )
        put!( local_hook, WorkerCommunication( jobstats, task_ID, ready ) )
    catch #uh oh
        @info("Worker failed on task node: $task_ID .")
        put!( local_hook, WorkerCommunication( JobStatisticsSample(), task_ID, failed ) )
    end
end

"""
    reset_worker(  remote_hook::RemoteChannel{ Channel{ Any } },
                    local_hook::RemoteChannel{ Channel{ WorkerCommunication } })

Resets the remote and local hooks for a worker which has completed its tasking.

"""
function reset_worker(  remote_hook::RemoteChannel{ Channel{ Any } },
                        local_hook::RemoteChannel{ Channel{ WorkerCommunication } } )
    try
        #think the memory is already reset but the user should have access to this
        #isready(remote_hook) && put!( remote_hook, nothing ) #Reset memory
        put!( local_hook, WorkerCommunication( JobStatisticsSample(), 0, available ) )
    catch #uh oh
        @info("Failed to reset worker...")
        put!( local_hook, WorkerCommunication( JobStatisticsSample(), 0, failed ) )
    end
end
