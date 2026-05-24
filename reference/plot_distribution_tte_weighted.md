# Plot enrollment-weighted survival by hypothesis

Plot enrollment-weighted survival by hypothesis

## Usage

``` r
plot_distribution_tte_weighted(
  hypotheses,
  distribution_tte,
  enroll_rate,
  time_grid = seq(0, 60, 0.5),
  landmark_times = c(12, 24, 36)
)
```

## Arguments

- hypotheses:

  Hypotheses object from processed config

- distribution_tte:

  Time-to-event distribution data frame

- enroll_rate:

  Enrollment rate data frame

- time_grid:

  Time sequence for plotting

- landmark_times:

  Times for survival rate labels

## Value

ggplot object
