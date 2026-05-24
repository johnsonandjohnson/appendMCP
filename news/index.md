# Changelog

## appendMCP 0.3.0

### New Features

- Added lintr static code analysis setup and report (`lintr-reports/`)

### Bug Fixes

- Fixed alpha bug that didn’t propagate from config before
- Fixed alpha bug with reporting local power
- Fixed zero-power for propagated-weight hypotheses in
  `update_p_thresholds_cpp`
- Fixed bug in `enroll_rate` processing for complex piecewise constant
  enrollment rates
- Fixed differential dropout: updated `get_dist_tite` and
  `plot_distribution_tte_ahr` to use `ahr_dd`
- Fixed `process_analyses_2` to handle cases where `hypothesis_analysed`
  is a subset (e.g., `c(2,3)`)
- Fixed vignettes and templates after `timeline_figure` refactor
- Fixed [`process_config()`](../reference/process_config.md) to use
  [`system.file()`](https://rdrr.io/r/base/system.file.html) for
  template paths (QC-012)
- Fixed `process_distribution` to validate required columns (QC-013)
- Fixed `check_analyses_structure` to allow
  `power_subsets_any`/`power_subsets_all` columns (QC-001)
- Added `test_method` to hypotheses allowed columns; added diagonal == 0
  check; relaxed graph row sum to \<= 1 (QC-003/005/006/007/015)
- Documented all 22 return fields in `process_config` `@return` (QC-009)
- Handle `NA`/`NULL` robustly for `nominal` and `sfpar` in boundary
  computation

### Improvements

- Switched to `huxtable` for all table outputs
- Refactored `create_summary_tables`: fixed hypothesis sorting and
  endpoint lookup
- Resolved all `no visible binding` R CMD check notes
- Resolved `seq_linter` warnings; moved `archived.R` out of package `R/`
  folder
- Fixed trailing whitespace and style issues across codebase
- Rounded inline numeric values in Rmd templates; increased timeline
  plot height
- Removed deprecated `get_boundaries_old` and stale vignette HTML
  outputs
- Added `number_sims` to config
- Exported
  [`create_summary_tables()`](../reference/create_summary_tables.md)
- Added support for studies with no binary endpoints; added custom graph
  plotting

## appendMCP 0.2.0

- Initial development version
