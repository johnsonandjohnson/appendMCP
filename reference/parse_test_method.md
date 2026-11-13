# Parse a test_method string into a structured spec

Converts the user-facing string stored in
`config$hypotheses$test_method` (e.g. `"logrank"`, `"cpw(6)"`,
`"fh(0,1)"`) into an internal list with components `family` and
`params`.

## Usage

``` r
parse_test_method(method)
```

## Arguments

- method:

  Single character string.

## Value

A list with `$family` (character) and `$params` (list).

## Details

Supported families:

- logrank:

  Standard log-rank (no parameters)

- stratified_logrank:

  Stratified log-rank (no parameters)

- unpooled_proportions:

  Binary endpoint test (no parameters)

- pooled_proportions:

  Binary endpoint test (no parameters)

- cmh:

  Cochran-Mantel-Haenszel test (no parameters)

- cpw(t_star):

  Constant piecewise weight; `t_star` in months

- fh(rho,gamma):

  Fleming-Harrington weight

- mb(tau,w_max):

  Magirr-Burman weight
