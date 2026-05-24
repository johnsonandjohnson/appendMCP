# Calculate z bounds

Calculate z bounds

## Usage

``` r
calculate_z_bounds(
  info_levels = c(100, 200, 300, 400, 500)/4,
  alpha = 0.025,
  sfu = gsDesign::sfLDOF,
  sfupar = NULL,
  planned_max_info = 500/4
)
```

## Arguments

- info_levels:

  Information levels for analyses

- alpha:

  Type I error rate

- sfu:

  Spending function

- sfupar:

  Spending function parameters

- planned_max_info:

  Planned maximum information
