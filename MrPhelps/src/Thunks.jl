struct JobStatistics{A}
    elapsed_time::A
    bytes_allocated::A
end
JobStatistics() = JobStatistics(Series( Mean(), Variance() ), Series( Mean(), Variance() ))

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
    # Basically `:(Thunk(() -> $(esc(body))))` but use the location where it is defined. so we get useful stack traces if it errors.
    func = Expr(:->, Expr(:tuple), Expr(:block, __source__, expression))
    return :(Thunk($(esc(func))))
end

"""
    recieved_task( fn::Union{Thunk, Function} )

Executes a worker task on a remote machine. Statistics are sent back to the local scheduler,
data is stored locally.

"""
function dispatch_task( fn::Union{Thunk, Function},
                        local_hook::RemoteChannel{ Channel{ WorkerCommunication } },
                        task_ID::Int,
                        src = nothing )
    #try
        stats = Base.gc_num()
        elapsedtime = Base.time_ns()
        #if the channel is empty call the base function to add stuff too it
        #Note State_channel is a global that gets created in execute_mission() on every worker!!!!
        if !isnothing( fn )
            global state_channel
            if !isready( state_channel )#channel is empty!
                println("???")
                put!( state_channel, isnothing( src ) ? fn()() : fn()(src) )
            else
                println("???2")
                #if the channel is full, put the previous result into the next function...
                put!( state_channel, fn()(take!( state_channel )) )
            end
        else
            println("???3")
            put!(state_channel, src )#is actually a string or metadata?
        end
        elapsedtime = Base.time_ns() - elapsedtime
        diff = Base.GC_Diff( Base.gc_num(), stats )
        println("...")
        jobstats = JobStatisticsSample( elapsedtime * 1e-9, diff.allocd * 1e-6 )
        println("!!!")
        put!( local_hook, WorkerCommunication( jobstats, task_ID, ready ) )
    #catch #uh oh
    #    put!( local_hook, WorkerCommunication( JobStatisticsSample(), task_ID, failed ) )
        #if this fails we've lost a worker?
    #end
end
