# Helper functions, primarily for the process.R file

# Declare global variables to avoid R CMD check NOTEs
utils::globalVariables(".")

#' Get boundary specifications for group sequential design
#' @param dist_type Type of endpoint (binary or time-to-event)
#' @param control Control treatment character string
#' @param test Test treatment character string
#' @param sf Spending function string (in rpact terminology)
#' @param sfpar Spending function parameter (if needed)
#' @param nominal Nominal spend information (if using)
#' @param enroll_rate Enrollment rate object
#' @param distribution Distributional information object
#' @param information_factor Information factors (either ubjects or events)
#' @param max_information_factor Maximum information factor (either max subjects or max events)
#' @param information_fractions Information fractions across the analyses
#' @param times_analysed Analysis times (for time-to-event endpoints)
#' @param possible_weight Weight in the analysis (from the graphical test)
#' @param control_pooled_rate Control arm pooled rate (for binary outcomes)
#' @param test_pooled_rate Test arm pooled rate (for binary outcomes)
#' @param alpha Type I error rate
#' @return Boundary specifications object
get_boundaries <- function(
  dist_type,
  control,
  test,
  sf,
  sfpar,
  nominal,
  enroll_rate,
  distribution,
  possible_weight,
  control_pooled_rate,
  test_pooled_rate,
  information_factor,
  max_information_factor,
  information_fractions,
  times_analysed = NULL,
  alpha = 0.025
) {
  if (dist_type == "bin") {
    # Use {rpact} for binary outcomes
    n1 <- dplyr::filter(enroll_rate, .data$treatments %in% test) %>%
      {.$arm_rate*.$duration} |>
      sum()
    n2 <- dplyr::filter(enroll_rate, .data$treatments %in% control) %>%
      {.$arm_rate*.$duration} |>
      sum()
    rpact::getPowerRates(
      design              = rpact::getDesignGroupSequential(
        kMax             = length(information_fractions),
        alpha            = possible_weight*alpha,
        informationRates = information_fractions,
        typeOfDesign     = `if`(sf == "none", "OF", sf),
        gammaA           = `if`(is.null(sfpar), NA_real_, sfpar)
      ),
      pi1                    = test_pooled_rate,
      pi2                    = control_pooled_rate,
      maxNumberOfSubjects    = max_information_factor,
      allocationRatioPlanned = n1/n2
    )
  } else {
    # Use {gsDesign2} for time-to-event outcomes
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
      sf <- "asUser"
      sfpar <- sfpar/(possible_weight*alpha)
      sfpar[length(sfpar)]     <- 1
    }
    gsDesign2::gs_power_ahr(
      enroll_rate = dplyr::group_by(enroll_rate, .data$stratum, .data$rate, .data$duration, .data$index) |>
        dplyr::summarise(rate = sum(.data$arm_rate), .groups = "drop") |> dplyr::arrange(.data$index),
      fail_rate   = tidyr::pivot_wider(distribution,
                                       names_from  = "treatment",
                                       values_from = "fail_rate",
                                       id_cols     = c("stratum", "duration",
                                                       "dropout_rate"),
                                       values_fn = list)  |> tidyr::unnest_longer(-("stratum":"dropout_rate")) %>%
        {tibble::tibble(duration     = .$duration,
                        fail_rate    = .[[control]],
                        dropout_rate = .$dropout_rate,
                        hr           = .[[test]]/.[[control]],
                        stratum      = .$stratum)},
      event       = NULL,
      analysis_time = times_analysed,
      upar        = list(sf          =
                           dplyr::case_match(sf,
                                      "none"   ~ list(gsDesign::sfLDOF),
                                      "asHSD"  ~ list(gsDesign::sfHSD),
                                      "asKD"   ~ list(gsDesign::sfPower),
                                      "asOF"   ~ list(gsDesign::sfLDOF),
                                      "asP"    ~ list(gsDesign::sfLDPocock),
                                      "asUser" ~ list(gsDesign::sfPoints))[[1]],
                         param       = sfpar,
                         total_spend = possible_weight*alpha),
      test_lower  = FALSE,
      ratio       = dplyr::filter(enroll_rate, .data$treatments == test)$ratio[1]/
        dplyr::filter(enroll_rate, .data$treatments == control)$ratio[1],
      info_scale  = "h0_info"
    )
  }
}

#' Extract cumulative powers from OC object
#' @param oc Operating characteristics object
#' @return Vector of cumulative powers
get_powers <- function(oc) {
  if ("TrialDesignPlanRates" %in% class(oc)) {
    oc$rejectPerStage |> as.numeric() |> cumsum()
  } else {
    oc$bound$probability
  }
}

#' Extract exit hurdles from OC object
#' @param oc Operating characteristics object
#' @return Vector of exit hurdles
get_hurdles <- function(oc) {
  if ("TrialDesignPlanRates" %in% class(oc)) {
    oc$criticalValuesEffectScale |> as.numeric()
  } else {
    oc$bound$`~hr at bound`
  }
}

#' Extract nominal p-value thresholds from OC object
#' @param oc Operating characteristics object
#' @return Vector of nominal p-values
get_nominal_p <- function(oc) {
  if ("TrialDesignPlanRates" %in% class(oc)) {
    oc$criticalValuesPValueScale |> as.numeric()
  } else {
    oc$bound$`nominal p`
  }
}

#' Extract nominal cum alpha-spending from OC object
#' @param oc Operating characteristics object
#' @return Vector of cumulative alpha spent
get_cum_alpha_spend <- function(oc) {
  if ("TrialDesignPlanRates" %in% class(oc)) {
    oc$.design$alphaSpent
  } else {
    par <- oc$input$upar
    par$sf(alpha = par$total_spend, t = oc$analysis$info_frac0, param = par$param)$spend
  }
}

#' Get description of effect size
#' @param oc Operating characteristics object
#' @return Character string describing effect size
get_description_effect_size <- function(oc) {
  if ("TrialDesignPlanRates" %in% class(oc)) {
    paste0("Delta = ", round(100*(oc$pi1 - oc$pi2), 1), "%")
  } else {
    paste(`if`(dplyr::n_distinct(oc$fail_rate$hr) == 1, "HR =", "AHR ="),
          oc$analysis$ahr |> utils::tail(1) |> round(3))
  }
}

#' Get description of maximal information level
#' @param dist_type Distribution type
#' @param max_information_factor Maximum information factor
#' @param digits Number of digits for rounding
#' @return Character string describing max information
get_description_max_info <- function(dist_type, max_information_factor, digits = 0) {
  paste(round(max_information_factor, digits=digits),
        `if`(dist_type == "bin", "outcomes", "events"))
}

#' Get description of spending function
#' @param sf Spending function
#' @param sfpar Spending function parameter
#' @param nominal Nominal spend information
#' @return Character string describing spending function
#' @export
get_description_sf <- function(sf, sfpar, nominal) {
  sf_str <- dplyr::case_match(
    sf,
    "none"   ~ "N/A",
    "asHSD"  ~ `if`(is.null(sfpar), "missing parameter", glue::glue("HSD({sfpar})")),
    "asKD"   ~ `if`(is.null(sfpar), "missing parameter", glue::glue("KDM({sfpar})")),
    "asOF"   ~ "LD-OF",
    "asP"    ~ "LD-Pocock",
    "asUser" ~ `if`(is.null(sfpar), "", paste("Bespoke; cum. spend = (",
                     glue::glue_collapse(sfpar, sep = ", "), ")"))
  )
  if (!is.null(nominal)) {
    if (length(nominal) == 1) {
      glue::glue("{sf_str}, with a nominal spend of {glue::glue_collapse(nominal, ', ')} at IA1")
    } else {
      glue::glue("{sf_str}, with nominal spends of {glue::glue_collapse(nominal, ', ')} at IA1-{length(nominal)}")
    }
  } else {
    sf_str
  }
}

#' Get short description of analysis trigger
#' @param endpoint Endpoint name
#' @param sample_size Sample size
#' @param events Number of events
#' @return Short description string
get_description_trigger_short <- function(endpoint, sample_size, events) {
  `if`(!is.na(sample_size),
       glue::glue("{sample_size} {endpoint} outcomes"),
       glue::glue("{events} {endpoint} events"))
}

#' Get long description of analysis trigger
#' @param endpoint Endpoint name
#' @param strata Strata
#' @param treatments Treatments
#' @param sample_size Sample size
#' @param events Number of events
#' @param description_short Short description
#' @param distribution Distribution object
#' @return Long description string
get_description_trigger_long <- function(endpoint, strata, treatments, sample_size, events, description_short, distribution) {
  strata_str <- `if`(
    length(strata) == length(unique(distribution$stratum)),
    "FAS",
    paste(glue::glue_collapse(strata, sep = ", ", last = " and "), "strata")
  )
  treatment_str <- `if`(
    length(treatments) == length(unique(distribution$treatment)),
    "all",
    paste("the", glue::glue_collapse(treatments, sep = ", ", last = " and "))
  )
  glue::glue("{description_short} in the {strata_str} across {treatment_str} treatment arms")
}

#' Calculate pooled rate across strata
#' @param enroll_rate Enrollment rate data
#' @param distribution Distribution data
#' @return Pooled rate
get_pooled_rate <- function(enroll_rate, distribution) {
  strata_vec <- unique(enroll_rate$stratum)
  tibble::tibble(
    stratum     = strata_vec,
    rate        = purrr::map_dbl(
      strata_vec,
      \(st) dplyr::filter(distribution, .data$stratum == st) |> dplyr::pull(.data$rate)
    ),
    sample_size = purrr::map_dbl(
      strata_vec,
      \(st) dplyr::filter(enroll_rate, .data$stratum == st) %>%
        {.$rate * .$duration} |>
        sum()
    )
  ) %>%
    {sum(.$rate*.$sample_size)/(sum(.$sample_size))}
}

#' Expected sample size at specific time
#' @param t Time point of interest
#' @param maturity_time Endpoint maturity time
#' @param enroll_rate Enrollment information
#' @return Expected sample size
expected_n_at_t <- function(t = 10, maturity_time = 6, enroll_rate = gsDesign2::define_enroll_rate(duration = 10, rate = 10)) {
  enroll_rate |>
    dplyr::summarise(duration = sum(.data$duration), .by = "stratum") |>
    dplyr::pull(.data$duration) |>
    max() ->
    lpr
  if (t <= maturity_time) {
    0
  } else if (t >= lpr + maturity_time) {
    sum(enroll_rate$duration*enroll_rate$rate)
  } else {
    gsDesign2::expected_accrual(time = t - maturity_time, enroll_rate = enroll_rate)
  }
}
expected_n_at_t <- Vectorize(expected_n_at_t, "t")

#' Expected time for specific sample size
#' @param n Sample size of interest
#' @param maturity_time Endpoint maturity time
#' @param enroll_rate Enrollment information
#' @return Expected time
expected_t_at_n <- function(n = 100, maturity_time = 6, enroll_rate = gsDesign2::define_enroll_rate(duration = 10, rate = 10)) {
  if (n > sum(enroll_rate$duration*enroll_rate$rate)) return(NA)
  enroll_rate |>
    dplyr::summarise(duration = sum(.data$duration), .by = "stratum") |>
    dplyr::pull(.data$duration) |>
    max() ->
    lpr
  if (n == sum(enroll_rate$duration*enroll_rate$rate)) return(lpr + maturity_time)
  stats::uniroot(
    f = function(t, n, enroll_rate) gsDesign2::expected_accrual(t, enroll_rate) - n,
    lower = 1e-6,
    upper = lpr,
    n = n,
    enroll_rate = enroll_rate
  )$root + maturity_time
}

#' Expected events at specific time
#' @param t Time point of interest
#' @param fail_rate Failure rate information
#' @param enroll_rate Enrollment information
#' @return Expected events
expected_d_at_t <- function(t = 10, fail_rate, enroll_rate) {
  if (t <= 0) return(0)
  stratum <- unique(fail_rate$stratum)
  d <- 0
  for (st in stratum) {
    d <- d + gsDesign2::expected_event(
      enroll_rate = dplyr::filter(enroll_rate, .data$stratum == st),
      fail_rate = dplyr::filter(fail_rate, .data$stratum == st),
      total_duration = t)
  }
  d
}
expected_d_at_t <- Vectorize(expected_d_at_t, "t")

#' Expected time for specific number of events
#' @param d Events of interest
#' @param fail_rate Failure rate information
#' @param enroll_rate Enrollment information
#' @param interval Interval for root finding
#' @return Expected time
expected_t_at_d <- function(d = 20, fail_rate, enroll_rate, interval = c(1e-3, 1e6)) {
  stats::uniroot(
    f = function(t, d, fail_rate, enroll_rate) expected_d_at_t(t, fail_rate, enroll_rate) - d,
    lower = interval[1],
    upper = interval[2],
    d = d,
    fail_rate = fail_rate,
    enroll_rate = enroll_rate
  )$root
}

#' Get all possible weights for each endpoint in graphical testing procedure
#' @param graph Graph object
#' @param digits Number of digits for rounding
#' @param and_symbol Symbol for joining
#' @return Data frame of weights and scenarios
#' @export
get_weights <- function(graph, digits = 6, and_symbol = ", ") {
  G <- gMCPLite::matrix2graph(m = graph$g, weights = graph$w)
  form_rej_str <- function(x) {
    sapply(
      x, function(y) `if`(
        all(y == 1), "Initial allocation",
        paste0("Successful ", paste("H", which(y == 0), collapse = and_symbol, sep = ""))
      )
    ) |>
      paste(collapse = " or ")
  }
  K <- length(gMCPLite::getNodes(G))
  W <- gMCPLite::generateWeights(G)
  tibble::tibble(Hint = apply(W[, 1:K], 1, c, simplify = FALSE),
                 as.data.frame(W[, -(1:K)])) |>
    dplyr::mutate(mj = purrr::map_dbl(.data$Hint, sum)) |>
    tidyr::pivot_longer(-c("Hint", "mj"), names_to = "index", values_to = "possible_weight") |>
    dplyr::mutate(possible_weight = round(.data$possible_weight, digits)) |>
    dplyr::filter(.data$possible_weight > 0) |>
    dplyr::group_by(.data$index, .data$possible_weight) |>
    dplyr::reframe(max_mj = max(.data$mj), mj = .data$mj, Hint = .data$Hint) |>
    dplyr::group_by(.data$index, .data$possible_weight) |>
    dplyr::filter(.data$mj == .data$max_mj) |>
    dplyr::reframe(listHj = list(.data$Hint)) |>
    dplyr::group_by(.data$index) |>
    dplyr::mutate(scenario = purrr::map_chr(.data$listHj, form_rej_str)) |>
    dplyr::select("index", "possible_weight", "scenario") |>
    dplyr::mutate(index = as.numeric(gsub(".*?([0-9]+).*", "\\1", .data$index))) |>
    dplyr::ungroup()
}

get_info_bin <- function(control, test, enroll_rate, maturity_time,
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
    1/(control_pooled_rate*(1 - control_pooled_rate)/n1 +
         test_pooled_rate*(1 - test_pooled_rate)/n2)
  } else if (method == "pooled_proportions") {
    piP <- 0.5*(control_pooled_rate + test_pooled_rate)
    1/(piP*(1 - piP)*(1/n1 + 1/n2))
  }
}

get_info_tite <- function(control, test, enroll_rate, fail_rate,
                          times_analysed) {
  fail_rate_wide   = tidyr::pivot_wider(fail_rate,
                                        names_from  = "treatment",
                                        values_from = "fail_rate",
                                        id_cols     = c("stratum", "duration",
                                                        "dropout_rate"),
                                        values_fn = list) |>
    tidyr::unnest_longer(-("stratum":"dropout_rate")) %>%
    {tibble::tibble(duration     = .$duration,
                    fail_rate    = .[[control]],
                    dropout_rate = .$dropout_rate,
                    hr           = .[[test]]/.[[control]],
                    stratum      = .$stratum)}
  gsDesign2::ahr(
    enroll_rate |>
      dplyr::group_by(.data$rate, .data$duration) |>
      dplyr::mutate(rate = sum(.data$arm_rate)) |>
      dplyr::slice_head(n = 1),
    fail_rate_wide,
    times_analysed,
    dplyr::filter(enroll_rate, .data$treatments == test)$ratio[1]/
      dplyr::filter(enroll_rate, .data$treatments == control)$ratio[1]
  )$info
}
