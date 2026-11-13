# Convert a parsed test_method spec to a gsDesign2-style weight argument

Returns the value that should be passed as the `weight` argument to the
internal WLR delta/sigma2 functions (.gs_delta_wlr_internal,
.gs_sigma2_wlr_internal).

## Usage

``` r
test_method_to_wlr_weight(spec)
```

## Arguments

- spec:

  Output of [`parse_test_method()`](parse_test_method.md).

## Value

Either the string `"logrank"` or a list with `$method` and `$param`.
