# Simulation with data.table optimization

Simulation with data.table optimization

## Usage

``` r
sim_outcomes(
  enroll_data,
  distribution_tte,
  distribution_bin,
  correlation_matrix
)
```

## Arguments

- enroll_data:

  Data frame with enrollment data containing columns Si, Ri, Ti

- distribution_tte:

  Distribution parameters for time-to-event endpoints

- distribution_bin:

  Distribution parameters for binary endpoints

- correlation_matrix:

  Correlation matrix for endpoints
