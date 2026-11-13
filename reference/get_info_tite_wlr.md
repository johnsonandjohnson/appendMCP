# Compute WLR information (sigma^2) at a vector of analysis times

Uses the internal `.gs_sigma2_wlr_internal` function (which supports the
"custom" weight branch) rather than calling the gsDesign2 namespace.

## Usage

``` r
get_info_tite_wlr(
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

Numeric vector of information values (one per analysis time).
