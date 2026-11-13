# Return TRUE iff a test_method string names a WLR-family method

WLR families (cpw, fh, mb) need the WLR information / boundary path. All
other methods use the AHR path or binary path.

## Usage

``` r
is_wlr_method(method)
```

## Arguments

- method:

  Single character string.

## Value

Logical scalar.
