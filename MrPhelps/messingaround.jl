using MrPhelps
using LightGraphs, GraphRecipes, Plots
using Pkg
Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path="/home/caseykneale/Desktop/Playground/MrPhelps/"))

mutable struct Sherlock
    moduleinst        ::Module
    modulename        ::Symbol
    allnames          ::Vector{Symbol}
    functions         ::Vector{Symbol}
    types             ::Vector{Symbol}
    abstracttypes     ::Vector{Symbol}
    undefined_exports ::Vector{Symbol}
    graph             ::SimpleDiGraph
    nv                ::Int
    tag               ::Dict{Int, Symbol}
    lookup            ::Dict{Symbol, Int}
end

function safeisfield(m::Module, s::Symbol, t::Type)
    try
        f = getfield(m, s)
        return isa(f, t) && !isa(f, Function)
    catch
        return false
    end
end

function safeisnotabstract(m::Module, s::Symbol, t::Type)
    result = safeisfield(m, s, t)
    if (result && hasfield( typeof(getfield(m, s)), :abstract))
        return !getfield(m, s).abstract
    else
        return false
    end
end

function safeisabstract(m::Module, s::Symbol, t::Type)
    result = safeisfield(m, s, t)
    if (result && hasfield( typeof(getfield(m, s)), :abstract))
        return getfield(m, s).abstract
    else
        return false
    end
end

function Sherlock(moduleinst::Module)
    modname     = Symbol(moduleinst)
    allnames    = [ n for n in names( moduleinst ) ]
    nv          = length( allnames )
    graph       = SimpleDiGraph( nv )
    tags        = Dict( 1:nv .=> allnames )
    lookup      = Dict( allnames .=> 1:nv )
    #remove package name from list
    allnames    = allnames[ allnames .!= modname ]
    fns         = [ safeisfield(moduleinst, curname, Function ) for curname in allnames ]
    types       = [ safeisnotabstract(moduleinst, curname, Type ) && !(string(curname)[1] == '@') for curname in allnames]
    abstypes    = [ safeisabstract(moduleinst, curname, Type ) && !(string(curname)[1] == '@') for curname in allnames]
    others      = (fns .+ types) .== 0
    return Sherlock(    moduleinst, modname, allnames,
                        allnames[fns], allnames[types], allnames[abstypes], allnames[others],
                        graph, nv, tags, lookup )
end


function buildgraph( sher::Sherlock )
    #Dive into the types to look for type relationships
    for stype in sher.types
        thisnode = sher.lookup[stype]
        nodefield = getfield( sher.moduleinst, stype )
        for subtype in fieldtypes( nodefield )
            if subtype in [ getfield( sher.moduleinst, st ) for st in sher.types]
                add_edge!( sher.graph, sher.lookup[ Symbol( subtype ) ] , thisnode )
            end
        end
    end

end


sherlock = Sherlock( MrPhelps )
buildgraph( sherlock )

Plots.default(size = (1000, 1000))

graphplot(sherlock.graph,
          markersize = 0.065,
          markercolor = range(colorant"lightblue", stop=colorant"lightgreen", length=sherlock.nv),
          names = [ sherlock.tag[i] for i in 1:sherlock.nv ] ,
          fontsize = 10,
          linecolor = :darkgrey,
          title = "Sherlock Type Graph: $(sherlock.modulename)"
          )

png("/home/caseykneale/Desktop/Sherlock/pics/mrphelps.png")
