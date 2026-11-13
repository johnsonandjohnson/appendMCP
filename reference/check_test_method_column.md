# Check test_method column

Validates that every non-NA value in a `test_method` column is either a
plain method name or a correctly-formed parametric WLR string. Calls
[`parse_test_method()`](parse_test_method.md) on each value so that bad
strings (e.g. `"cpw(bad)"`, `"unknown(1)"`) produce a clear error at
config-validation time rather than later in processing.

## Usage

``` r
check_test_method_column(df, col_name)
```

## Arguments

- df:

  Data frame containing the column.

- col_name:

  Name of the `test_method` column.
