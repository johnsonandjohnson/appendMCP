# Pool a multi-stratum fail_rate table to a single effective stratum

[`gsDesign2::gs_power_wlr`](https://merck.github.io/gsDesign2/reference/gs_power_wlr.html)
/ `gs_info_wlr` (via `gs_create_arm`) only support a single stratum.
This helper computes stratum-size-weighted average hazard rates so that
the multi-stratum design can be represented as a single effective
stratum, matching the approach used internally by
[`gsDesign2::ahr()`](https://merck.github.io/gsDesign2/reference/ahr.html)
for the AHR path.

## Usage

``` r
.pool_strata_fail_rate(fail_rate, enroll_rate, treatment)
```

## Arguments

- fail_rate:

  Distribution data frame with columns `stratum`, `treatment`,
  `duration`, `fail_rate`, `dropout_rate`.

- enroll_rate:

  Processed enrollment data frame (with `arm_rate`, `stratum_treatment`,
  `duration`).

- treatment:

  Character name of the treatment arm to pool.

## Value

A one-row-per-duration-period data frame with columns `duration`,
`fail_rate`, `dropout_rate` representing the pooled effective stratum.
