# Dataset simulation

Dataset simulation

## Usage

``` r
sim_dataset(
  enroll_rate,
  distribution_tte,
  distribution_bin,
  n,
  n_min_per_stratum,
  n_max_per_stratum,
  correlation_matrix,
  seed = Sys.time()
)
```

## Arguments

- enroll_rate:

  Data frame with enrollment rates

- distribution_tte:

  Distribution parameters for time-to-event endpoints

- distribution_bin:

  Distribution parameters for binary endpoints

- n:

  Total sample size

- n_min_per_stratum:

  Minimum sample size per stratum

- n_max_per_stratum:

  Maximum sample size per stratum

- correlation_matrix:

  Correlation matrix for endpoints

- seed:

  Random seed for reproducibility
