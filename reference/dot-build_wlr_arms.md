# Build npsurvSS arm objects from appendMCP distribution tables

Constructs the `arm0` (control) and `arm1` (test) objects expected by
the gsDesign2 WLR internals. Multiple strata are pooled to a single
effective stratum via
[`.pool_strata_fail_rate()`](dot-pool_strata_fail_rate.md).

## Usage

``` r
.build_wlr_arms(control, test, enroll_rate, fail_rate, total_time)
```

## Arguments

- control:

  Character name of the control treatment.

- test:

  Character name of the test treatment.

- enroll_rate:

  Processed enrollment data frame (arm_rate, duration, index).

- fail_rate:

  Distribution data frame (treatment, duration, fail_rate, dropout_rate,
  stratum).

- total_time:

  Scalar: calendar time at the analysis.

## Value

A list with components `arm0` and `arm1`.
