struct JobStatistics
    elapsed_time::Float64
    bytes_allocated::Float64
end

@enum WORKER_STATE begin
    available   = 0
    ready       = 1
    launched    = 2
    hasdata     = 3
    failed      = 4
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
function recieved_task( fn::Union{Thunk, Function} )
    try
        stats = gc_num()
        elapsedtime = time_ns()
        returnvalue = fn()
        elapsedtime = time_ns() - elapsedtime
        diff = GC_Diff( gc_num(), stats )
        return JobStatistics( elapsedtime * 1e-9, diff.allocd * 1e-6 ), returnvalue
    catch #uh oh
        return missing, missing
    end
end
