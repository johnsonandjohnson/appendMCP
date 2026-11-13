# Apply a CPW (or other WLR) test to a simulated dataset

Used by [`apply_hypothesis_tests()`](apply_hypothesis_tests.md) when
`test_method` is a WLR family. Computes the observed WLR Z-statistic and
information from IPD.

## Usage

``` r
test_wlr(df, endpoint, strata, control, test, weight)
```

## Arguments

- df:

  Simulated IPD data frame (must have columns: stratum, treatment,
  endpoint event/time columns).

- endpoint:

  Character endpoint name.

- strata:

  Character vector of strata to include.

- control:

  Character control arm name.

- test:

  Character test arm name.

- weight:

  Weight argument (from
  [`test_method_to_wlr_weight()`](test_method_to_wlr_weight.md)).

## Value

Named numeric vector with elements `z_stat` and `sample_size` (number at
risk used in the test).
