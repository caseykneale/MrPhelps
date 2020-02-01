#!/usr/bin/env julia
#Start Test Script
using Test

#Test Case
@testset "Expand" begin
    tst = "a{name}b{number}c.ext"
    semantics = Dict(   "name"    => [ "great", "okay", "bad" ],
                        "number"  => [ "1", "2", "3" ],
                        "slumber" => [ "z", "zz","zzz" ] )
    exper = [ i for i in Expand(tst,semantics) ]
    @test all( exper .== ["agreatb1c.ext", "aokayb1c.ext", "abadb1c.ext", "agreatb2c.ext", "aokayb2c.ext", "abadb2c.ext", "agreatb3c.ext", "aokayb3c.ext", "abadb3c.ext"] )
end
