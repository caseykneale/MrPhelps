#SSH Cluster manager...
# machines => array of machine elements
# machine => address or (address, cnt)
# address => string of form `[user@]host[:port] bind_addr[:bind_port]`
# cnt => :auto or number
# :auto launches NUM_CORES number of workers at address
# number launches the specified number of workers at address

struct SSHMachine
    address::String #string of form `[user@]host[:port] bind_addr[:bind_port]`
    core_count::Union{Symbol, Int}
end

function machine(addr::String, core_count::Symbol)
    @assert( core_count == :auto, "Only accepted core Symbol is `:auto`, which uses NUM_CORES workers." )
    return SSHMachine(addr, core_count)
end

function machine(addr::String, core_count::Int)
    @assert( core_count >= 0, "Cannot make negative workers.." )
    return SSHMachine(addr, core_count)
end
