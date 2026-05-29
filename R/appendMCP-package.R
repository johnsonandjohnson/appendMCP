#' Generate analysis documentation for graphical MCPs in group sequential trials
#'
#' {appendMCP} generates analysis documentation for graphical multiple comparison
#' procedures (MCPs) in group sequential design (GSD) clinical trials. Given a
#' study configuration, it produces summary tables, diagnostic plots, and a fully
#' formatted R Markdown report suitable for appending to a statistical analysis
#' plan (SAP).
#'
#' @section Main Functions:
#' \describe{
#'   \item{\code{\link{load_config_from_repository}}}{Load built-in configurations}
#'   \item{\code{\link{process_config}}}{Process design configurations and calculate operating characteristics}
#'   \item{\code{\link{generate_report}}}{Generate comprehensive HTML or Word reports}
#'   \item{\code{\link{create_study}}}{Scaffold a new study from built-in templates}
#' }
#'
#' @section Quick Start:
#' \preformatted{
#' library(appendMCP)
#'
#' config  <- load_config_from_repository("example_study")
#' results <- process_config(config)
#' generate_report(results)
#' }
#'
#' @section What the Package Produces:
#' \describe{
#'   \item{Table 1}{Hypothesis summary (endpoint, type, spending function)}
#'   \item{Table 2}{Analysis schedule by hypothesis (timing, information fractions)}
#'   \item{Table 3}{Analysis schedule by analysis (all hypotheses at each look)}
#'   \item{Table 4}{Weight scenarios under the graphical MCP}
#'   \item{Table 5}{Boundary specifications (nominal p-values, information fractions, local power)}
#'   \item{Table 6a / 6b}{Simulation-based operating characteristics by analysis and overall}
#'   \item{Plots}{Graph diagram, information fractions, alpha spending, enrollment, time-to-event and binary endpoint distributions}
#' }
#'
#' Tables are returned as \code{huxtable} objects ready for Word or HTML output.
#'
#' @section Configuration Structure:
#' A valid configuration must include:
#' \itemize{
#'   \item \code{analyses}: Analysis specifications (data frame)
#'   \item \code{hypotheses}: Hypothesis definitions (data frame)
#'   \item \code{enroll_rate}: Enrollment rates by strata (data frame)
#'   \item \code{graph}: Graphical testing procedure (list with \code{g} matrix and \code{w} weights)
#'   \item \code{distribution_tte} and/or \code{distribution_bin}: Distribution parameters (data frame)
#' }
#'
#' @examples
#' \dontrun{
#' # List available templates
#' list_config_repository()
#' list_rmd_template_repository()
#'
#' # Load and process a study
#' config  <- load_config_from_repository("example_study")
#' results <- process_config(config)
#'
#' # Explore results
#' results$tables$table1        # Hypothesis summary
#' results$tables$table5        # Boundary specifications
#' results$graph_figure         # Graphical MCP diagram
#' results$alpha_spend_figure   # Alpha spending functions
#'
#' # Generate report
#' generate_report(results)
#'
#' # Scaffold a new study
#' create_study(
#'   config       = "example_study",
#'   rmd_template = "gsd_detailed",
#'   output_dir   = "my_study"
#' )
#' }
#'
#' @name appendMCP
#' @docType package
"_PACKAGE"

if (getRversion() >= "2.15.1") utils::globalVariables(".")
