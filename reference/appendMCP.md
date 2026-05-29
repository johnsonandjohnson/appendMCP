# Generate analysis documentation for graphical MCPs in group sequential trials

appendMCP generates analysis documentation for graphical multiple
comparison procedures (MCPs) in group sequential design (GSD) clinical
trials. Given a study configuration, it produces summary tables,
diagnostic plots, and a fully formatted R Markdown report suitable for
appending to a statistical analysis plan (SAP).

## Main Functions

- [`load_config_from_repository`](load_config_from_repository.md):

  Load built-in configurations

- [`process_config`](process_config.md):

  Process design configurations and calculate operating characteristics

- [`generate_report`](generate_report.md):

  Generate comprehensive HTML or Word reports

- [`create_study`](create_study.md):

  Scaffold a new study from built-in templates

## Quick Start


    library(appendMCP)

    config  <- load_config_from_repository("example_study")
    results <- process_config(config)
    generate_report(results)

## What the Package Produces

- Table 1:

  Hypothesis summary (endpoint, type, spending function)

- Table 2:

  Analysis schedule by hypothesis (timing, information fractions)

- Table 3:

  Analysis schedule by analysis (all hypotheses at each look)

- Table 4:

  Weight scenarios under the graphical MCP

- Table 5:

  Boundary specifications (nominal p-values, information fractions,
  local power)

- Table 6a / 6b:

  Simulation-based operating characteristics by analysis and overall

- Plots:

  Graph diagram, information fractions, alpha spending, enrollment,
  time-to-event and binary endpoint distributions

Tables are returned as `huxtable` objects ready for Word or HTML output.

## Configuration Structure

A valid configuration must include:

- `analyses`: Analysis specifications (data frame)

- `hypotheses`: Hypothesis definitions (data frame)

- `enroll_rate`: Enrollment rates by strata (data frame)

- `graph`: Graphical testing procedure (list with `g` matrix and `w`
  weights)

- `distribution_tte` and/or `distribution_bin`: Distribution parameters
  (data frame)

## Author

**Maintainer**: Yevgen Tymofyeyev <ytymofye@its.jnj.com>

Authors:

- Yevgen Tymofyeyev <ytymofye@its.jnj.com>

- Michael Grayling <mgraylin@its.jnj.com>

## Examples

``` r
if (FALSE) { # \dontrun{
# List available templates
list_config_repository()
list_rmd_template_repository()

# Load and process a study
config  <- load_config_from_repository("example_study")
results <- process_config(config)

# Explore results
results$tables$table1        # Hypothesis summary
results$tables$table5        # Boundary specifications
results$graph_figure         # Graphical MCP diagram
results$alpha_spend_figure   # Alpha spending functions

# Generate report
generate_report(results)

# Scaffold a new study
create_study(
  config       = "example_study",
  rmd_template = "gsd_detailed",
  output_dir   = "my_study"
)
} # }
```
