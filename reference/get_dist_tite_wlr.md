# Compute WLR Z-statistic distribution for simulation

Counterpart to `get_dist_tite()` for WLR families. Returns
`list(EZ, CovZ)` suitable for consumption by `get_mvn()`.

## Usage

``` r
get_dist_tite_wlr(
  control,
  test,
  enroll_rate,
  fail_rate,
  times_analysed,
  weight
)
```

## Arguments

- control:

  Character name of the control treatment.

- test:

  Character name of the test treatment.

- enroll_rate:

  Processed enrollment data frame.

- fail_rate:

  Distribution data frame.

- times_analysed:

  Numeric vector of analysis times.

- weight:

  Weight argument as returned by
  [`test_method_to_wlr_weight()`](test_method_to_wlr_weight.md).

## Value

List with components `EZ` and `CovZ`.
