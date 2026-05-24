# Plot time-to-event survival curves

Plot time-to-event survival curves

## Usage

``` r
plot_distribution_tte(
  distribution_tte,
  time_grid = seq(0, 60, 0.5),
  landmark_times = c(12, 24, 36)
)
```

## Arguments

- distribution_tte:

  Time-to-event distribution data frame with columns: endpoint, stratum,
  treatment, duration, fail_rate, dropout_rate

- time_grid:

  Time sequence for plotting (default: 0 to 60 months)

- landmark_times:

  Times for survival rate labels (default: 12, 24, 36 months)

## Value

ggplot object
