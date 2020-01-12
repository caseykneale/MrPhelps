using Pkg
Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path="/home/caseykneale/Desktop/Playground/MrPhelps/"))
using MrPhelps
using CSV, DataFrames, Random

const entries = 11

datadir  = "Playground/MrPhelps/data/"
filefmt  = "expr_{experiment}_number_{number}.csv"
fullpath = Base.joinpath(datadir, filefmt)

fauxfilenames = Expand( fullpath, Dict( "experiment" => [ "A", "B", "C" ],
                                        "number"     => [ "1", "2" ] )
                      )

#Make some random 3 column CSV's and save them to disk via the expand call
for filename in fauxfilenames
    column_names = [ :name, :rand, :randn ]

    column_values = [ [ randstring(rand(1:10)[1] + 4)  for entry in 1:entries ],
                      [ rand(1)[1]              for entry in 1:entries ],
                      [ randn(1)[1]             for entry in 1:entries ] ]
    df = DataFrame( column_values, column_names )
    CSV.write(filename, df)
end

function VariableGlob( path::String )
    strlen          = length( path )
    isenclosed      = false
    segments        = []
    variablenames   = []
    cursor          = 1
    variable_cursor = 0

    for (i, chr) in enumerate( collect( path ) )
        if chr == '{'
            if !isenclosed
                if i > 1
                    push!(segments, path[ cursor : (i - 1 ) ] )
                    variable_cursor = i
                end
                isenclosed = true
            else
                @error( "Enclosing symbol `{` found without matching `}`. \n Only single nested wild cards supported." )
            end
        elseif ( chr == '}' )
            if isenclosed
                isenclosed = false
                cursor = i + 1
                push!(variablenames, path[ (variable_cursor+1) : (i-1)] )
            else
                @error( "Enclosing symbol `}` found without matching `{`." )
            end
        elseif i == strlen
            if !isenclosed
                push!(segments, path[ cursor : strlen ] )
            else
                @error( "Enclosing symbol `{` found without matching `}`." )
            end
        end
    end

    @assert( length(unique(variablenames)) == length(variablenames), "Replicate variable names found in string. Cannot proceed." )

    return segments, variablenames
end


VariableGlob( fullpath )
