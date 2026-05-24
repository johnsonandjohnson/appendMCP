# Process hypotheses with boundary specifications

Transforms hypotheses data frame by appending computed columns: - index,
dist_type: Basic indexing and distribution type lookup - treatments:
Combined control/test treatment vectors - sfpar, nominal: Spending
function parameters (if missing) - description_sf, description_max_info:
Human-readable descriptions - enroll_rate, distribution: Nested data
filtered to hypothesis-specific combinations - maturity_time: Binary
endpoint timing - times_analysed: Analysis timing from linked analyses -
information_factor, max_information_factor, information_fractions: GSD
information calculations - weights: Weight scenarios (unnested, creating
multiple rows per hypothesis) - control_pooled_rate, test_pooled_rate:
Pooled rates for binary endpoints - specs, power, hurdles, nominal_p:
Boundary specifications from GSD calculations - description_effect_size:
Effect size descriptions

## Usage

``` r
process_hypotheses(
  hypotheses,
  analyses,
  enroll_rate,
  distribution,
  weights,
  alpha = 0.025
)
```

## Arguments

- hypotheses:

  Hypothesis specifications

- analyses:

  Processed analyses

- enroll_rate:

  Enrollment rate data

- distribution:

  Distribution data

- weights:

  Weight scenarios

- alpha:

  Type I error rate

## Value

Processed hypotheses with 18+ additional computed columns, expanded by
weight scenarios
