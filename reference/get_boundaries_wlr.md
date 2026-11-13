# Compute GSD boundary specs using WLR information

Drop-in counterpart to [`get_boundaries()`](get_boundaries.md) for WLR
families (cpw, fh, mb). Returns a tibble mirroring the structure
produced by
[`gsDesign2::gs_power_ahr()`](https://merck.github.io/gsDesign2/reference/gs_power_ahr.html)
so that the downstream extractors (get_powers, get_hurdles,
get_nominal_p, get_cum_alpha_spend, get_description_effect_size) work
without modification.

## Usage

``` r
get_boundaries_wlr(
  dist_type,
  control,
  test,
  sf,
  sfpar,
  nominal,
  enroll_rate,
  distribution,
  possible_weight,
  information_factor,
  max_information_factor,
  information_fractions,
  times_analysed,
  weight,
  t_star = NULL,
  alpha = 0.025
)
```

## Arguments

- dist_type:

  "tte" (binary endpoints never reach this path).

- control:

  Character name of the control treatment.

- test:

  Character name of the test treatment.

- sf:

  Spending function string.

- sfpar:

  Spending function parameter (or NULL/NA).

- nominal:

  Nominal alpha spending vector (or NULL/NA).

- enroll_rate:

  Processed enrollment data frame.

- distribution:

  Distribution data frame (fail_rate, dropout_rate, ...).

- possible_weight:

  Alpha weight from graphical MCP.

- information_factor:

  Vector of information factors.

- max_information_factor:

  Scalar max information factor.

- information_fractions:

  Vector of information fractions.

- times_analysed:

  Numeric vector of analysis times.

- weight:

  Weight argument from
  [`test_method_to_wlr_weight()`](test_method_to_wlr_weight.md).

- alpha:

  One-sided alpha level.

## Value

Result of
[`gsDesign2::gs_power_wlr()`](https://merck.github.io/gsDesign2/reference/gs_power_wlr.html).
