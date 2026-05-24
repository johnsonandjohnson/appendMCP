# Get boundary specifications for group sequential design

Get boundary specifications for group sequential design

## Usage

``` r
get_boundaries(
  dist_type,
  control,
  test,
  sf,
  sfpar,
  nominal,
  enroll_rate,
  distribution,
  possible_weight,
  control_pooled_rate,
  test_pooled_rate,
  information_factor,
  max_information_factor,
  information_fractions,
  times_analysed = NULL,
  alpha = 0.025
)
```

## Arguments

- dist_type:

  Type of endpoint (binary or time-to-event)

- control:

  Control treatment character string

- test:

  Test treatment character string

- sf:

  Spending function string (in rpact terminology)

- sfpar:

  Spending function parameter (if needed)

- nominal:

  Nominal spend information (if using)

- enroll_rate:

  Enrollment rate object

- distribution:

  Distributional information object

- possible_weight:

  Weight in the analysis (from the graphical test)

- control_pooled_rate:

  Control arm pooled rate (for binary outcomes)

- test_pooled_rate:

  Test arm pooled rate (for binary outcomes)

- information_factor:

  Information factors (either ubjects or events)

- max_information_factor:

  Maximum information factor (either max subjects or max events)

- information_fractions:

  Information fractions across the analyses

- times_analysed:

  Analysis times (for time-to-event endpoints)

- alpha:

  Type I error rate

## Value

Boundary specifications object
