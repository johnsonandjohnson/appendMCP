# Plot time-to-event hazard rates

Plot time-to-event hazard rates

## Usage

``` r
plot_distribution_tte_hazard(distribution_tte, time_grid = seq(0, 60, 0.5))
```

## Arguments

- distribution_tte:

  Time-to-event distribution data frame with columns: endpoint, stratum,
  treatment, duration, fail_rate, dropout_rate

- time_grid:

  Time sequence for plotting (default: 0 to 60 months)

## Value

ggplot object
