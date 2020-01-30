abstract type FileIterator end

"""
    interleavestrings(x::Vector{<:AbstractString}, y::Vector{<:AbstractString})

Interleaves two vectors of strings. `x` comes before `y`.
Shout out: Thanks, Don MacMillen from Slack!

"""
function interleavestrings(x::Vector{<:AbstractString}, y::Vector{<:AbstractString})
    lenx, leny = length(x), length(y)
    largest = max(lenx, leny)
    result = fill("", 2*largest)
    result[1:2:2*lenx] = x
    result[2:2:2*leny] = y
    return join(result)
end

struct Expand <: FileIterator
    statictxt::Vector{String}
    mapping::Any
    productiter::Base.Iterators.ProductIterator
end

"""
    Expand( str::String, replace_map::Dict{String,Vector{String}} )

Expand is an iterator that replaces keywords in a string, `str`, with all
permutations in the `replace_map`. To define a keyword it must be enclosed in
curly brackets `{...}`.

"""
function Expand( str::String, replace_map::Dict{String,Vector{String}} )
    locations, items, cuts = [], [], []
    #TODO: Char-wise/Trie search instead could be more performant?
    for ( curkey, item ) in replace_map
        firstunitofallmatches = first.( findall( "{" * curkey * "}", str ) ) .=> curkey
        @assert(length(firstunitofallmatches) == 1, "Cannot use keyword $curkey twice in expand statement.")
        locations = vcat( locations, firstunitofallmatches )
        push!( items, item )
    end
    #sort the order of the items found in the string by which come first!
    idx = sortperm(locations, by = x -> first( x ) )
    locations = locations[idx]
    #Handle edgecase where string starts with keyword to be replaced
    ( lastloc, tag ) = first( locations )
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

    return Expand( cuts, locations, Iterators.product( items[idx]... ) )
end

function Base.iterate( iter::Expand, state = ( nothing ) )
    if isnothing(state)
        subiter, state = collect( iterate( iter.productiter ) )
    else
        nextiter = iterate( iter.productiter, state )
        if isnothing( nextiter )
            return nothing
        end
        subiter, state = collect( nextiter )
    end
    return interleavestrings( iter.statictxt, collect( subiter ) ), state
end

mutable struct VariableGlob
    parsedsegments::Vector{String}
    parsedvariables::Vector{String}
    parsed_values::Vector{Any}#TODO: Type specific...
end

"""
    VariableGlob( path::String )

Given an input `path`, parse for variable names enclosed in curly brackets.
Returns a tuple of nonvariable elements of the path, and variable elements.

"""
function VariableGlob( path::String, expression::String )
    strlen          = length( expression )
    isenclosed      = false
    segments, variablenames = [], []
    cursor,   variable_cursor = 1, 1
    #Parse the text around curly brackets, and the text inside curly brackets into
    # 2 different vectors.
    for (i, chr) in enumerate( collect( expression ) )
        if chr == '{'
            if !isenclosed
                if i > 1
                    push!(segments, expression[ cursor : (i - 1 ) ] )
                    variable_cursor = i
                else
                    push!(segments, "" )
                end
                isenclosed = true
            else
                @error( "Enclosing symbol `{` found without matching `}`. \n Only single nested wild cards supported." )
            end
        elseif chr == '}'
            if isenclosed
                isenclosed = false
                cursor = i + 1
                push!( variablenames, expression[ ( variable_cursor + 1 ) : ( i - 1 ) ] )
            else
                @error( "Enclosing symbol `}` found without matching `{`." )
            end
        elseif i == strlen
            if !isenclosed
                push!( segments, expression[ cursor : strlen ] )
            else
                @error( "Enclosing symbol `{` found without matching `}`." )
            end
        end
    end
    #Safety checks
    @assert( length(unique(variablenames)) == length(variablenames), "Replicate variable names found in string. Cannot proceed." )
    @assert( all( length.(variablenames) .>= 1 ), "Variable name cannot be less then 1 character long!" )
    @assert( ( length(variablenames) < length(segments) ), "Filename cannot end with a wildcard." )
    #Clean up our understanding of the root directory...
    filematches = glob( join(segments, "*"), path  )
    #Now that we have a list of matching file names let's get their metadata
    segmentlengths = length.( segments )
    variables_count = length(variablenames)
    template = [ ]
    templatecount = 0
    for filematch in filematches
        idx = length(path)
        matchlen = length(filematch)
        tmpdict = Dict()
        for ( s, seglen ) in enumerate( segmentlengths )
            if s <= variables_count
                idx += seglen
                findnextseg = matchlen
                if s < length(segments)
                    findnextsegmatch = match( Regex( "(" * segments[s + 1] * ")s?" ), filematch)
                    if !isnothing(findnextsegmatch)
                        findnextseg = findnextsegmatch.offset - 1
                    end
                end
                tmpdict[ variablenames[ s ] ] = filematch[ (idx+1):(findnextseg) ]
                idx = findnextseg
            end
        end
        push!(template, tmpdict)
    end
    return VariableGlob( segments, variablenames, template )
end
