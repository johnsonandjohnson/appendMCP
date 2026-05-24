# Tools for defining graphical multiple comparison procedures in group-sequentially designed trials

appendMCP provides routines for describing graphical multiple comparison
procedures (MCPs) in trials with a group-sequential design (GSD). Its
primary objective is to generate comprehensive analysis reports and
documentation that can be appended to statistical analysis plan (SAP)
documents. The package includes predefined configuration templates and
report templates that users can customize for their specific study
designs.

## Main Functions

- [`create_study`](create_study.md):

  Create a complete study configuration from available templates

- [`load_config_from_repository`](load_config_from_repository.md):

  Load built-in configurations

- [`process_config`](process_config.md):

  Process design configurations and calculate operating characteristics

- [`generate_report`](generate_report.md):

  Generate comprehensive reports

## Quick Start

Create a new study using built-in templates:


    create_study(
      config       = "dualEP_study",
      rmd_template = "gsd_detailed",
      output_dir   = "my_study"
    )

Or process configurations directly:


    config  <- load_config_from_repository("dualEP_study")
    results <- process_config(config)
    generate_report(
      gsd_details   = results,
      template_file = load_rmd_template_from_repository("gsd_detailed"),
      template_type = "html"
    )

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

# View a sample study config list from the repository
load_config_from_repository("dualEP_study")

# View the corresponding .R file
file.show(get_config_path("dualEP_study"))

# Create sub-directory containing a report .Rmd file
create_study(
  config       = "dualEP_study", # using config from repository
  rmd_template = "gsd_detailed",
  output_dir   = "my_custom_study"
)
} # }
```
