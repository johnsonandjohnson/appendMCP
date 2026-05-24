# Execute simulations for marginal operating characteristics

Calculates marginal operating characteristics using Monte Carlo
simulation with Maurer-Bretz graphical procedure. Generates 3D rejection
array and computes comprehensive power metrics including individual
hypothesis power, subset power, and expected analysis timing.

## Usage

``` r
exec_sims(
  analyses,
  hypotheses,
  graph,
  method = "z",
  sims = 1000,
  alpha = 0.025
)
```

## Arguments

- analyses:

  Processed analyses data frame

- hypotheses:

  Processed hypotheses data frame

- graph:

  Graph object with transition matrix and weights

- method:

  Method for test statistics (default "z")

- sims:

  Number of simulations

- alpha:

  Overall Type I error rate

## Value

List with marginal_oc containing:

- oc_at_analyses: Power metrics by analysis (individual, any, all)

- oc_across_analyses: Expected analysis index and expected time for
  first rejection

## Details

Workflow: 1. Collapse hypotheses by endpoint, extract distribution
parameters 2. Generate MVN distribution for correlated test statistics
3. Process rejection rules and alpha spending thresholds 4. Simulate
p-values from MVN, apply Maurer-Bretz to each simulation 5. Build 3D
rejection array \[J hypotheses × K analyses × S simulations\] 6. Compute
power metrics via get_sim_oc()
