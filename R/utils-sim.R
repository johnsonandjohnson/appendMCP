# Helper functions, for performing simulations

# Declare global variables to avoid R CMD check NOTEs
utils::globalVariables(c(".", ".I", "orig_order", "endpoint", "Si", "Ti",
                         "stratum", "treatment", "fail_rate", "duration",
                         "dropout_rate"))

#' @importFrom utils tail
#' @importFrom stats time
#' @importFrom graphics text
#' @importFrom data.table as.data.table setkey ":="
#' @useDynLib appendMCP, .registration=TRUE
#' @importFrom Rcpp sourceCpp
NULL

#' Simulation with data.table optimization
#' @param enroll_data Data frame with enrollment data containing columns Si, Ri, Ti
#' @param distribution_tte Distribution parameters for time-to-event endpoints
#' @param distribution_bin Distribution parameters for binary endpoints
#' @param correlation_matrix Correlation matrix for endpoints
#' @export
sim_outcomes <- function(enroll_data, distribution_tte, distribution_bin, correlation_matrix) {
  if (!is.data.frame(enroll_data)) stop("enroll_data must be a data frame")
  required_cols        <- c("Si", "Ri", "Ti")
  if (!all(required_cols %in% names(enroll_data))) {
    stop(paste("enroll_data must contain columns:",
               paste(required_cols, collapse = ", ")))
  }
  n                    <- nrow(enroll_data)
  if (n == 0) stop("enroll_data cannot be empty")
  # Convert to data.table but preserve original order
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("data.table package required for optimization")
  }
  dt_enroll            <- data.table::as.data.table(enroll_data)
  dt_enroll[, orig_order := .I] # Add original row index
  data.table::setkey(dt_enroll, Si, Ti)
  endpoints_tte        <- if (!missing(distribution_tte)) unique(distribution_tte$endpoint) else character(0)
  endpoints_bin        <- if (!missing(distribution_bin)) unique(distribution_bin$endpoint) else character(0)
  all_endpoints        <- c(endpoints_tte, endpoints_bin)
  n_endpoints          <- length(all_endpoints)
  if (n_endpoints == 0) stop("No endpoints specified")
  # Default correlation matrix
  if (missing(correlation_matrix)) {
    correlation_matrix <- diag(n_endpoints)
  }
  # Generate correlated uniform variables
  if (n_endpoints > 1) {
    Z                  <-
      matrix(stats::rnorm(n_endpoints*n), n, n_endpoints)%*%
      chol(correlation_matrix)
    U                  <- stats::pnorm(Z)
  } else {
    U                  <- matrix(stats::runif(n), n, 1)
  }
  result_data          <- enroll_data
  # Process time-to-event endpoints with data.table
  if (!missing(distribution_tte)) {
    dt_tte             <- data.table::as.data.table(distribution_tte)
    for (i in seq_along(endpoints_tte)) {
      endpoint_name    <- endpoints_tte[i]
      # Group by stratum/treatment to create piecewise parameters
      dt_endpoint      <- dt_tte[endpoint == endpoint_name]
      dt_grouped       <- dt_endpoint[, .(fail_rate    = list(fail_rate),
                                          duration     = list(duration),
                                          dropout_rate = dropout_rate[1]),
                                      by = .(stratum, treatment)]
      data.table::setkey(dt_grouped, stratum, treatment)
      # Merge with enrollment data
      dt_merged        <- dt_grouped[dt_enroll, on = c("stratum"   = "Si",
                                                       "treatment" = "Ti")]
      u_col            <- which(all_endpoints == endpoint_name)
      # Vectorized calculations - but U needs to match original order
      U_ordered        <- U[dt_merged$orig_order, u_col]
      Ei               <- mapply(function(p, lambda, dur) {
        if (length(lambda) == 1) {
          stats::qexp(p, rate = lambda)
        } else {
          times        <- c(0, cumsum(dur[!is.infinite(dur)]))
          rpact::getPiecewiseExponentialQuantile(p,
                                                 piecewiseLambda       = lambda,
                                                 piecewiseSurvivalTime = times)
        }
      }, U_ordered, dt_merged$fail_rate, dt_merged$duration)
      Ci               <- stats::qexp(stats::runif(nrow(dt_merged)),
                                      rate = dt_merged$dropout_rate)
      Yi               <- pmin(Ei, Ci)
      Di               <- as.numeric(Ei <= Ci)
      Ai               <- Yi + dt_merged$Ri
      # Create result vectors in original order
      result_Ei        <- result_Ci <- result_Yi <- result_Di <- result_Ai <-
        numeric(n)
      result_Ei[dt_merged$orig_order] <- Ei
      result_Ci[dt_merged$orig_order] <- Ci
      result_Yi[dt_merged$orig_order] <- Yi
      result_Di[dt_merged$orig_order] <- Di
      result_Ai[dt_merged$orig_order] <- Ai
      # Add columns efficiently
      result_data[[paste0(endpoint_name, ": Ei")]] <- result_Ei
      result_data[[paste0(endpoint_name, ": Ci")]] <- result_Ci
      result_data[[paste0(endpoint_name, ": Yi")]] <- result_Yi
      result_data[[paste0(endpoint_name, ": Di")]] <- result_Di
      result_data[[paste0(endpoint_name, ": Ai")]] <- result_Ai
    }
  }
  # Process binary endpoints with data.table
  if (!missing(distribution_bin)) {
    dt_bin             <- data.table::as.data.table(distribution_bin)
    data.table::setkey(dt_bin, stratum, treatment)
    for (i in seq_along(endpoints_bin)) {
      endpoint_name    <- endpoints_bin[i]
      dt_endpoint      <- dt_bin[endpoint == endpoint_name]
      dt_merged        <- dt_endpoint[dt_enroll, on = c("stratum"   = "Si",
                                                        "treatment" = "Ti")]
      u_col            <- which(all_endpoints == endpoint_name)
      # Vectorized calculations - but U needs to match original order
      U_ordered        <- U[dt_merged$orig_order, u_col]
      Yi               <- as.numeric(U_ordered < dt_merged$rate)
      Ai               <- dt_merged$Ri + dt_merged$maturity_time
      # Create result vectors in original order
      result_Yi        <- numeric(n)
      result_Ai        <- numeric(n)
      result_Yi[dt_merged$orig_order] <- Yi
      result_Ai[dt_merged$orig_order] <- Ai
      result_data[[paste0(endpoint_name, ": Yi")]] <- result_Yi
      result_data[[paste0(endpoint_name, ": Ai")]] <- result_Ai
    }
  }
  result_data
}

#' Dataset simulation
#' @param enroll_rate Data frame with enrollment rates
#' @param distribution_tte Distribution parameters for time-to-event endpoints
#' @param distribution_bin Distribution parameters for binary endpoints
#' @param n Total sample size
#' @param n_min_per_stratum Minimum sample size per stratum
#' @param n_max_per_stratum Maximum sample size per stratum
#' @param correlation_matrix Correlation matrix for endpoints
#' @param seed Random seed for reproducibility
#' @export
sim_dataset <- function(
  enroll_rate,
  distribution_tte,
  distribution_bin,
  n,
  n_min_per_stratum,
  n_max_per_stratum,
  correlation_matrix,
  seed = Sys.time()
) {
  if (!is.data.frame(enroll_rate)) stop("enroll_rate must be a data frame")
  if (!is.numeric(n) || length(n) != 1 || n <= 0) stop("n must be a positive integer")
  if (missing(n_min_per_stratum)) n_min_per_stratum <- NULL
  if (missing(n_max_per_stratum)) n_max_per_stratum <- NULL
  set.seed(seed)
  sim_pwc_stratified_recruitment_cpp(enroll_rate, n, n_min_per_stratum,
                                     n_max_per_stratum) |>
    sim_pb_randomization_cpp(enroll_rate) |>
    sim_outcomes(distribution_tte, distribution_bin, correlation_matrix) |>
    tibble::as_tibble()
}

#' Apply hypothesis tests to analyses
#' @param analyses Data frame containing analysis results
#' @param hypotheses Data frame containing hypothesis definitions
#' @export
apply_hypothesis_tests <- function(
  analyses,
  hypotheses
) {
  if (!is.data.frame(analyses)) stop("analyses must be a data frame")
  if (!is.data.frame(hypotheses)) stop("hypotheses must be a data frame")
  test_functions                    <- list(
    "logrank"              = test_logrank_cpp,
    "stratified_logrank"   = test_stratified_logrank_cpp,
    "pooled_proportions"   = test_pooled_proportions_cpp,
    "unpooled_proportions" = test_unpooled_proportions_cpp,
    "cmh"                  = test_cmh_cpp
  )
  for (h in seq_len(nrow(hypotheses))) {
    hyp                             <- hypotheses[h, ]
    col_name                        <- paste0("hypothesis_", h)
    analyses[[col_name]]            <- vector("list", nrow(analyses))
    for (a in seq_len(nrow(analyses))) {
      if (a %in% hyp$analyses_analysed[[1]]) {
        method <- hyp$test_method
        tryCatch({
          test_result <- if (is_wlr_method(method)) {
            # WLR family: use the R-level weighted log-rank statistic
            spec   <- parse_test_method(method)
            weight <- test_method_to_wlr_weight(spec)
            test_wlr(df       = analyses$df[[a]],
                     endpoint = hyp$endpoint,
                     strata   = hyp$strata[[1]],
                     control  = hyp$control,
                     test     = hyp$test,
                     weight   = weight)
          } else {
            test_func <- test_functions[[method]]
            if (is.null(test_func)) {
              stop(paste("Unknown test method:", method))
            }
            test_func(df       = analyses$df[[a]],
                      endpoint = hyp$endpoint,
                      strata   = hyp$strata[[1]],
                      control  = hyp$control,
                      test     = hyp$test)
          }
          analyses[[col_name]][[a]] <- test_result
        }, error = function(e) {
          warning(paste("Error in hypothesis test", h, "analysis", a, ":",
                        e$message))
          analyses[[col_name]][[a]] <- NA
        })
      } else {
        analyses[[col_name]][[a]]   <- NA
      }
    }
  }
  analyses
}

#' Wrapper function to fix C++ list-column issue
#' @param df Data frame with simulation data
#' @param analyses Data frame containing analysis definitions
#' @param hypotheses Data frame containing hypothesis definitions
#' @export
calculate_analysis_timing_cpp_wrapper <- function(
  df,
  analyses,
  hypotheses
) {
  if (!is.data.frame(df)) stop("df must be a data frame")
  if (!is.data.frame(analyses)) stop("analyses must be a data frame")
  if (!is.data.frame(hypotheses)) stop("hypotheses must be a data frame")
  analyses    <- calculate_analysis_timing_cpp(df, analyses, hypotheses) |>
    tibble::as_tibble()
  analyses$df <- lapply(analyses$df, function(df) tibble::as_tibble(df))
  analyses
}

#' Extract information levels from analyses results
#' @param analyses_result Results from hypothesis testing
#' @param hypotheses Data frame containing hypothesis definitions
#' @export
extract_information_levels <- function(
  analyses_result,
  hypotheses
) {
  n_hyp                <- nrow(hypotheses)
  info_list            <- vector("list", n_hyp)
  for (h in seq_len(n_hyp)) {
    analyses_tested    <- hypotheses$analyses_analysed[[h]]
    hyp_col            <- paste0("hypothesis_", h)
    info_vals          <- numeric(length(analyses_tested))
    dist_type          <- hypotheses$dist_type[h]
    for (i in seq_along(analyses_tested)) {
      a                <- analyses_tested[i]
      test_result      <- analyses_result[[hyp_col]][[a]]
      if (is.numeric(test_result)) {
        if (dist_type == "bin") {
          info_vals[i] <- test_result[["sample_size"]]
        } else {
          info_vals[i] <- test_result[["events_control"]] + test_result[["events_test"]]
        }
      } else {
        info_vals[i]   <- NA_real_
      }
    }
    info_list[[h]]     <- info_vals[!is.na(info_vals)]
  }
  tibble::tibble(hypothesis         = seq_len(n_hyp),
                 information_levels = info_list)
}

#' Process rejection rules
#' @param hypotheses Data frame containing hypothesis definitions
#' @param alpha Overall Type I error rate
#' @export
process_rejection_rules <- function(
    hypotheses,
    alpha = 0.025
) {
  hypotheses |>
    dplyr::mutate(
      sf_mod       = purrr::map2_chr(
        .data$sf, .data$nominal, \(sf, nominal) if (!is.null(nominal) && !all(is.na(nominal)) && sf != "none") "asUser" else sf
      ),
      sfpar_mod    = purrr::pmap(
        list(.data$sf, .data$sfpar, .data$nominal, .data$information_fractions, .data$possible_weight),
        function(sf, sfpar, nominal, information_fractions, possible_weight) {
          if (is.null(sfpar) || all(is.na(sfpar))) sfpar <- NULL
          if (sf == "none") nominal <- NULL
          if (!is.null(nominal) && !all(is.na(nominal))) {
            sfpar <- dplyr::case_match(
              sf,
              "asHSD"  ~ list(gsDesign::sfHSD),
              "asKD"   ~ list(gsDesign::sfPower),
              "asOF"   ~ list(gsDesign::sfLDOF),
              "asP"    ~ list(gsDesign::sfLDPocock),
              "asUser" ~ list(gsDesign::sfPoints))[[1]](possible_weight*alpha,
                                                        information_fractions,
                                                        sfpar)$spend
            sfpar[seq_along(nominal)] <- cumsum(nominal)
            sfpar                    <- sfpar/(possible_weight*alpha)
            sfpar[length(sfpar)]     <- 1
          }
          sfpar
        }
      ),
      p_thresholds = purrr::pmap(
        list(.data$sf_mod, .data$sfpar_mod, .data$information_factor, .data$possible_weight, .data$information),
        \(sf, sfpar, information_factor, possible_weight, information) get_p_thresholds(sf, sfpar, information_factor, possible_weight*alpha, information)
      )
    )
}

#' Calculate z bounds
#' @param info_levels Information levels for analyses
#' @param alpha Type I error rate
#' @param sfu Spending function
#' @param sfupar Spending function parameters
#' @param planned_max_info Planned maximum information
#' @export
calculate_z_bounds         <- function(
    info_levels      = c(100, 200, 300, 400, 500)/4,
    alpha            = 0.025,
    sfu              = gsDesign::sfLDOF,
    sfupar           = NULL,
    planned_max_info = 500/4
) {
  last_info <- info_levels[length(info_levels)]
  k         <- length(info_levels)
  if (planned_max_info == last_info) {
    timing  <- info_levels/planned_max_info
    spend   <- sfu(alpha, timing, sfupar)$spend
  } else {
    timing  <- info_levels/last_info
    spend   <- c(sfu(alpha, info_levels[-k]/planned_max_info, sfupar)$spend,
                 alpha)
  }
  l         <- rep(-20, k)
  .C("gsbound1", PACKAGE = "gsDesign",
     k, 0, timing, l, l, l, spend - c(0, spend[-k]), 1e-06, 18L, 0L, 0L)[[5]]
}

#' Get p thresholds
#' @param sf Spending function name
#' @param sfpar Spending function parameters
#' @param info Information levels
#' @param alpha Type I error rate
#' @param obs_info Observed information levels
#' @export
get_p_thresholds <- function(sf, sfpar, info, alpha, obs_info) {
  if (length(info) == 1) {
    alpha
  } else {
    if (missing(obs_info)) {
      calculate_z_bounds(
        info_levels      = info,
        alpha            = alpha,
        sfu              =
          dplyr::case_match(sf,
                            "asHSD"  ~ list(gsDesign::sfHSD),
                            "asKD"   ~ list(gsDesign::sfPower),
                            "asOF"   ~ list(gsDesign::sfLDOF),
                            "asP"    ~ list(gsDesign::sfLDPocock),
                            "asUser" ~ list(gsDesign::sfPoints))[[1]],
        sfupar           = sfpar,
        planned_max_info = tail(info, 1)
      ) |>
        stats::pnorm(lower.tail = FALSE)
    } else {
      info_tar <- obs_info/tail(info, 1)
      sf_fn    <- dplyr::case_match(
        sf,
        "asHSD"  ~ list(gsDesign::sfHSD),
        "asKD"   ~ list(gsDesign::sfPower),
        "asOF"   ~ list(gsDesign::sfLDOF),
        "asP"    ~ list(gsDesign::sfLDPocock),
        "asUser" ~ list(gsDesign::sfPoints)
      )[[1]]
      spend    <- sf_fn(alpha, c(info_tar[-length(info_tar)], 1), sfpar)$spend/alpha
      spend[length(spend)] <- 1
      calculate_z_bounds(info_levels      = obs_info,
                         alpha            = alpha,
                         sfu              = gsDesign::sfPoints,
                         sfupar           = spend,
                         planned_max_info = tail(obs_info, 1)) |>
        stats::pnorm(lower.tail = FALSE)
    }
  }
}

#' Update graph
#' @param graph Graph object with edges and weights
#' @param rejected Index of rejected hypothesis
#' @export
update_graph       <- function(
    graph,
    rejected # Node to reject
) {
  update_graph_cpp(graph$g, graph$w, rejected)
}

#' Update p thresholds
#' @param analyses Data frame containing analysis definitions
#' @param hypotheses Data frame containing hypothesis definitions
#' @param graph Graph object with edges and weights
#' @export
update_p_thresholds <- function(
    analyses,
    hypotheses,
    graph
) {
  update_p_thresholds_cpp(analyses, hypotheses, graph$g, graph$w)
}

#' Implement M/B - version for IPD simulations
#' @param analyses Data frame containing analysis results
#' @param hypotheses Data frame containing hypothesis definitions
#' @param graph Graph object with edges and weights
#' @export
get_maurer_bretz <- function(
    analyses,
    hypotheses,
    graph
) {
  hyp_cols                               <-
    grep("^hypothesis_", names(analyses), value = TRUE)
  for (col in hyp_cols) {
    analyses[[paste0("p_", col)]]        <-
      purrr::map_dbl(analyses[[col]], \(x) x["z_statistic"]) |>
      stats::pnorm(lower.tail = FALSE)
  }
  p_obs                                  <- analyses |>
    dplyr::select(dplyr::starts_with("p_")) |>
    t()
  J                                      <- nrow(p_obs)
  for (j in 1:J) {
    if (any(is.na(p_obs[j, ]))) {
      p_obs[j, which(is.na(p_obs[j, ]))] <-
        tail(p_obs[j, !is.na(p_obs[j, ])], 1)
    }
  }
  K                                      <- ncol(p_obs)
  p_thr                                  <- update_p_thresholds(analyses,
                                                                hypotheses,
                                                                graph)
  reject                                 <- numeric(J)
  reject_analysis                        <- rep(NA, J)
  reject_time                            <- rep(NA, J)
  set_J                                  <- seq_len(J)
  for (k in seq_len(K)) {
    no_rejections                        <- FALSE
    while (all(!no_rejections, length(set_J) > 0)) {
      no_rejections                      <- TRUE
      if (length(set_J) > 0) {
        revised_J                        <- set_J
        for (j in set_J) {
          if (p_obs[j, k] < p_thr[j, k]) {
            reject[j]                    <- 1
            reject_analysis[j]           <- k
            reject_time[j]               <- analyses$analysis_time[k]
            graph                        <- update_graph(graph, j)
            p_thr                        <-
              update_p_thresholds(analyses, hypotheses, graph)
            revised_J                    <- revised_J[-which(revised_J == j)]
            no_rejections                <- FALSE
          }
        }
        set_J                            <- revised_J
      }
    }
  }
  list(reject          = reject,
       reject_analysis = reject_analysis,
       reject_time     = reject_time)
}

#' Simplified Maurer-Bretz procedure with matrix-based rejection tracking
#'
#' This function implements the Maurer-Bretz graphical multiple comparison
#' procedure and tracks rejections in matrix form similar to p_obs structure.
#' It preserves the same logic as get_maurer_bretz_z().
#'
#' @param pvec Numeric vector of p-values for all hypothesis-analysis combinations
#' @param analyses Data frame containing analysis definitions with timing information
#' @param hypotheses Data frame containing hypothesis definitions including
#'   index and analyses_analysed columns
#' @param graph List containing the graphical structure with elements:
#'   \itemize{
#'     \item g: Transition matrix between hypotheses
#'     \item w: Initial weights for each hypothesis
#'   }
#'
#' @return Matrix of rejection indicators (0/1) with dimensions J x K,
#'   where J is number of hypotheses and K is number of analyses.
#'   Element [j,k] = 1 if hypothesis j was rejected at or before analysis k.
#'
#' @details
#' The function follows the same sequential testing procedure as get_maurer_bretz_z()
#' but tracks rejections in a matrix format where each row represents a hypothesis
#' and each column represents an analysis. Once a hypothesis is rejected, all
#' subsequent analyses for that hypothesis are marked as rejected (1).
#'
#' @export
get_maurer_bretz_z_raw <- function(
  pvec,
  analyses,
  hypotheses,
  graph
) {
  get_maurer_bretz_z_raw_cpp(pvec, analyses, hypotheses, graph$g, graph$w)
}

covariance          <- function(I) {
  Cov               <- matrix(1, length(I), length(I))
  if (length(I) > 1) {
    for (j1 in 1:(length(I) - 1)) {
      for (j2 in (j1 + 1):length(I)) {
        Cov[j1, j2] <- Cov[j2, j1] <- sqrt(I[j1]/I[j2])
      }
    }
  }
  Cov
}

get_dist_bin <- function(control, test, enroll_rate, maturity_time,
                         times_analysed, control_pooled_rate, test_pooled_rate,
                         method) {
  n1    <- purrr::map_dbl(
    times_analysed,
    \(t) expected_n_at_t(t, maturity_time,
                         dplyr::filter(enroll_rate, .data$treatments %in% test) |>
                           dplyr::mutate(rate = .data$arm_rate,
                                         stratum = .data$stratum_treatment))
  )
  n2    <- purrr::map_dbl(
    times_analysed,
    \(t) expected_n_at_t(t, maturity_time,
                         dplyr::filter(enroll_rate, .data$treatments %in% control) |>
                           dplyr::mutate(rate = .data$arm_rate,
                                         stratum = .data$stratum_treatment))
  )
  if (method == "unpooled_proportions") {
    I   <- 1/(control_pooled_rate*(1 - control_pooled_rate)/n1 +
                test_pooled_rate*(1 - test_pooled_rate)/n2)
  } else if (method == "pooled_proportions") {
    piP <- 0.5*(control_pooled_rate + test_pooled_rate)
    I   <- 1/(piP*(1 - piP)*(1/n1 + 1/n2))
  }
  list(EZ   = (test_pooled_rate - control_pooled_rate)*sqrt(I),
       CovZ = covariance((n1 + n2)/tail(n1 + n2, 1)))
}

get_dist_tite <- function(control, test, enroll_rate, fail_rate,
                          times_analysed) {
  fail_rate_wide   = tidyr::pivot_wider(fail_rate,
                                        names_from  = "treatment",
                                        values_from = c("fail_rate",
                                                        "dropout_rate"),
                                        id_cols     = c("stratum", "duration"),
                                        values_fn = list)  |>
    tidyr::unnest_longer(-("stratum":"duration")) %>%
    {tibble::tibble(duration       = .$duration,
                    fail_rate      = .[[paste0("fail_rate_", control)]],
                    dropout_rate_c = .[[paste0("dropout_rate_", control)]],
                    dropout_rate_e = .[[paste0("dropout_rate_", test)]],
                    hr             = .[[paste0("fail_rate_", test)]]/
                      .[[paste0("fail_rate_", control)]],
                    stratum        = .$stratum)}
  ahr_obj <- ahr_dd(
    enroll_rate |>
      dplyr::group_by(.data$stratum, .data$rate, .data$duration, .data$index) |>
      dplyr::summarise(rate = sum(.data$arm_rate), .groups = "drop") |>
      dplyr::arrange(.data$index),
    fail_rate_wide,
    times_analysed,
    dplyr::filter(enroll_rate, .data$treatments == test)$ratio[1]/
      dplyr::filter(enroll_rate, .data$treatments == control)$ratio[1]
  )
  list(EZ   = -log(ahr_obj$ahr)*sqrt(ahr_obj$info),
       CovZ = covariance(ahr_obj$info))
}

get_dist <- function(hypotheses) {
  hypotheses |>
    dplyr::mutate(
      dist = purrr::pmap(
        list(.data$dist_type, .data$control, .data$test, .data$enroll_rate, .data$distribution, .data$maturity_time, .data$times_analysed, .data$control_pooled_rate, .data$test_pooled_rate, .data$test_method),
        function(type, con, trt, en, di, mat, t, piC, piT, method) {
          if (type == "bin") {
            get_dist_bin(con, trt, en, mat, t, piC, piT, method)
          } else if (is_wlr_method(method)) {
            spec   <- parse_test_method(method)
            weight <- test_method_to_wlr_weight(spec)
            get_dist_tite_wlr(con, trt, en, di, t, weight)
          } else {
            get_dist_tite(con, trt, en, di, t)
          }
        }
      )
    )
}

get_mvn <- function(hypotheses) {
  num_test_stats           <- length(unlist(hypotheses$analyses_analysed))
  EZ                       <- numeric(num_test_stats)
  CovZ                     <- matrix(0, num_test_stats, num_test_stats)
  count                    <- 1
  for (i in seq_len(nrow(hypotheses))) {
    range_i                <-
      (count):(count - 1 + length(hypotheses$analyses_analysed[[i]]))
    EZ[range_i]            <- hypotheses$dist[[i]]$EZ
    CovZ[range_i, range_i] <- hypotheses$dist[[i]]$CovZ
    count                  <- count + length(hypotheses$analyses_analysed[[i]])
  }
  list(EZ   = EZ,
       CovZ = CovZ)
}

#' Execute simulations for marginal operating characteristics
#'
#' Calculates marginal operating characteristics using Monte Carlo simulation with
#' Maurer-Bretz graphical procedure. Generates 3D rejection array and computes
#' comprehensive power metrics including individual hypothesis power, subset power,
#' and expected analysis timing.
#'
#' @param analyses Data frame with analysis definitions and timing
#' @param hypotheses Data frame with hypothesis definitions, distributions, and spending functions
#' @param graph List with graphical structure (g = transition matrix, w = weights)
#' @param method "z" for Z-statistic simulation (implemented), "ipd" for individual patient data (not implemented)
#' @param sims Number of Monte Carlo simulations (default: 1000)
#'
#' @return List with marginal_oc containing:
#'   \itemize{
#'     \item oc_at_analyses: Power metrics by analysis (individual, any, all)
#'     \item oc_across_analyses: Expected analysis index and expected time for first rejection
#'   }
#'
#' @details
#' Workflow:
#' 1. Collapse hypotheses by endpoint, extract distribution parameters
#' 2. Generate MVN distribution for correlated test statistics
#' 3. Process rejection rules and alpha spending thresholds
#' 4. Simulate p-values from MVN, apply Maurer-Bretz to each simulation
#' 5. Build 3D rejection array [J hypotheses × K analyses × S simulations]
#' 6. Compute power metrics via get_sim_oc()
#'
#' @param analyses Processed analyses data frame
#' @param hypotheses Processed hypotheses data frame
#' @param graph Graph object with transition matrix and weights
#' @param method Method for test statistics (default "z")
#' @param sims Number of simulations
#' @param alpha Overall Type I error rate
#' @export
exec_sims <- function(analyses, hypotheses, graph, method = "z",
                      sims = 1000, alpha = 0.025) {
  if (method == "z") {
    hypotheses |>
      dplyr::group_by(.data$index) |>
      dplyr::slice_head(n = 1) |>
      dplyr::ungroup() |>
      get_dist() |>
      get_mvn() ->
      mvn

    # Expand weight scenarios and compute rejection thresholds
    hypotheses |>
      dplyr::mutate(information = .data$information_factor) |>
      process_rejection_rules(alpha = alpha) ->
      hypotheses

    # Simulate p-values: Z ~ MVN(EZ, CovZ), convert to p = 1 - Φ(Z)
    simulated_pvalues <- 1 - stats::pnorm(mvtnorm::rmvnorm(sims, mvn$EZ, mvn$CovZ))

    # Apply Maurer-Bretz to each simulation, returns list of J×K rejection matrices
    rejection_matrices <- apply(simulated_pvalues, 1, function(p) {
      get_maurer_bretz_z_raw(p, analyses, hypotheses, graph)
    }, simplify = FALSE)

    # Stack into 3D array: [J hypotheses, K analyses, S simulations]
    # Element [j,k,s] = 1 if hypothesis j rejected at/before analysis k in simulation s
    rejection_array <- array(
      unlist(rejection_matrices),
      dim = c(nrow(rejection_matrices[[1]]), ncol(rejection_matrices[[1]]), sims)
    )

    # --- Basic checks & dims ---
    # J <- dim(rejection_array)[1]  # hypotheses (1..J)
    # K <- dim(rejection_array)[2]  # analyses   (1..K)
    # S <- dim(rejection_array)[3]  # simulations(1..S)
    # if (!all(rejection_array %in% c(0, 1))) warning("rejection_array has values other than 0/1.")
    # if (K > 1) {
    #   cum_ok <- all(rejection_array[, -1, , drop = FALSE] >= rejection_array[, -K, , drop = FALSE])
    #   if (!cum_ok) warning("Array may not be cumulative across analyses; interpreting as-is.")
    # }

    # --- Core helpers ---

    # Individual hypothesis power by analysis (mean across simulations) -> J x K matrix
    individual_power_matrix <- function(S) {
      apply(S, c(1, 2), mean)  # average over third dim (simulations)
    }

    # Power for a subset at a given analysis k:
    # type = "any" -> P(at least one rejected by analysis k)
    # type = "all" -> P(all rejected by analysis k)
    power_subset_at_k <- function(S, subset, k, type = c("any", "all")) {
      type <- match.arg(type)
      subset <- as.integer(subset)
      X <- S[subset, k, , drop = FALSE]      # |subset| x S
      hits <- colSums(X > 0)                 # count per simulation
      if (type == "any") mean(hits > 0) else mean(hits == length(subset))
    }

    # --- Tidy table builder---

    # Parameters:
    # - analysis_indexes: vector of analysis indices to include in output (default: all)
    # - hyp_indexes: vector of hypothesis indices for individual power (default: all)
    # - subsets_any_by_analysis: list where element [[k]] contains named subsets for "any" metric at analysis k
    # - subsets_all_by_analysis: list where element [[k]] contains named subsets for "all" metric at analysis k
    # - analysis_times: vector of analysis times from analyses$time (required for expected time metrics)
    get_sim_oc <- function(S,
                                                 analysis_indexes                = seq_len(dim(S)[2]),
                                                 hyp_indexes              = seq_len(dim(S)[1]),
                                                 subsets_any_by_analysis = NULL,
                                                 subsets_all_by_analysis = NULL,
                                                 analysis_times = NULL) {
      # --- Internal helpers (package-friendly, no library() calls) ---

      # Power for a subset at a given analysis k:
      # type = "any" -> P(at least one rejected by analysis k)
      # type = "all" -> P(all rejected by analysis k)
      power_subset_at_k <- function(S, subset, k, type = c("any", "all")) {
        type   <- match.arg(type)
        subset <- as.integer(subset)
        X      <- S[subset, k, , drop = FALSE]        # |subset| x S
        hits   <- colSums(X > 0)                      # per-simulation count
        if (type == "any") mean(hits > 0) else mean(hits == length(subset))
      }

      # Safely fetch the list of subsets for analysis k (supports numeric or character indexing)
      get_for_k <- function(x, k) {
        if (is.null(x)) return(list())
        if (!is.null(x[[k]])) return(x[[k]])
        if (!is.null(x[[as.character(k)]])) return(x[[as.character(k)]])
        list()
      }

      # Expected analysis index for a subset (global metric across all simulations)
      # For type = "any": earliest analysis where any in subset is rejected
      # For type = "all": earliest analysis where all in subset are rejected
      expected_analysis_for_subset <- function(S, subset, type = c("any", "all")) {
        type    <- match.arg(type)
        subset  <- as.integer(subset)
        K       <- dim(S)[2]
        Sdim    <- dim(S)[3]
        earliest <- rep.int(NA_integer_, Sdim)

        for (sim in seq_len(Sdim)) {
          mat <- S[subset, , sim, drop = FALSE]       # |subset| x K
          if (type == "any") {
            idx <- which(colSums(mat) > 0L)
          } else {
            idx <- which(colSums(mat) == length(subset))
          }
          earliest[sim] <- if (length(idx) > 0L) min(idx) else NA_integer_
        }
        mean(earliest, na.rm = TRUE)
      }

      # Expected success time for a subset (global metric across all simulations)
      # For type = "any": time at earliest analysis where any in subset is rejected
      # For type = "all": time at earliest analysis where all in subset are rejected
      expected_time_for_subset <- function(S, subset, type = c("any", "all")) {
        type    <- match.arg(type)
        subset  <- as.integer(subset)
        K       <- dim(S)[2]
        Sdim    <- dim(S)[3]
        earliest_time <- rep.int(NA_real_, Sdim)

        for (sim in seq_len(Sdim)) {
          mat <- S[subset, , sim, drop = FALSE]       # |subset| x K
          if (type == "any") {
            idx <- which(colSums(mat) > 0L)
          } else {
            idx <- which(colSums(mat) == length(subset))
          }
          earliest_time[sim] <- if (length(idx) > 0L) analysis_times[min(idx)] else NA_real_
        }
        mean(earliest_time, na.rm = TRUE)
      }

      # Flatten per-analysis lists into a single list of unique subsets (names preserved if present)
      flatten_subsets <- function(x) {
        if (is.null(x)) return(list())
        all_subsets <- purrr::reduce(x, c)
        # Deduplicate by subset content, keeping first occurrence (with name if present)
        unique_keys <- unique(sapply(all_subsets, function(s) paste(sort(s), collapse = ",")))
        unique_subsets <- list()
        for (key in unique_keys) {
          idx <- which(sapply(all_subsets, function(s) paste(sort(s), collapse = ",")) == key)[1]
          unique_subsets[[length(unique_subsets) + 1]] <- all_subsets[[idx]]
          if (!is.null(names(all_subsets)[idx])) {
            names(unique_subsets)[length(unique_subsets)] <- names(all_subsets)[idx]
          }
        }
        unique_subsets
      }

      # --- Precompute individual powers (J x K matrix, mean over simulations) ---
      ind_mat <- apply(S, c(1, 2), mean)

      # --- 1) Analysis-specific power table -------------------------------------

      # Individual rows
      ind_rows <- as.data.frame(expand.grid(
        hypothesis_index = hyp_indexes,
        analysis_index   = analysis_indexes,
        KEEP.OUT.ATTRS   = FALSE,
        stringsAsFactors = FALSE
      )) |>
        tibble::as_tibble() |>
        dplyr::mutate(
          metric      = "Power",
          subset_name = paste0("H", .data$hypothesis_index),
          hypotheses  = purrr::map(.data$hypothesis_index, ~ as.integer(.x)),
          value       = mapply(function(j, k) ind_mat[j, k],
                               .data$hypothesis_index, .data$analysis_index)
        ) |>
        dplyr::select("metric", "subset_name", "hypotheses",
                      "analysis_index", "value")

      # "At least one" rows (per-analysis)
      any_rows <- purrr::map_dfr(analysis_indexes, function(k) {
        subsets_k <- get_for_k(subsets_any_by_analysis, k)
        if (length(subsets_k) == 0L) return(tibble::tibble())
        purrr::map2_dfr(
          .x = subsets_k,
          .y = names(subsets_k),
          ~{
            subset <- as.integer(.x)
            nm     <- if (!is.null(.y) && nzchar(.y)) .y else paste(subset, collapse = ",")
            tibble::tibble(
              metric         = "Probability of success for at least one Hi",
              subset_name    = nm,
              hypotheses     = list(subset),
              analysis_index = k,
              value          = power_subset_at_k(S, subset, k, type = "any")
            )
          }
        )
      })

      # "All" rows (per-analysis)
      all_rows <- purrr::map_dfr(analysis_indexes, function(k) {
        subsets_k <- get_for_k(subsets_all_by_analysis, k)
        if (length(subsets_k) == 0L) return(tibble::tibble())
        purrr::map2_dfr(
          .x = subsets_k,
          .y = names(subsets_k),
          ~{
            subset <- as.integer(.x)
            nm     <- if (!is.null(.y) && nzchar(.y)) .y else paste(subset, collapse = ",")
            tibble::tibble(
              metric         = "Probability of success for all Hi",
              subset_name    = nm,
              hypotheses     = list(subset),
              analysis_index = k,
              value          = power_subset_at_k(S, subset, k, type = "all")
            )
          }
        )
      })

      oc_at_analyses <- dplyr::bind_rows(ind_rows, any_rows, all_rows) |>
        dplyr::arrange(
          "analysis_index",
          factor(.data$metric, levels = c("Power", "Power (any H)", "Power (all H)")),
          "subset_name"
        )

      # --- 2) Summary over analyses (computed once per subset/hypothesis) ----

      # Individual expected analysis
      expected_individual <- tibble::tibble(
        metric            = "Expected Success Analysis ",
        subset_name       = paste0("H", hyp_indexes),
        hypotheses        = purrr::map(hyp_indexes, ~ as.integer(.x)),
        value             = purrr::map_dbl(hyp_indexes, ~ expected_analysis_for_subset(S, .x, type = "any"))
      )

      # Individual expected time (if analysis_times provided)
      expected_time_individual <- if (!is.null(analysis_times)) {
        tibble::tibble(
          metric            = "Expected Success Time",
          subset_name       = paste0("H", hyp_indexes),
          hypotheses        = purrr::map(hyp_indexes, ~ as.integer(.x)),
          value             = purrr::map_dbl(hyp_indexes, ~ expected_time_for_subset(S, .x, type = "any"))
        )
      } else {
        tibble::tibble()
      }

      # Flatten per-analysis "any" subsets, then compute expected analysis per unique subset
      flat_any <- flatten_subsets(subsets_any_by_analysis)
      expected_any <- if (length(flat_any) > 0L) {
        purrr::map2_dfr(flat_any, names(flat_any), ~{
          subset <- as.integer(.x)
          nm     <- if (!is.null(.y) && nzchar(.y)) .y else paste(subset, collapse = ",")
          tibble::tibble(
            metric        = "Expected Success Analysis (at least one Hi)",
            subset_name   = nm,
            hypotheses    = list(subset),
            value         = expected_analysis_for_subset(S, subset, type = "any")
          )
        })
      } else {
        tibble::tibble()
      }

      # Expected time for "any" subsets (if analysis_times provided)
      expected_time_any <- if (!is.null(analysis_times) && length(flat_any) > 0L) {
        purrr::map2_dfr(flat_any, names(flat_any), ~{
          subset <- as.integer(.x)
          nm     <- if (!is.null(.y) && nzchar(.y)) .y else paste(subset, collapse = ",")
          tibble::tibble(
            metric        = "Expected Success Time (at least one Hi)",
            subset_name   = nm,
            hypotheses    = list(subset),
            value         = expected_time_for_subset(S, subset, type = "any")
          )
        })
      } else {
        tibble::tibble()
      }

      # Flatten per-analysis "all" subsets, then compute expected analysis per unique subset
      flat_all <- flatten_subsets(subsets_all_by_analysis)
      expected_all <- if (length(flat_all) > 0L) {
        purrr::map2_dfr(flat_all, names(flat_all), ~{
          subset <- as.integer(.x)
          nm     <- if (!is.null(.y) && nzchar(.y)) .y else paste(subset, collapse = ",")
          tibble::tibble(
            metric         = "Expected Success Analysis (for all Hi)",
            subset_name    = nm,
            hypotheses     = list(subset),
            value          = expected_analysis_for_subset(S, subset, type = "all")
          )
        })
      } else {
        tibble::tibble()
      }

      # Expected time for "all" subsets (if analysis_times provided)
      expected_time_all <- if (!is.null(analysis_times) && length(flat_all) > 0L) {
        purrr::map2_dfr(flat_all, names(flat_all), ~{
          subset <- as.integer(.x)
          nm     <- if (!is.null(.y) && nzchar(.y)) .y else paste(subset, collapse = ",")
          tibble::tibble(
            metric         = "Expected Success Time (for all Hi)",
            subset_name    = nm,
            hypotheses     = list(subset),
            value          = expected_time_for_subset(S, subset, type = "all")
          )
        })
      } else {
        tibble::tibble()
      }

      oc_across_analyses <- dplyr::bind_rows(expected_individual, expected_time_individual,
                                              expected_any, expected_time_any,
                                              expected_all, expected_time_all)

      # Return both tables
      list(
        oc_at_analyses     = oc_at_analyses,
        oc_across_analyses = oc_across_analyses
      )
    }

    # --- EXAMPLE: specify subsets per analysis ---

    # For each analysis k, define a named list of subsets.
    # If you want the "global" subset (e.g., {1,2,3}) applied everywhere, just include it inside each element.
    # subsets_any_by_analysis <- list(
    #  `1` = list("H1 or H2"        = c(1, 2),
    #             "Any of H1,H2,H3" = c(1, 2, 3)),
    #  `2` = list("H2 or H3"        = c(2, 3),
    #             "Any of H1,H2,H3" = c(1, 2, 3)),
    #  `3` = list("H1 or H3"        = c(1, 3),
    #             "Any of H1,H2,H3" = c(1, 2, 3)),
    #  `4` = list("H1 or H2"        = c(1, 2),
    #             "Any of H1,H2,H3" = c(1, 2, 3))
    #)
    # similar for 'subsets_all_by_analysis'

    # Compute power metrics from 3D rejection array
    oc_results <- get_sim_oc(
      S                         = rejection_array,
      subsets_any_by_analysis   = if("power_subsets_any" %in% names(analyses)) analyses$power_subsets_any else NULL,
      subsets_all_by_analysis   = if("power_subsets_all" %in% names(analyses)) analyses$power_subsets_all else NULL,
      analysis_times            = analyses$time
    )

    return( list(
      marginal_oc = oc_results
    ))

  } else if (method == "ipd") {
    # Add IPD code here
    stop("IPD method not yet implemented")
  }
}
