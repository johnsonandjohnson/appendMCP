# Table 5: Boundary specifications

Table 5: Boundary specifications

## Usage

``` r
table5_hux(
  table5,
  info_fraction_digits = 2,
  pval_digits = 5,
  hurdle_digits = 3,
  prob_digits = 1,
  font_size = NULL
)
```

## Arguments

- table5:

  data.frame version of table5

- info_fraction_digits:

  Number of decimal places for information fraction

- pval_digits:

  Number of decimal places for nominal p-value and local alpha level

- hurdle_digits:

  Number of decimal places for exit hurdle

- prob_digits:

  Number of decimal places for local power (as percentage)

- font_size:

  Font size in points, or NULL to use document default

## Value

huxtable version of table5
