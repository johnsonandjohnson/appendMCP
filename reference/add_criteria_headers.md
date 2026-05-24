# Function to add criteria headers (removes criteria and time columns)

Function to add criteria headers (removes criteria and time columns)

## Usage

``` r
add_criteria_headers(hux_table, data, n_cols, time_digits = 1)
```

## Arguments

- hux_table:

  A hux table to modify

- data:

  the original data.frame version of the above table

- n_cols:

  Number of columns

- time_digits:

  Number of decimal places for expected analysis time

## Value

Modified hux table
