using Turing, StatsPlots

struct Component
  μ::Float64
  σ::Float64
end

function mixture_errors( components::Vector{Component}; number_of_samples = 50000 )
  @model mixingdist( x ) = begin
    a ~ truncated.( [ Normal( x[i], component.σ ) for (i, component) in enumerate(components) ], 0 , 1)
    closure = sum( a )
    Dirichlet( a ./ closure )
  end
  return sample( mixingstats( map( x -> x.μ, components ) ), HMC(0.1, 5), 50000)
end

default(size = (800, 800))

# Case #1: All components equal in concentration, and similar in small error
#should be nearly degenerate to normal distributions.
measurands_in_bounds = [  Component( 0.33, 0.1 ),
                          Component( 0.33, 0.1 ),
                          Component( 0.33, 0.1 )
                        ]
plot( mixture_errors( measurands_in_bounds ), title = "In Bounds Case (basically Normal)"  )
png("/home/caseykneale/Desktop/mixtures/Normal.png")

# Case #2: One component low in measured value with large uncertainty
# Should be far from normally distributed for this component
measurands_edge_case = [  Component( 0.05, 0.1 ),
                          Component( 0.45, 0.1 ),
                          Component( 0.50, 0.2 )
                        ]
plot( mixture_errors( measurands_edge_case ), title = "Edge Case" )
png("/home/caseykneale/Desktop/mixtures/Edge.png")
