function interleavestrings(x::Vector{String}, y::Vector{String})
    lenx, leny = length( x ), length( y )
    largest = max( lenx, leny )
    result = ""
    for i in 1 : largest
        xadd = ( i <= lenx ) ? x[ i ] : ""
        yadd = ( i <= leny ) ? y[ i ] : ""
        result = result * xadd * yadd
    end
    return result
end

struct Expand
    statictxt::Vector{String}
    mapping::Any
    productiter::Base.Iterators.ProductIterator
end

function Expand( str::String, replace_map::Dict{String,Vector{String}} )
    locations, items, cuts = [], [], []
    #TODO: Char-wise search instead could be more performant?
    for ( curkey, item ) in replace_map
        firstunitofallmatches = first.( findall( "{" * curkey * "}", str ) ) .=> curkey
        @assert(length(firstunitofallmatches) == 1, "Cannot use keyword $curkey twice in expand statement.")
        locations = vcat( locations, firstunitofallmatches )
        push!( items, item )
    end
    #sort the order of the items found in the string by which come first!
    sort!(locations, by = x -> first( x ) )
    #Handle edgecase where string starts with keyword to be replaced
    ( lastloc, tag ) = locations[ 1 ]
    firstcut = ( lastloc[ 1 ] > 1 ) ? str[ 1 : ( lastloc - 1 ) ] : ""
    push!( cuts, firstcut )
    for item in 1 : ( length( locations ) - 1 )
        ( loc, tag ) = locations[ item ]
        ( nextloc, tag2 ) = locations[ item + 1 ]
        push!( cuts,  str[ ( loc + length( tag ) + 2 ) : ( nextloc - 1 ) ] )
    end
    #handle end of string, edge case is implicit
    ( lastloc, tag ) = locations[ end ]
    push!( cuts,  str[ ( lastloc + length( tag ) + 2 ) : end] )

    return Expand( cuts, locations, Iterators.product( items... ) )
end

function Base.iterate( iter::Expand, state = ( nothing ) )
    if isnothing(state)
        subiter, state = collect( iterate( expanded.productiter ) )
    else
        nextiter = iterate( expanded.productiter, state )
        if isnothing( nextiter )
            return nothing
        end
        subiter, state = collect( nextiter )
    end
    return interleavestrings(iter.statictxt, collect(subiter)) , state
end
