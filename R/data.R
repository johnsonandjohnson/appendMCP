#' Example Study Configuration List
#'
#' A list containing study design parameters for an example study, including
#' analysis, hypothesis, enrollment rate, and distribution parameter
#' specifications.
#'
#' @format A list with the following components:
#' \describe{
#'   \item{study_name}{Character string with study name}
#'   \item{study_description}{Character string describing the study}
#'   \item{alpha}{Numeric value for overall type I familywise error-rate}
#'   \item{analyses}{Tibble with analysis triggers, including endpoint, strata, treatment, sample size, and event information}
#'   \item{hypotheses}{Tibble with hypothesis specifications, including type, endpoint, and spending functions}
#'   \item{enroll_rate}{Tibble with enrollment rates by stratum}
#'   \item{distribution_tte}{Tibble with time-to-event endpoint distribution parameters by stratum and arm}
#'   \item{distribution_bin}{Tibble with binary endpoint distribution parameters by stratum and arm}
#'   \item{graph}{List containing graphical testing procedure matrix and weights}
#' }
#' @source Internal template configuration
#' @examples
#' data(example_study_config)
#' example_study_config$study_name
#' example_study_config$analyses
"example_study_config"
