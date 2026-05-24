# Generate GSD Report

Generate GSD Report

## Usage

``` r
generate_report(
  gsd_details,
  output_file = NULL,
  template_type = "html",
  template_file = NULL,
  output_dir = NULL
)
```

## Arguments

- gsd_details:

  Results object from process_config function

- output_file:

  Output file path (defaults to config name + extension)

- template_type:

  Type of report template ("html", "pdf", "word")

- template_file:

  Path to Rmd template file (defaults to package template)

- output_dir:

  Output directory (defaults to config file directory)
