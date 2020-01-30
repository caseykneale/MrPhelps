using Pkg
Pkg.API.develop(Pkg.PackageSpec(name="MrPhelps", path="/home/caseykneale/Desktop/Playground/MrPhelps/"))
using MrPhelps
using CSV, DataFrames, Random

const entries = 111

datadir  = "Playground/MrPhelps/data/"
filefmt  = "expr_{experiment}_number_{num}.csv"
fullpath = Base.joinpath(datadir, filefmt)

fauxfilenames = Expand( fullpath, Dict( "experiment" => [ "A", "B", "C" ],
                                        "num"     => [ "1", "2" ] )
                      )

#Make some random 3 column CSV's and save them to disk via the expand call
for filename in fauxfilenames
    column_names = [ :name, :rand, :randn ]

    column_values = [ [ randstring(rand(1:10)[1] + 4)   for entry in 1:entries ],
                      [ rand(1)[1]                      for entry in 1:entries ],
                      [ randn(1)[1]                     for entry in 1:entries ] ]
    df = DataFrame( column_values, column_names )
    CSV.write(filename, df)
end

mock_data_meta = VariableGlob( datadir, filefmt )

println.( mock_data_meta.parsed_values )
