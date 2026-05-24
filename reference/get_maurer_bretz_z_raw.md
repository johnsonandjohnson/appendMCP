# Simplified Maurer-Bretz procedure with matrix-based rejection tracking

This function implements the Maurer-Bretz graphical multiple comparison
procedure and tracks rejections in matrix form similar to p_obs
structure. It preserves the same logic as get_maurer_bretz_z().

## Usage

``` r
get_maurer_bretz_z_raw(pvec, analyses, hypotheses, graph)
```

## Arguments

- pvec:

  Numeric vector of p-values for all hypothesis-analysis combinations

- analyses:

  Data frame containing analysis definitions with timing information

- hypotheses:

  Data frame containing hypothesis definitions including index and
  analyses_analysed columns

- graph:

  List containing the graphical structure with elements:

  - g: Transition matrix between hypotheses

  - w: Initial weights for each hypothesis

## Value

Matrix of rejection indicators (0/1) with dimensions J x K, where J is
number of hypotheses and K is number of analyses. Element \[j,k\] = 1 if
hypothesis j was rejected at or before analysis k.

## Details

The function follows the same sequential testing procedure as
get_maurer_bretz_z() but tracks rejections in a matrix format where each
row represents a hypothesis and each column represents an analysis. Once
a hypothesis is rejected, all subsequent analyses for that hypothesis
are marked as rejected (1).
