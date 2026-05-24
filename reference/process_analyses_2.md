# Process analyses with hypothesis information

Appends hypothesis-specific information to analyses by adding: -
hypotheses_information_fractions: Information fractions for each
hypothesis at this analysis - hypotheses_information: Absolute
information levels (fractions × max information)

## Usage

``` r
process_analyses_2(analyses, hypotheses)
```

## Arguments

- analyses:

  Processed analyses from process_analyses_1

- hypotheses:

  Processed hypotheses

## Value

Final processed analyses data frame with 2 additional hypothesis-linked
columns
