# Create multiplicity graph visualization

Generates a visual representation of a graphical multiple comparison
procedure using the gMCPLite package. The graph shows hypotheses as
nodes with their initial alpha weights and transition probabilities
between hypotheses.

## Usage

``` r
plot_graph(graph)
```

## Arguments

- graph:

  A list containing graph structure with elements:

  g

  :   Square matrix of transition probabilities between hypotheses

  w

  :   Numeric vector of initial alpha weights for each hypothesis

## Value

A graph object from
[`hGraph`](https://merck.github.io/gMCPLite/reference/hGraph.html) that
can be plotted

## Details

The function validates the input graph structure and creates a visual
representation where:

- Nodes represent hypotheses with their alpha weights

- Edges show transition probabilities when hypotheses are rejected

- Self-loops are automatically handled by gMCPLite

## See also

[`hGraph`](https://merck.github.io/gMCPLite/reference/hGraph.html) for
the underlying visualization function

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a simple 2-hypothesis graph
graph <- list(
  g = matrix(c(0, 1, 1, 0), nrow = 2),
  w = c(0.025, 0.025)
)
fig   <- plot_graph(graph)
plot(fig)
} # }
```
