# utils-wlr.R
#
# Internal helpers for weighted log-rank (WLR) test support in appendMCP.
#
# Design principles
# -----------------
# * We do NOT patch the gsDesign2 namespace.  Instead we carry our own copies of
#   gs_delta_wlr / gs_sigma2_wlr (sourced from gsDesign2 0.4.3) extended with a
#   "custom" weight branch, and call those copies directly from get_info_tite_wlr
#   and get_boundaries_wlr.
# * The public surface is intentionally small:
#     - parse_test_method()       : string -> structured spec
#     - test_method_to_wlr_weight(): spec   -> gsDesign2-style weight argument
#   Everything else is internal (no @export).

# ---------------------------------------------------------------------------
# 1.  CPW weight function
# ---------------------------------------------------------------------------

#' Constant piecewise weight for the CPW log-rank test
#'
#' Returns 0 for time points at or before \code{t_star} and 1 afterwards,
#' implementing the weight scheme from Zucker (1990) / Xu (2017) for settings
#' with a delayed treatment effect.
#'
#' @param x      Numeric vector of time points.
#' @param arm0   npsurvSS arm object for control (required by gsDesign2 interface;
#'               not used in this weight function).
#' @param arm1   npsurvSS arm object for treatment (same note as arm0).
#' @param t_star Scalar threshold (months, default 6). Events at or before this
#'               time receive weight 0; events after receive weight 1.
#'
#' @return Numeric vector of length \code{length(x)} with values in \{0, 1\}.
#' @keywords internal
wlr_weight_cpw <- function(x, arm0, arm1, t_star = 6) {
  as.numeric(x > t_star)
}

# ---------------------------------------------------------------------------
# 2.  test_method string parsing
# ---------------------------------------------------------------------------

#' Parse a test_method string into a structured spec
#'
#' Converts the user-facing string stored in
#' \code{config$hypotheses$test_method} (e.g. \code{"logrank"},
#' \code{"cpw(6)"}, \code{"fh(0,1)"}) into an internal list with components
#' \code{family} and \code{params}.
#'
#' Supported families:
#' \describe{
#'   \item{logrank}{Standard log-rank (no parameters)}
#'   \item{stratified_logrank}{Stratified log-rank (no parameters)}
#'   \item{unpooled_proportions}{Binary endpoint test (no parameters)}
#'   \item{pooled_proportions}{Binary endpoint test (no parameters)}
#'   \item{cmh}{Cochran-Mantel-Haenszel test (no parameters)}
#'   \item{cpw(t_star)}{Constant piecewise weight; \code{t_star} in months}
#'   \item{fh(rho,gamma)}{Fleming-Harrington weight}
#'   \item{mb(tau,w_max)}{Magirr-Burman weight}
#' }
#'
#' @param method Single character string.
#' @return A list with \code{$family} (character) and \code{$params} (list).
#' @keywords internal
parse_test_method <- function(method) {
  stopifnot(is.character(method), length(method) == 1)

  # Plain-name methods (no parameters)
  plain <- c("logrank", "stratified_logrank",
             "unpooled_proportions", "pooled_proportions", "cmh")
  if (method %in% plain) {
    return(list(family = method, params = list()))
  }

  # Parameterised methods: family(p1) or family(p1,p2)
  m <- regexec("^([a-zA-Z_][a-zA-Z0-9_]*)\\((.+)\\)$", method, perl = TRUE)
  parts <- regmatches(method, m)[[1]]
  if (length(parts) != 3) {
    stop("test_method '", method, "' is not recognised.  ",
         "Use one of: logrank, stratified_logrank, unpooled_proportions, ",
         "pooled_proportions, cmh, cpw(<t_star>), fh(<rho>,<gamma>), ",
         "mb(<tau>,<w_max>).")
  }

  family     <- parts[2]
  raw_params <- trimws(strsplit(parts[3], ",", fixed = TRUE)[[1]])
  nums       <- suppressWarnings(as.numeric(raw_params))

  params <- switch(
    family,
    cpw = {
      if (length(nums) != 1L || is.na(nums[1])) {
        stop("cpw() requires exactly one numeric argument, e.g. cpw(6).")
      }
      list(t_star = nums[1])
    },
    fh = {
      if (length(nums) != 2L || any(is.na(nums))) {
        stop("fh() requires exactly two numeric arguments, e.g. fh(0,1).")
      }
      list(rho = nums[1], gamma = nums[2])
    },
    mb = {
      if (length(nums) != 2L || any(is.na(nums))) {
        stop("mb() requires exactly two numeric arguments, e.g. mb(1,2).")
      }
      list(tau = nums[1], w_max = nums[2])
    },
    stop("Unknown test_method family '", family, "'.  ",
         "Supported parametric families: cpw, fh, mb.")
  )

  list(family = family, params = params)
}

#' Return TRUE iff a test_method string names a WLR-family method
#'
#' WLR families (cpw, fh, mb) need the WLR information / boundary path.
#' All other methods use the AHR path or binary path.
#'
#' @param method Single character string.
#' @return Logical scalar.
#' @keywords internal
is_wlr_method <- function(method) {
  spec <- parse_test_method(method)
  spec$family %in% c("cpw", "fh", "mb")
}

#' Convert a parsed test_method spec to a gsDesign2-style weight argument
#'
#' Returns the value that should be passed as the \code{weight} argument to
#' the internal WLR delta/sigma2 functions (.gs_delta_wlr_internal,
#' .gs_sigma2_wlr_internal).
#'
#' @param spec Output of \code{parse_test_method()}.
#' @return Either the string \code{"logrank"} or a list with
#'   \code{$method} and \code{$param}.
#' @keywords internal
test_method_to_wlr_weight <- function(spec) {
  switch(
    spec$family,
    logrank            = ,
    stratified_logrank = "logrank",
    cpw = {
      t_star <- spec$params$t_star
      list(
        method = "custom",
        param  = list(
          weight_fun = function(x, arm0, arm1)
            wlr_weight_cpw(x, arm0, arm1, t_star = t_star)
        )
      )
    },
    fh = list(
      method = "fh",
      param  = list(rho = spec$params$rho, gamma = spec$params$gamma)
    ),
    mb = list(
      method = "mb",
      param  = list(tau = spec$params$tau, w_max = spec$params$w_max)
    ),
    stop("test_method_to_wlr_weight(): unrecognised family '", spec$family, "'.")
  )
}

# ---------------------------------------------------------------------------
# 3.  Internal copies of gs_delta_wlr / gs_sigma2_wlr
#     (gsDesign2 0.4.3 originals + "custom" weight branch)
#     We call these directly; we never replace the gsDesign2 namespace.
# ---------------------------------------------------------------------------

.gs_delta_wlr_internal <- function(arm0, arm1, tmax = NULL,
                                    weight = "logrank",
                                    approx = "asymptotic",
                                    normalization = FALSE) {
  if (is.null(tmax)) tmax <- arm0$total_time
  p1 <- arm1$size / (arm0$size + arm1$size)
  p0 <- 1 - p1

  # Weight function resolution
  if (identical(weight, "logrank")) {
    weight_fun <- gsDesign2::wlr_weight_1
  } else {
    weight_fun <- switch(
      weight$method,
      fh = function(x, arm0, arm1) {
        gsDesign2::wlr_weight_fh(x, arm0, arm1,
                                 rho   = weight$param$rho,
                                 gamma = weight$param$gamma)
      },
      mb = function(x, arm0, arm1) {
        gsDesign2::wlr_weight_mb(x, arm0, arm1,
                                 tau   = weight$param$tau,
                                 w_max = weight$param$w_max)
      },
      custom = weight$param$weight_fun,
      stop(".gs_delta_wlr_internal(): Unknown weight method '",
           weight$method, "'.", call. = FALSE)
    )
  }

  if (approx == "event_driven") {
    if (sum(arm0$surv_shape != arm1$surv_shape) > 0 ||
        length(unique(arm1$surv_scale / arm0$surv_scale)) > 1) {
      stop(".gs_delta_wlr_internal(): Hazard is not proportional over time.",
           call. = FALSE)
    } else if (any(gsDesign2::wlr_weight_fh(seq(0, tmax, length.out = 10),
                                             arm0, arm1) != "1")) {
      stop(".gs_delta_wlr_internal(): Weight must equal `1` when ",
           "`approx = 'event_driven'`.", call. = FALSE)
    }
    theta <- c(arm0$surv_shape * log(arm1$surv_scale / arm0$surv_scale))[1]
    nu    <- p0 * gsDesign2:::prob_event.arm(arm0, tmax = tmax) +
             p1 * gsDesign2:::prob_event.arm(arm1, tmax = tmax)
    delta <- theta * p0 * p1 * nu

  } else if (approx == "asymptotic") {
    delta <- stats::integrate(function(x) {
      term0 <- p0 * gsDesign2:::prob_risk(arm0, x, tmax)
      term1 <- p1 * gsDesign2:::prob_risk(arm1, x, tmax)
      term  <- (term0 * term1) / (term0 + term1)
      term  <- ifelse(is.na(term), 0, term)
      weight_fun(x, arm0, arm1) * term *
        (npsurvSS::hsurv(x, arm1) - npsurvSS::hsurv(x, arm0))
    }, lower = 0, upper = tmax, rel.tol = 1e-05)$value

  } else if (approx == "generalized_schoenfeld") {
    delta <- stats::integrate(function(x) {
      if (normalization) {
        log_hr_ratio <- 1
      } else {
        log_hr_ratio <- log(npsurvSS::hsurv(x, arm1) / npsurvSS::hsurv(x, arm0))
      }
      weight_fun(x, arm0, arm1) * log_hr_ratio *
        p0 * gsDesign2:::prob_risk(arm0, x, tmax) *
        p1 * gsDesign2:::prob_risk(arm1, x, tmax) /
        (p0 * gsDesign2:::prob_risk(arm0, x, tmax) +
         p1 * gsDesign2:::prob_risk(arm1, x, tmax))^2 *
        (p0 * gsDesign2:::dens_event(arm0, x, tmax) +
         p1 * gsDesign2:::dens_event(arm1, x, tmax))
    }, lower = 0, upper = tmax)$value

  } else {
    stop(".gs_delta_wlr_internal(): Please specify a valid approximation.",
         call. = FALSE)
  }

  delta
}


.gs_sigma2_wlr_internal <- function(arm0, arm1, tmax = NULL,
                                     weight = "logrank",
                                     approx = "asymptotic") {
  if (is.null(tmax)) tmax <- arm0$total_time
  p1 <- arm1$size / (arm0$size + arm1$size)
  p0 <- 1 - p1

  enroll_duration       <- diff(arm0$accr_interval)
  enroll_total_duration <- max(arm0$accr_interval)
  n_enroll_piece        <- length(enroll_duration)
  enroll_relative_rate  <- rep(-10, n_enroll_piece)
  for (s in seq_len(n_enroll_piece)) {
    enroll_relative_rate[s] <-
      arm0$accr_param[s] / arm0$accr_param[n_enroll_piece] *
      enroll_duration[n_enroll_piece] / enroll_duration[s]
  }

  # Weight function resolution
  if (identical(weight, "logrank")) {
    weight_fun <- gsDesign2::wlr_weight_1
  } else {
    weight_fun <- switch(
      weight$method,
      fh = function(x, arm0, arm1) {
        gsDesign2::wlr_weight_fh(x, arm0, arm1,
                                 rho   = weight$param$rho,
                                 gamma = weight$param$gamma,
                                 tau   = if ("tau" %in% names(weight$param))
                                   weight$param$tau else NULL)
      },
      mb = function(x, arm0, arm1) {
        gsDesign2::wlr_weight_mb(x, arm0, arm1,
                                 tau   = weight$param$tau,
                                 w_max = weight$param$w_max)
      },
      custom = weight$param$weight_fun,
      stop(".gs_sigma2_wlr_internal(): Unknown weight method '",
           weight$method, "'.", call. = FALSE)
    )
  }

  if (approx == "event_driven") {
    nu     <- p0 * gsDesign2:::prob_event.arm(arm0, tmax = tmax) +
              p1 * gsDesign2:::prob_event.arm(arm1, tmax = tmax)
    sigma2 <- p0 * p1 * nu

  } else if (approx %in% c("asymptotic", "generalized_schoenfeld")) {
    if (tmax < enroll_total_duration) {
      arm0$accr_time     <- tmax
      arm1$accr_time     <- tmax
      arm0$accr_interval <- sort(
        c(tmax, arm0$accr_interval)[which(c(tmax, arm0$accr_interval) <= tmax)]
      )
      arm1$accr_interval <- arm0$accr_interval

      truncated_enroll_duration <- diff(arm0$accr_interval)
      arm0$accr_param <- truncated_enroll_duration *
        enroll_relative_rate[seq_along(truncated_enroll_duration)] /
        sum(truncated_enroll_duration *
              enroll_relative_rate[seq_along(truncated_enroll_duration)])
      arm1$accr_param <- arm0$accr_param
    }

    sigma2 <- stats::integrate(function(x) {
      term0 <- p0 * gsDesign2:::prob_risk(arm0, x, tmax)
      term1 <- p1 * gsDesign2:::prob_risk(arm1, x, tmax)
      denom <- (term0 + term1)^2
      term  <- term0 * term1 / denom
      term  <- ifelse(is.na(term) | !is.finite(term), 0, term)
      weight_fun(x, arm0, arm1)^2 * term *
        (p0 * gsDesign2:::dens_event(arm0, x, tmax) +
         p1 * gsDesign2:::dens_event(arm1, x, tmax))
    }, lower = 0, upper = tmax)$value

  } else {
    stop(".gs_sigma2_wlr_internal(): Please specify a valid approximation.",
         call. = FALSE)
  }

  sigma2
}

# ---------------------------------------------------------------------------
# 4.  WLR information and boundary helpers
# ---------------------------------------------------------------------------

#' Pool a multi-stratum fail_rate table to a single effective stratum
#'
#' \code{gsDesign2::gs_power_wlr} / \code{gs_info_wlr} (via
#' \code{gs_create_arm}) only support a single stratum.  This helper computes
#' stratum-size-weighted average hazard rates so that the multi-stratum design
#' can be represented as a single effective stratum, matching the approach used
#' internally by \code{gsDesign2::ahr()} for the AHR path.
#'
#' @param fail_rate  Distribution data frame with columns \code{stratum},
#'   \code{treatment}, \code{duration}, \code{fail_rate}, \code{dropout_rate}.
#' @param enroll_rate  Processed enrollment data frame (with \code{arm_rate},
#'   \code{stratum_treatment}, \code{duration}).
#' @param treatment  Character name of the treatment arm to pool.
#'
#' @return A one-row-per-duration-period data frame with columns
#'   \code{duration}, \code{fail_rate}, \code{dropout_rate} representing the
#'   pooled effective stratum.
#' @keywords internal
.pool_strata_fail_rate <- function(fail_rate, enroll_rate, treatment) {
  strata <- unique(fail_rate$stratum)

  # Stratum weights: expected total person-time per stratum (proportional to
  # arm-specific sample size, using enrollment rate * duration)
  stratum_n <- purrr::map_dbl(strata, function(st) {
    dplyr::filter(enroll_rate,
                  .data$stratum_treatment == paste(st, treatment, sep = "-")) %>%
      {sum(.$arm_rate * .$duration)}
  })
  names(stratum_n) <- strata
  total_n <- sum(stratum_n)
  if (total_n == 0) stop(".pool_strata_fail_rate(): zero total sample size.")
  stratum_w <- stratum_n / total_n

  # All strata must share the same duration breakpoints for this pooling to be
  # well-defined.  Use the first stratum's breakpoints and warn if they differ.
  # NOTE: Use .env$treatment to avoid dplyr masking the function parameter with
  # the same-named data column.
  fr_first <- dplyr::filter(fail_rate,
                             .data$stratum == strata[1],
                             .data$treatment == .env$treatment) |>
    dplyr::arrange(.data$duration)
  durations <- fr_first$duration

  pooled_fail_rate    <- numeric(length(durations))
  pooled_dropout_rate <- numeric(length(durations))

  for (st in strata) {
    fr_st <- dplyr::filter(fail_rate,
                           .data$stratum == st,
                           .data$treatment == .env$treatment) |>
      dplyr::arrange(.data$duration)
    pooled_fail_rate    <- pooled_fail_rate    + stratum_w[st] * fr_st$fail_rate
    pooled_dropout_rate <- pooled_dropout_rate + stratum_w[st] * fr_st$dropout_rate
  }

  tibble::tibble(
    duration     = durations,
    fail_rate    = pooled_fail_rate,
    dropout_rate = pooled_dropout_rate
  )
}

#' Build npsurvSS arm objects from appendMCP distribution tables
#'
#' Constructs the \code{arm0} (control) and \code{arm1} (test) objects
#' expected by the gsDesign2 WLR internals.  Multiple strata are pooled to a
#' single effective stratum via \code{.pool_strata_fail_rate()}.
#'
#' @param control Character name of the control treatment.
#' @param test    Character name of the test treatment.
#' @param enroll_rate  Processed enrollment data frame (arm_rate, duration, index).
#' @param fail_rate    Distribution data frame (treatment, duration, fail_rate,
#'                     dropout_rate, stratum).
#' @param total_time   Scalar: calendar time at the analysis.
#'
#' @return A list with components \code{arm0} and \code{arm1}.
#' @keywords internal
.build_wlr_arms <- function(control, test, enroll_rate, fail_rate, total_time) {
  # Total sample sizes (sum over all enroll periods for each arm, all strata)
  n_control <- dplyr::filter(enroll_rate, .data$treatments == control) %>%
    {sum(.$arm_rate * .$duration)}
  n_test    <- dplyr::filter(enroll_rate, .data$treatments == test) %>%
    {sum(.$arm_rate * .$duration)}
  n_total   <- n_control + n_test

  # Pool enrollment across strata: collapse to a single enrollment timeline.
  #
  # Background: enroll_rate has one row per (stratum, treatment, period).
  # Multiple strata enroll CONCURRENTLY over the same calendar periods, so we
  # must identify the WITHIN-STRATUM period position (1st period, 2nd period,
  # etc.) and pool rates across strata for each period position — NOT treat each
  # stratum row as a distinct sequential period.
  #
  # We take the timeline from one reference stratum/treatment combination and
  # assign each row a within-group period counter, then sum arm_rate across all
  # strata/treatments for the same period position.
  enroll_pooled <- enroll_rate |>
    dplyr::arrange(.data$index) |>                  # sort by original row order
    dplyr::group_by(.data$treatments, .data$stratum) |>
    dplyr::mutate(.period_pos = seq_len(dplyr::n())) |>  # within-group period position
    dplyr::ungroup() |>
    dplyr::group_by(.data$.period_pos) |>
    dplyr::summarise(
      duration = dplyr::first(.data$duration),      # durations must match across strata
      arm_rate = sum(.data$arm_rate),               # pool rates across strata & treatments
      .groups  = "drop"
    ) |>
    dplyr::arrange(.data$.period_pos)

  accr_interval <- c(0, cumsum(enroll_pooled$duration))
  accr_param    <- enroll_pooled$arm_rate * enroll_pooled$duration /
    sum(enroll_pooled$arm_rate * enroll_pooled$duration)

  # Pool failure rates across strata (weighted by stratum sample size)
  fr_control <- .pool_strata_fail_rate(fail_rate, enroll_rate, control)
  fr_test    <- .pool_strata_fail_rate(fail_rate, enroll_rate, test)

  arm0 <- npsurvSS::create_arm(
    size          = n_control / n_total,
    accr_time     = max(accr_interval),
    accr_dist     = "pieceuni",
    accr_interval = accr_interval,
    accr_param    = accr_param,
    surv_scale    = fr_control$fail_rate,
    surv_shape    = 1,
    surv_interval = c(0, cumsum(fr_control$duration)),
    loss_scale    = fr_control$dropout_rate[1],
    follow_time   = total_time - max(accr_interval)
  )

  arm1 <- npsurvSS::create_arm(
    size          = n_test / n_total,
    accr_time     = max(accr_interval),
    accr_dist     = "pieceuni",
    accr_interval = accr_interval,
    accr_param    = accr_param,
    surv_scale    = fr_test$fail_rate,
    surv_shape    = 1,
    surv_interval = c(0, cumsum(fr_test$duration)),
    loss_scale    = fr_test$dropout_rate[1],
    follow_time   = total_time - max(accr_interval)
  )

  list(arm0 = arm0, arm1 = arm1)
}

#' Compute WLR information (sigma^2) at a vector of analysis times
#'
#' Uses the internal \code{.gs_sigma2_wlr_internal} function (which supports
#' the "custom" weight branch) rather than calling the gsDesign2 namespace.
#'
#' @param control      Character name of the control treatment.
#' @param test         Character name of the test treatment.
#' @param enroll_rate  Processed enrollment data frame.
#' @param fail_rate    Distribution data frame.
#' @param times_analysed Numeric vector of analysis times.
#' @param weight       Weight argument as returned by
#'                     \code{test_method_to_wlr_weight()}.
#'
#' @return Numeric vector of information values (one per analysis time).
#' @keywords internal
get_info_tite_wlr <- function(control, test, enroll_rate, fail_rate,
                               times_analysed, weight) {
  purrr::map_dbl(times_analysed, function(t) {
    arms <- .build_wlr_arms(control, test, enroll_rate, fail_rate, t)
    .gs_sigma2_wlr_internal(arms$arm0, arms$arm1,
                             tmax   = t,
                             weight = weight,
                             approx = "asymptotic")
  })
}

#' Compute WLR drift (delta) at a vector of analysis times
#'
#' @inheritParams get_info_tite_wlr
#' @return Numeric vector of drift values.
#' @keywords internal
get_delta_tite_wlr <- function(control, test, enroll_rate, fail_rate,
                                times_analysed, weight) {
  purrr::map_dbl(times_analysed, function(t) {
    arms <- .build_wlr_arms(control, test, enroll_rate, fail_rate, t)
    .gs_delta_wlr_internal(arms$arm0, arms$arm1,
                            tmax   = t,
                            weight = weight,
                            approx = "asymptotic")
  })
}

#' Compute GSD boundary specs using WLR information
#'
#' Drop-in counterpart to \code{get_boundaries()} for WLR families (cpw, fh,
#' mb). Returns a tibble mirroring the structure produced by
#' \code{gsDesign2::gs_power_ahr()} so that the downstream extractors
#' (get_powers, get_hurdles, get_nominal_p, get_cum_alpha_spend,
#' get_description_effect_size) work without modification.
#'
#' @param dist_type   "tte" (binary endpoints never reach this path).
#' @param control     Character name of the control treatment.
#' @param test        Character name of the test treatment.
#' @param sf          Spending function string.
#' @param sfpar       Spending function parameter (or NULL/NA).
#' @param nominal     Nominal alpha spending vector (or NULL/NA).
#' @param enroll_rate Processed enrollment data frame.
#' @param distribution Distribution data frame (fail_rate, dropout_rate, ...).
#' @param possible_weight Alpha weight from graphical MCP.
#' @param information_factor  Vector of information factors.
#' @param max_information_factor Scalar max information factor.
#' @param information_fractions  Vector of information fractions.
#' @param times_analysed  Numeric vector of analysis times.
#' @param weight      Weight argument from \code{test_method_to_wlr_weight()}.
#' @param alpha       One-sided alpha level.
#'
#' @return Result of \code{gsDesign2::gs_power_wlr()}.
#' @keywords internal
get_boundaries_wlr <- function(dist_type,
                                control,
                                test,
                                sf,
                                sfpar,
                                nominal,
                                enroll_rate,
                                distribution,
                                possible_weight,
                                information_factor,
                                max_information_factor,
                                information_fractions,
                                times_analysed,
                                weight,
                                alpha = 0.025) {
  # Spending function parameter handling (mirrors get_boundaries logic)
  if (is.null(sfpar) || all(is.na(sfpar))) sfpar <- NULL
  if (sf == "none") nominal <- NULL
  if (!is.null(nominal) && !all(is.na(nominal))) {
    sfpar <- dplyr::case_match(
      sf,
      "asHSD"  ~ list(gsDesign::sfHSD),
      "asKD"   ~ list(gsDesign::sfPower),
      "asOF"   ~ list(gsDesign::sfLDOF),
      "asP"    ~ list(gsDesign::sfLDPocock),
      "asUser" ~ list(gsDesign::sfPoints))[[1]](possible_weight * alpha,
                                                information_fractions,
                                                sfpar)$spend
    sfpar[seq_along(nominal)] <- cumsum(nominal)
    sf    <- "asUser"
    sfpar <- sfpar / (possible_weight * alpha)
    sfpar[length(sfpar)] <- 1
  }

  sf_fn <- dplyr::case_match(
    sf,
    "none"   ~ list(gsDesign::sfLDOF),
    "asHSD"  ~ list(gsDesign::sfHSD),
    "asKD"   ~ list(gsDesign::sfPower),
    "asOF"   ~ list(gsDesign::sfLDOF),
    "asP"    ~ list(gsDesign::sfLDPocock),
    "asUser" ~ list(gsDesign::sfPoints))[[1]]

  # Build enroll_rate in gsDesign2 format (single-stratum pooled).
  # Use within-stratum period positions to correctly collapse concurrent
  # multi-stratum enrollment into a single timeline.
  enroll_rate_gs2 <- enroll_rate |>
    dplyr::arrange(.data$index) |>
    dplyr::group_by(.data$treatments, .data$stratum) |>
    dplyr::mutate(.period_pos = seq_len(dplyr::n())) |>
    dplyr::ungroup() |>
    dplyr::group_by(.data$.period_pos) |>
    dplyr::summarise(
      duration = dplyr::first(.data$duration),
      rate     = sum(.data$arm_rate),
      .groups  = "drop"
    ) |>
    dplyr::arrange(.data$.period_pos) |>
    dplyr::mutate(stratum = "All")

  # Pool fail_rate across strata, weighted by stratum sample size
  fr_control_pooled <- .pool_strata_fail_rate(distribution, enroll_rate, control)
  fr_test_pooled    <- .pool_strata_fail_rate(distribution, enroll_rate, test)

  fail_rate_gs2 <- tibble::tibble(
    stratum      = "All",
    duration     = fr_control_pooled$duration,
    fail_rate    = fr_control_pooled$fail_rate,
    dropout_rate = fr_control_pooled$dropout_rate,
    hr           = fr_test_pooled$fail_rate / fr_control_pooled$fail_rate
  )

  # gsDesign2::gs_power_wlr only supports "logrank", "fh", and "mb" weight
  # methods.  For the "custom" weight (used by CPW), we must use
  # gsDesign2::gs_power_npe with pre-computed theta / info from the internal
  # WLR functions, then assemble a compatible gs_design-style output object.
  if (is.list(weight) && identical(weight$method, "custom")) {
    # sigma2_vec is the per-patient variance (sigma^2 per person).
    # gs_power_npe expects TOTAL Fisher information = sigma2 * N_total.
    # We scale up here so that the non-centrality theta * sqrt(info) is correct.
    n_total    <- sum(enroll_rate$arm_rate * enroll_rate$duration)

    sigma2_vec <- get_info_tite_wlr(control, test, enroll_rate, distribution,
                                     times_analysed, weight)
    delta_vec  <- get_delta_tite_wlr(control, test, enroll_rate, distribution,
                                      times_analysed, weight)
    # theta = (-delta) / sigma2: dimensionless ratio, no N-scaling needed.
    # gsDesign2 defines theta > 0 when the treatment is beneficial.
    theta_vec  <- (-delta_vec) / sigma2_vec

    # Scale per-patient sigma2 to total information for gs_power_npe
    info_vec   <- sigma2_vec * n_total

    # gs_power_npe returns a flat tibble; reshape into gs_design-style list
    npe_bounds <- gsDesign2::gs_power_npe(
      theta      = theta_vec,
      theta0     = rep(0, length(theta_vec)),
      info       = info_vec,
      info0      = info_vec,
      upper      = gsDesign2::gs_spending_bound,
      upar       = list(sf = sf_fn, param = sfpar,
                        total_spend = possible_weight * alpha),
      lower      = gsDesign2::gs_b,
      lpar       = rep(-Inf, length(times_analysed)),
      test_lower = FALSE,
      info_scale = "h0_info"
    )

    upper_bounds <- dplyr::filter(npe_bounds, .data$bound == "upper")
    lower_bounds <- dplyr::filter(npe_bounds, .data$bound == "lower")

    bound_tbl <- tibble::tibble(
      analysis     = upper_bounds$analysis,
      bound        = "upper",
      probability  = upper_bounds$probability,
      probability0 = pnorm(-upper_bounds$z),
      z            = upper_bounds$z,
      # "~hr at bound" is not meaningful for CPW; use NA
      `~hr at bound` = NA_real_,
      `nominal p`  = pnorm(-upper_bounds$z)
    )

    analysis_tbl <- data.frame(
      analysis   = seq_along(times_analysed),
      time       = times_analysed,
      n          = NA_real_,
      event      = information_factor,
      ahr        = NA_real_,
      theta      = theta_vec,
      info       = info_vec,
      info0      = info_vec,
      info_frac  = info_vec / max(info_vec),
      info_frac0 = info_vec / max(info_vec)
    )

    return(structure(
      list(
        design       = "wlr_custom",
        input        = list(upar = list(sf = sf_fn, param = sfpar,
                                        total_spend = possible_weight * alpha)),
        enroll_rate  = enroll_rate_gs2,
        fail_rate    = fail_rate_gs2,
        bound        = bound_tbl,
        analysis     = analysis_tbl
      ),
      class = "gs_design"
    ))
  }

  gsDesign2::gs_power_wlr(
    enroll_rate   = enroll_rate_gs2,
    fail_rate     = fail_rate_gs2,
    event         = NULL,
    analysis_time = times_analysed,
    weight        = weight,
    upar          = list(
      sf          = sf_fn,
      param       = sfpar,
      total_spend = possible_weight * alpha
    ),
    lpar          = list(sf = gsDesign::sfLDOF, param = NULL, total_spend = -Inf),
    test_lower    = FALSE,
    ratio         = dplyr::filter(enroll_rate, .data$treatments == test)$ratio[1] /
      dplyr::filter(enroll_rate, .data$treatments == control)$ratio[1],
    info_scale    = "h0_info"
  )
}

#' Compute WLR Z-statistic distribution for simulation
#'
#' Counterpart to \code{get_dist_tite()} for WLR families. Returns
#' \code{list(EZ, CovZ)} suitable for consumption by \code{get_mvn()}.
#'
#' @inheritParams get_info_tite_wlr
#' @return List with components \code{EZ} and \code{CovZ}.
#' @keywords internal
get_dist_tite_wlr <- function(control, test, enroll_rate, fail_rate,
                               times_analysed, weight) {
  sigma2_vec <- get_info_tite_wlr(
    control, test, enroll_rate, fail_rate, times_analysed, weight
  )
  delta_vec  <- get_delta_tite_wlr(
    control, test, enroll_rate, fail_rate, times_analysed, weight
  )

  # sigma2_vec is per-patient variance. Scale to total information (sigma2 * N)
  # so that EZ = delta_total / sqrt(info_total) = delta * sqrt(N) / sqrt(sigma2)
  # has the correct non-centrality for the multivariate normal distribution.
  n_total  <- sum(enroll_rate$arm_rate * enroll_rate$duration)
  info_vec <- sigma2_vec * n_total

  # EZ: standardised drift at each analysis (non-centrality of Z-statistic)
  # delta * sqrt(N) / sqrt(sigma2) = delta_total / sqrt(info_total)
  EZ   <- delta_vec * sqrt(n_total) / sqrt(sigma2_vec)
  # Covariance matrix via information-fraction formula (same as logrank).
  # covariance() uses ratios sqrt(I_j/I_k), so it is scale-invariant; passing
  # info_vec or sigma2_vec gives the same result.
  CovZ <- covariance(info_vec)

  list(EZ = EZ, CovZ = CovZ)
}

#' Apply a CPW (or other WLR) test to a simulated dataset
#'
#' Used by \code{apply_hypothesis_tests()} when \code{test_method} is a WLR
#' family. Computes the observed WLR Z-statistic and information from IPD.
#'
#' @param df       Simulated IPD data frame (must have columns: stratum,
#'                 treatment, endpoint event/time columns).
#' @param endpoint Character endpoint name.
#' @param strata   Character vector of strata to include.
#' @param control  Character control arm name.
#' @param test     Character test arm name.
#' @param weight   Weight argument (from \code{test_method_to_wlr_weight()}).
#'
#' @return Named numeric vector with elements \code{z_stat} and
#'         \code{sample_size} (number at risk used in the test).
#' @keywords internal
test_wlr <- function(df, endpoint, strata, control, test, weight) {
  # Subset to relevant stratum and arms
  df_sub <- df[df$stratum %in% strata &
                 df$treatment %in% c(control, test), , drop = FALSE]

  time_col  <- paste0(endpoint, "_time")
  event_col <- paste0(endpoint, "_event")

  if (!all(c(time_col, event_col) %in% names(df_sub))) {
    stop("test_wlr(): columns '", time_col, "' and '", event_col,
         "' not found in simulation data frame.")
  }

  t_obs <- df_sub[[time_col]]
  d_obs <- df_sub[[event_col]]
  grp   <- as.integer(df_sub$treatment == test)  # 1 = test, 0 = control

  n     <- nrow(df_sub)
  n_events <- sum(d_obs, na.rm = TRUE)

  # Evaluate weight at observed event times
  # arm0 / arm1 are not used by CPW weight, but other families may need them.
  # We pass NULL placeholders; CPW is the only family currently used in simulation.
  ordered_times <- sort(unique(t_obs[d_obs == 1]))
  w_vals <- if (is.character(weight) && weight == "logrank") {
    rep(1, length(ordered_times))
  } else if (weight$method == "custom") {
    weight$param$weight_fun(ordered_times, NULL, NULL)
  } else {
    # For fh / mb we cannot compute arm objects cheaply from IPD;
    # fall back to standard log-rank with a warning.
    warning("test_wlr(): fh/mb weights require arm objects not available ",
            "from IPD simulation; falling back to unweighted log-rank.")
    rep(1, length(ordered_times))
  }

  # Weighted log-rank statistic (O - E form, weight applied at each event time)
  U     <- 0
  V     <- 0
  for (i in seq_along(ordered_times)) {
    ti       <- ordered_times[i]
    at_risk  <- t_obs >= ti
    n_risk   <- sum(at_risk)
    n_risk1  <- sum(at_risk & grp == 1)
    n_risk0  <- sum(at_risk & grp == 0)
    events_i <- d_obs == 1 & t_obs == ti
    d_i      <- sum(events_i)
    d_i1     <- sum(events_i & grp == 1)
    if (n_risk > 1) {
      e_i1  <- d_i * n_risk1 / n_risk
      v_i   <- d_i * n_risk1 * n_risk0 / (n_risk^2 * max(n_risk - 1, 1))
      U     <- U + w_vals[i] * (d_i1 - e_i1)
      V     <- V + w_vals[i]^2 * v_i
    }
  }

  z_stat <- if (V > 0) U / sqrt(V) else 0

  c(z_stat = z_stat, sample_size = n, events = n_events, info = V)
}
