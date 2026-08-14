# appendMCP

**appendMCP** generates analysis documentation for clinical trials
conducted using graphical multiple comparison procedures (MCPs) within a
group sequential design (GSD) setting. Given a study configuration, it
produces summary tables, diagnostic plots, and a fully formatted R
Markdown report suitable for appending to a statistical analysis plan
(SAP).

## Installation

``` r

# install.packages("remotes")
remotes::install_github("johnsonandjohnson/appendMCP")
```

## Quick Start

The core workflow is three steps: load a configuration, process it, and
generate a report.

``` r

library(appendMCP)

config  <- load_config_from_repository("example_study")
results <- process_config(config)
generate_report(results)
```

This produces an HTML report in your working directory containing
summary tables, the graphical testing procedure diagram, information
fraction plots, alpha spending visualizations, and operating
characteristics.

## What the Package Produces

- **Table 1:** Hypothesis summary (endpoint, type, spending function)
- **Table 2:** Analysis schedule by hypothesis (timing, information
  fractions)
- **Table 3:** Analysis schedule by analysis (all hypotheses at each
  look)
- **Table 4:** Weight scenarios under the graphical MCP
- **Table 5:** Boundary specifications (nominal p-values, information
  fractions, local power)
- **Table 6a / 6b:** Simulation-based operating characteristics by
  analysis and overall
- **Plots:** Graph diagram, information fractions, alpha spending,
  enrollment, time-to-event and binary endpoint distributions

Tables are returned as `huxtable` objects ready for Word or HTML output.

## Exploring Results

``` r

# Individual tables
results$tables$table1   # Hypothesis summary
results$tables$table2   # Schedule by hypothesis
results$tables$table5   # Boundary specifications (nominal p-values, local power)

# Plots (top-level fields on the results object)
results$graph_figure          # Graphical MCP diagram
results$information_figure    # Information fraction over time
results$alpha_spend_figure    # Alpha spending functions
results$tte_figure            # Time-to-event distributions
results$er_figure             # Enrollment rate
```

## Scaffolding a New Study

[`create_study()`](reference/create_study.md) copies a configuration and
report template into a project folder and generates a ready-to-run
analysis script:

``` r

create_study(
  config       = "example_study",   # built-in config, or path to your own .R file
  rmd_template = "gsd_default",     # built-in template, or path to your own .Rmd
  output_dir   = "my_study"
)
# Creates:
#   my_study/study_config.R    — edit this to define your study
#   my_study/render_config.R   — run this to execute the analysis
#   my_study/report.Rmd        — the report template
```

## Available Built-in Configurations and Templates

``` r

list_config_repository()        # built-in study configurations
list_rmd_template_repository()  # built-in report templates
```

## Using a Custom Configuration

A configuration is an R list assigned to a single variable in a `.R`
file. The required fields are:

| Field | Description |
|----|----|
| `study_name` | Study identifier string |
| `alpha` | One-sided significance level (e.g. `0.025`) |
| `analyses` | Data frame of analysis specifications |
| `hypotheses` | Data frame of hypothesis definitions |
| `enroll_rate` | Data frame of enrollment rates by stratum |
| `graph` | List with `g` (transition matrix) and `w` (initial weights) |
| `distribution_tte` | Time-to-event distributions (required if any TTE endpoint) |
| `distribution_bin` | Binary endpoint distributions (required if any binary endpoint) |

See the built-in example for a complete, annotated configuration:

``` r

config <- load_config_from_repository("example_study")
str(config, max.level = 1)
```

Or read the configuration guide vignette:

``` r

vignette("configuration-guide", package = "appendMCP")
```

## Getting Help

- Function reference: [`?process_config`](reference/process_config.md),
  [`?create_study`](reference/create_study.md),
  [`?generate_report`](reference/generate_report.md)
- Vignettes: `browseVignettes("appendMCP")`
- Full documentation site:
  <https://johnsonandjohnson.github.io/appendMCP>
- Report a bug: <https://github.com/johnsonandjohnson/appendMCP/issues>
