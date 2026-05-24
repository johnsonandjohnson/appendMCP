# Example Study Configuration List

A list containing study design parameters for an example study,
including analysis, hypothesis, enrollment rate, and distribution
parameter specifications.

## Usage

``` r
example_study_config
```

## Format

A list with the following components:

- study_name:

  Character string with study name

- study_description:

  Character string describing the study

- alpha:

  Numeric value for overall type I familywise error-rate

- analyses:

  Tibble with analysis triggers, including endpoint, strata, treatment,
  sample size, and event information

- hypotheses:

  Tibble with hypothesis specifications, including type, endpoint, and
  spending functions

- enroll_rate:

  Tibble with enrollment rates by stratum

- distribution_tte:

  Tibble with time-to-event endpoint distribution parameters by stratum
  and arm

- distribution_bin:

  Tibble with binary endpoint distribution parameters by stratum and arm

- graph:

  List containing graphical testing procedure matrix and weights

## Source

Internal template configuration

## Examples

``` r
data(example_study_config)
example_study_config$study_name
#> [1] "Example Study"
example_study_config$analyses
#> # A tibble: 4 × 7
#>   endpoint strata    treatments sample_size events power_subsets_any
#>   <chr>    <list>    <list>           <dbl>  <dbl> <list>           
#> 1 CR       <chr [2]> <chr [2]>          500     NA <named list [2]> 
#> 2 OS       <chr [2]> <chr [2]>           NA    234 <named list [2]> 
#> 3 OS       <chr [2]> <chr [2]>           NA    284 <named list [2]> 
#> 4 OS       <chr [2]> <chr [2]>           NA    334 <named list [2]> 
#> # ℹ 1 more variable: power_subsets_all <list>
```
