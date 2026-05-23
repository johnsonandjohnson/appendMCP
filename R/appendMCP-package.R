#' Tools for defining graphical multiple comparison procedures in group-sequentially designed trials
#'
#' {appendMCP} provides routines for describing graphical multiple comparison
#' procedures (MCPs) in trials with a group-sequential design (GSD). Its primary
#' objective is to generate comprehensive analysis reports and documentation
#' that can be appended to statistical analysis plan (SAP) documents. The
#' package includes predefined configuration templates and report templates
#' that users can customize for their specific study designs.
#'
#' @section Main Functions:
#' \describe{
#'   \item{\code{\link{create_study}}}{Create a complete study configuration from available templates}
#'   \item{\code{\link{load_config_from_repository}}}{Load built-in configurations}
#'   \item{\code{\link{process_config}}}{Process design configurations and calculate operating characteristics}
#'   \item{\code{\link{generate_report}}}{Generate comprehensive reports}
#' }
#'
#' @section Quick Start:
#' Create a new study using built-in templates:
#' \preformatted{
#' create_study(
#'   config       = "dualEP_study",
#'   rmd_template = "gsd_detailed",
#'   output_dir   = "my_study"
#' )
#' }
#'
#' Or process configurations directly:
#' \preformatted{
#' config  <- load_config_from_repository("dualEP_study")
#' results <- process_config(config)
#' generate_report(
#'   gsd_details   = results,
#'   template_file = load_rmd_template_from_repository("gsd_detailed"),
#'   template_type = "html"
#' )
#' }
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
#' # View a sample study config list from the repository
#' load_config_from_repository("dualEP_study")
#'
#' # View the corresponding .R file
#' file.show(get_config_path("dualEP_study"))
#'
#' # Create sub-directory containing a report .Rmd file
#' create_study(
#'   config       = "dualEP_study", # using config from repository
#'   rmd_template = "gsd_detailed",
#'   output_dir   = "my_custom_study"
#' )
#' }
#'
#' @name appendMCP
#' @docType package
"_PACKAGE"

if (getRversion() >= "2.15.1") utils::globalVariables(".")
