# Check required numeric field with bounds

Check required numeric field with bounds

## Usage

``` r
check_required_numeric_bounded(
  config,
  field_name,
  lower_bound,
  upper_bound,
  strict = FALSE
)
```

## Arguments

- config:

  Configuration list

- field_name:

  Name of field to check

- lower_bound:

  Lower bound (exclusive if strict=TRUE)

- upper_bound:

  Upper bound (exclusive if strict=TRUE)

- strict:

  If TRUE, bounds are exclusive; if FALSE, inclusive
