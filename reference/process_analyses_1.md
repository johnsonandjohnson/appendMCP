# Process analyses with timing information

Transforms the input analyses data frame by appending computed
columns: - index: Sequential row numbers for analysis identification -
dist_type: Distribution type ("tte" or "bin") matched from distribution
data - hypotheses_analysed: List of hypothesis indices that use each
analysis - maturity_time: Time point for binary endpoint maturity -
enroll_rate: Nested enrollment rates filtered by strata/treatments -
distribution: Nested distribution parameters filtered by
endpoint/strata/treatments - time: Expected analysis timing (sample size
or events driven) - description_trigger_short/long: Human-readable
analysis trigger descriptions

## Usage

``` r
process_analyses_1(analyses, enroll_rate, distribution, hypotheses)
```

## Arguments

- analyses:

  Analysis specifications

- enroll_rate:

  Enrollment rate data

- distribution:

  Distribution data

- hypotheses:

  Hypothesis specifications

## Value

Processed analyses data frame with 8 additional computed columns
