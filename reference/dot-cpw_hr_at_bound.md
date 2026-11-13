# Back-calculate post-t_star HR at a CPW Z boundary

For a CPW hypothesis, the exit hurdle expressed as a hazard ratio is not
a single overall HR but rather the HR that would need to hold *after*
`t_star` in order to just cross the Z boundary. This function finds that
post-`t_star` HR via 1-D root-finding: it varies the test-arm hazard
rate only for duration intervals whose cumulative start time exceeds
`t_star`, holding the pre-`t_star` intervals fixed (those events receive
zero CPW weight so they do not influence the statistic).

## Usage

``` r
.cpw_hr_at_bound(
  z_bound,
  info_total,
  t_star,
  control,
  test,
  enroll_rate,
  distribution,
  t_analysis,
  weight
)
```

## Arguments

- z_bound:

  Scalar Z boundary value (upper, so positive).

- info_total:

  Scalar total Fisher information (\\\sigma^2 \times N\\).

- t_star:

  CPW threshold (months); events at or before this time receive zero
  weight.

- control:

  Character name of the control arm.

- test:

  Character name of the test arm.

- enroll_rate:

  Processed enrollment data frame.

- distribution:

  Distribution data frame.

- t_analysis:

  Calendar time of the analysis (for arm construction).

- weight:

  Weight argument (from
  [`test_method_to_wlr_weight()`](test_method_to_wlr_weight.md)).

## Value

Scalar HR (between 0 and 1 exclusive for a beneficial treatment).
