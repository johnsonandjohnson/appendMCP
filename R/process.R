# Main analysis functions for group sequential design

#' Combine time-to-event and binary endpoint distributions
#' @param distribution_tte Time-to-event distribution data
#' @param distribution_bin Binary distribution data (can be NULL for TTE-only studies)
#' @return Combined distribution data frame
#' @export
process_distribution <- function(distribution_tte, distribution_bin) {
  required_cols <- c("endpoint", "stratum", "treatment")
  missing_cols <- setdiff(required_cols, names(distribution_tte))
  if (length(missing_cols) > 0) {
    stop("distribution_tte must contain columns: ", paste(missing_cols, collapse = ", "))
  }
  distribution_tte <- dplyr::mutate(distribution_tte,
                                    dist_type = "tte",
                                    .before   = all_of("endpoint"))

  # Handle case where distribution_bin is NULL (TTE-only studies)
  if (is.null(distribution_bin)) {
    distribution_tte |>
      dplyr::mutate(
        stratum_treatment = paste(.data$stratum, .data$treatment, sep = "-")
      )
  } else if (nrow(distribution_bin) == 0) {
    distribution_tte |>
      dplyr::mutate(
        stratum_treatment = paste(.data$stratum, .data$treatment, sep = "-")
      )
  } else {
    distribution_bin <- dplyr::mutate(distribution_bin,
                                      dist_type = "bin",
                                      .before   = all_of("endpoint"))
    dplyr::bind_rows(distribution_tte, distribution_bin) |>
      dplyr::mutate(
        stratum_treatment = paste(.data$stratum, .data$treatment, sep = "-")
      )
  }
}

#' Process enroll_rate
#' @param enroll_rate Configuration object
#' @return Updated enroll_rate
#' @export
process_enroll_rate <- function(enroll_rate) {
  enroll_rate |>
    dplyr::mutate(
      proportion = purrr::map(.data$ratio, \(r) r/sum(r)),
      arm_rate   = purrr::map2(.data$rate, .data$proportion, \(r, p) r*p),
      index      = seq_len(dplyr::n())
    )
}

#' Process analyses with timing information
#'
#' Transforms the input analyses data frame by appending computed columns:
#' - index: Sequential row numbers for analysis identification
#' - dist_type: Distribution type ("tte" or "bin") matched from distribution data
#' - hypotheses_analysed: List of hypothesis indices that use each analysis
#' - maturity_time: Time point for binary endpoint maturity
#' - enroll_rate: Nested enrollment rates filtered by strata/treatments
#' - distribution: Nested distribution parameters filtered by endpoint/strata/treatments
#' - time: Expected analysis timing (sample size or events driven)
#' - description_trigger_short/long: Human-readable analysis trigger descriptions
#'
#' @param analyses Analysis specifications
#' @param enroll_rate Enrollment rate data
#' @param distribution Distribution data
#' @param hypotheses Hypothesis specifications
#' @return Processed analyses data frame with 8 additional computed columns
process_analyses_1 <- function(analyses, enroll_rate, distribution, hypotheses) {
  # Step 1: Add analysis indexing and distribution type lookup
  analyses |>
    dplyr::mutate(
      index = seq_len(nrow(analyses)),  # Sequential analysis IDs
      dist_type = purrr::map_chr(  # Match endpoint to distribution type
        .data$endpoint,
        \(en) dplyr::filter(distribution, .data$endpoint == en) |>
          dplyr::pull(.data$dist_type) %>% .[1]
      ),
      .before = all_of("endpoint")
    ) |>
    # Step 2: Add hypothesis linkages and timing calculations
    dplyr::mutate(
      # Which hypotheses use this analysis (reverse lookup)
      hypotheses_analysed = purrr::map(
        .data$index, \(i) which(sapply(hypotheses$analyses_analysed,
                                 function(x) i %in% x))
      ),
      # Binary endpoint maturity time
      maturity_time = purrr::map_dbl(
        .data$endpoint, \(en) {
          dist_data <- dplyr::filter(distribution, .data$endpoint == en)
          if ("maturity_time" %in% names(dist_data) && nrow(dist_data) > 0) {
            dplyr::pull(dist_data, .data$maturity_time)[1]
          } else {
            NA_real_
          }
        }
      ),
      # Subset enrollment rates to analysis-specific strata/treatments
      enroll_rate = purrr::pmap(
        list(.data$strata, .data$treatments),
        \(st, tr) enroll_rate |>
          tidyr::unnest(c("treatments", "ratio", "proportion", "arm_rate")) |>
          dplyr::filter(.data$stratum %in% st & .data$treatments %in% tr) |>
          dplyr::mutate(stratum_treatment = paste(.data$stratum, .data$treatments, sep = "-"))
      ),
      # Subset distribution parameters to analysis-specific combinations
      distribution = purrr::pmap(
        list(.data$dist_type, .data$endpoint, .data$strata, .data$treatments),
        \(ty, en, st, tr) {
          filtered_dist <- dplyr::filter(distribution,
                                        .data$endpoint == en & .data$stratum %in% st &
                                          .data$treatment %in% tr) |>
            dplyr::select(-c("dist_type", "endpoint"))

          if (ty == "bin") {
            # Remove TTE-specific columns if they exist
            tte_cols <- c("duration", "fail_rate", "dropout_rate")
            existing_tte_cols <- intersect(tte_cols, names(filtered_dist))
            if (length(existing_tte_cols) > 0) {
              filtered_dist <- dplyr::select(filtered_dist, -all_of(existing_tte_cols))
            }
          } else {
            # Remove binary-specific columns if they exist
            bin_cols <- c("rate", "maturity_time")
            existing_bin_cols <- intersect(bin_cols, names(filtered_dist))
            if (length(existing_bin_cols) > 0) {
              filtered_dist <- dplyr::select(filtered_dist, -all_of(existing_bin_cols))
            }
          }
          filtered_dist
        }
      ),
      # Calculate expected analysis timing
      time = purrr::pmap_dbl(
        list(.data$dist_type, .data$sample_size, .data$events,
             .data$maturity_time, .data$enroll_rate, .data$distribution),
        \(ty, sa, ev, ma, en, di) `if`(
          ty == "bin",
          expected_t_at_n(sa, ma, dplyr::mutate(en, stratum = .data$stratum_treatment, rate = .data$arm_rate)),
          expected_t_at_d(ev, dplyr::mutate(di, stratum = .data$stratum_treatment),
                          dplyr::mutate(en, stratum = .data$stratum_treatment, rate = .data$arm_rate))
        )
      ),
      # Generate analysis trigger descriptions
      description_trigger_short = purrr::pmap_chr(
        list(.data$endpoint, .data$sample_size, .data$events),
        \(en, sa, ev) get_description_trigger_short(en, sa, ev)
      ),
      description_trigger_long = purrr::pmap_chr(
        list(.data$dist_type, .data$endpoint, .data$strata, .data$treatments, .data$sample_size, .data$events, .data$description_trigger_short),
        \(ty, en, st, tr, sa, ev, de)
          get_description_trigger_long(en, st, tr, sa, ev, de, !!distribution)
      )
    )
}

#' Process analyses with hypothesis information
#'
#' Appends hypothesis-specific information to analyses by adding:
#' - hypotheses_information_fractions: Information fractions for each hypothesis at this analysis
#' - hypotheses_information: Absolute information levels (fractions × max information)
#'
#' @param analyses Processed analyses from process_analyses_1
#' @param hypotheses Processed hypotheses
#' @return Final processed analyses data frame with 2 additional hypothesis-linked columns
process_analyses_2 <- function(analyses, hypotheses) {
  # Get first row per hypothesis to avoid weight scenario duplicates
  hypotheses |>
    dplyr::group_by(.data$index) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup() ->
    hypotheses_first
  # Append hypothesis information to each analysis
  analyses |>
    dplyr::mutate(
      # Extract information fractions for hypotheses using this analysis
      hypotheses_information_fractions = purrr::map2(
        .data$index, .data$hypotheses_analysed,
        \(i, hyp) sapply(hyp, \(x) {
          pos <- which(hypotheses_first$analyses_analysed[[x]] == i)
          hypotheses_first$information_fractions[[x]][pos]
        })
      ),
      # Get maximum information factors for linked hypotheses
      hypotheses_max_information = purrr::map(
        .data$hypotheses_analysed,
        \(hyp) sapply(hyp, \(x) hypotheses_first$max_information_factor[x])
      ),
      # Calculate absolute information levels (fraction × maximum)
      hypotheses_information = purrr::map2(
        .data$hypotheses_information_fractions, .data$hypotheses_max_information,
        \(x, y) x*y
      ),
      .after = "hypotheses_analysed"
    ) |>
    dplyr::select(-"hypotheses_max_information")  # Remove intermediate column
}

#' Process hypotheses with boundary specifications
#'
#' Transforms hypotheses data frame by appending computed columns:
#' - index, dist_type: Basic indexing and distribution type lookup
#' - treatments: Combined control/test treatment vectors
#' - sfpar, nominal: Spending function parameters (if missing)
#' - description_sf, description_max_info: Human-readable descriptions
#' - enroll_rate, distribution: Nested data filtered to hypothesis-specific combinations
#' - maturity_time: Binary endpoint timing
#' - times_analysed: Analysis timing from linked analyses
#' - information_factor, max_information_factor, information_fractions: GSD information calculations
#' - weights: Weight scenarios (unnested, creating multiple rows per hypothesis)
#' - control_pooled_rate, test_pooled_rate: Pooled rates for binary endpoints
#' - specs, power, hurdles, nominal_p: Boundary specifications from GSD calculations
#' - description_effect_size: Effect size descriptions
#'
#' @param hypotheses Hypothesis specifications
#' @param analyses Processed analyses
#' @param enroll_rate Enrollment rate data
#' @param distribution Distribution data
#' @param weights Weight scenarios
#' @param alpha Type I error rate
#' @return Processed hypotheses with 18+ additional computed columns, expanded by weight scenarios
process_hypotheses <- function(hypotheses, analyses, enroll_rate, distribution, weights, alpha = 0.025) {
  # Step 1: Add basic indexing and distribution type
  hypotheses |>
    dplyr::mutate(
      index = seq_len(nrow(hypotheses)),  # Sequential hypothesis IDs
      dist_type = purrr::map_chr(  # Match endpoint to distribution type
        .data$endpoint,
        \(en) dplyr::filter(distribution, .data$endpoint == en) |>
          dplyr::pull(.data$dist_type) %>% .[1]
      ),
      .before = "endpoint"
    ) |>
    # Step 2: Add treatment combinations and ensure required columns exist
    dplyr::mutate(
      treatments = purrr::map2(.data$control, .data$test, \(co, te) c(co, te)),  # Combine control/test
      .after = "test"
    ) %>%
    # Ensure sfpar column exists (spending function parameter)
    {
      if (suppressWarnings(is.null(.$sfpar))) {
        dplyr::mutate(., sfpar = NA, .after = .data$sf)
      } else {
        .
      }
    } %>%
    # Ensure nominal column exists (nominal alpha levels)
    {
      if (suppressWarnings(is.null(.$nominal))) {
        dplyr::mutate(., nominal = NA, .after = .data$sfpar)
      } else {
        .
      }
    } |>
    # Step 3: Add descriptions and nested data structures
    dplyr::mutate(
      # Generate spending function descriptions
      description_sf = purrr::pmap_chr(
        list(.data$sf, .data$sfpar, .data$nominal),
        \(sf, sfp, nom) get_description_sf(sf, sfp, nom)
      ),
      # Subset enrollment rates to hypothesis-specific strata/treatments
      enroll_rate = purrr::pmap(
        list(.data$strata, .data$control, .data$test),
        \(st, co, te) enroll_rate |>
          tidyr::unnest(c("treatments", "ratio", "proportion", "arm_rate")) |>
          dplyr::filter(.data$stratum %in% st & .data$treatments %in% c(co, te)) |>
          dplyr::mutate(stratum_treatment = paste(.data$stratum, .data$treatments, sep = "-"))
      ),
      # Subset distribution parameters to hypothesis-specific combinations
      distribution = purrr::pmap(
        list(.data$dist_type, .data$endpoint, .data$strata, .data$control, .data$test),
        \(ty, en, st, co, te) {
          filtered_dist <- dplyr::filter(distribution,
                                        .data$endpoint == en & .data$stratum %in% st &
                                          .data$treatment %in% c(co, te)) |>
            dplyr::select(-c("dist_type", "endpoint"))

          if (ty == "bin") {
            # Remove TTE-specific columns if they exist
            tte_cols <- c("duration", "fail_rate", "dropout_rate")
            existing_tte_cols <- intersect(tte_cols, names(filtered_dist))
            if (length(existing_tte_cols) > 0) {
              filtered_dist <- dplyr::select(filtered_dist, -all_of(existing_tte_cols))
            }
          } else {
            # Remove binary-specific columns if they exist
            bin_cols <- c("rate", "maturity_time")
            existing_bin_cols <- intersect(bin_cols, names(filtered_dist))
            if (length(existing_bin_cols) > 0) {
              filtered_dist <- dplyr::select(filtered_dist, -all_of(existing_bin_cols))
            }
          }
          filtered_dist
        }
      ),
      # Extract maturity time for binary endpoints
      maturity_time = purrr::map2_dbl(
        .data$dist_type, .data$distribution,
        \(ty, di) `if`(ty == "bin", di |> dplyr::pull(.data$maturity_time) %>% .[1], NA)
      )
    ) |>
    # Step 4: Calculate information fractions and timing
    dplyr::mutate(
      # Get analysis times for this hypothesis
      times_analysed        = purrr::map(.data$analyses_analysed, \(an) analyses$time[an]),
      # Add weight scenarios for this hypothesis
      weights               = purrr::map(
        .data$index, \(i) dplyr::filter(weights, .data$index == i) |> dplyr::select(-"index")
      ),
      # Calculate pooled rates for binary endpoints
      control_pooled_rate   = purrr::pmap_dbl(
        list(.data$dist_type, .data$control, .data$enroll_rate, .data$distribution),
        \(ty, tr, en, di) `if`(
          ty == "bin",
          get_pooled_rate(dplyr::filter(en, .data$treatments %in% tr) |> dplyr::mutate(rate    = .data$arm_rate,
                                                                                       stratum = .data$stratum_treatment),
                          dplyr::filter(di, .data$treatment %in% tr) |> dplyr::mutate(stratum = .data$stratum_treatment)),
          NA
        )
      ),
      test_pooled_rate      = purrr::pmap_dbl(
        list(.data$dist_type, .data$test, .data$enroll_rate, .data$distribution),
        \(ty, tr, en, di) `if`(
          ty == "bin",
          get_pooled_rate(dplyr::filter(en, .data$treatments %in% tr) |> dplyr::mutate(rate    = .data$arm_rate,
                                                                                       stratum = .data$stratum_treatment),
                          dplyr::filter(di, .data$treatment %in% tr) |> dplyr::mutate(stratum = .data$stratum_treatment)),
          NA
        )
      ),
      # Calculate information factors at each analysis time
      information           = purrr::pmap(
        list(.data$dist_type, .data$control, .data$test, .data$enroll_rate, .data$distribution, .data$maturity_time,
             .data$times_analysed, .data$control_pooled_rate, .data$test_pooled_rate, .data$test_method),
        function(type, con, trt, en, di, mat, t, piC, piT, method) {
          if (type == "bin") {
            get_info_bin(con, trt, en, mat, t, piC, piT, method)
          } else {
            get_info_tite(con, trt, en, di, t, test_method = method)
          }
        }
      ),
      # Maximum information (final analysis)
      max_information       = purrr::map_dbl(.data$information,
                                             \(inf) utils::tail(inf, 1)),
      information_factor    = purrr::pmap(
        list(.data$dist_type, .data$enroll_rate, .data$distribution, .data$maturity_time, .data$times_analysed),
        \(ty, en, di, ma, t) `if`(
          ty == "bin",
          expected_n_at_t(t, ma, dplyr::mutate(en, stratum = .data$stratum_treatment, rate = .data$arm_rate)),
          expected_d_at_t(t, dplyr::mutate(di, stratum = .data$stratum_treatment),
                          dplyr::mutate(en, stratum = .data$stratum_treatment, rate = .data$arm_rate))
        )
      ),
      # Maximum information (final analysis)
      max_information_factor = purrr::map_dbl(.data$information_factor, \(inf) utils::tail(inf, 1)),
      # Information fractions (relative to maximum)
      information_fractions  = purrr::map2(
        .data$information_factor, .data$max_information_factor, \(inf, max_inf) inf/max_inf
      ),
    ) |>
    # Step 5: Add maximum information description
    dplyr::mutate(
      description_max_info = purrr::map2_chr(
        .data$dist_type, .data$max_information_factor,
        \(ty, ma) get_description_max_info(ty, ma)
      ),
      .after = "description_sf"
    ) |>
    # Step 6: Expand by weight scenarios (creates multiple rows per hypothesis)
    tidyr::unnest("weights") |>
    # Step 7: Calculate boundary specifications for each weight scenario
    dplyr::mutate(
      # Generate boundary specifications object
      specs = purrr::pmap(
        list(.data$dist_type, .data$control, .data$test, .data$sf, .data$sfpar, .data$nominal, .data$enroll_rate,
             .data$distribution, .data$possible_weight, .data$control_pooled_rate, .data$test_pooled_rate,
             .data$information_factor, .data$max_information_factor, .data$information_fractions, .data$times_analysed,
             .data$test_method,
             alpha = alpha),
        get_boundaries
      ),
      # Extract local power calculations
      power = purrr::map(.data$specs, \(specs) get_powers(specs)),
      # Extract hurdle values (critical boundaries)
      hurdles = purrr::map(.data$specs, \(specs) get_hurdles(specs)),
      # Extract nominal p-values
      nominal_p = purrr::map(.data$specs, \(specs) get_nominal_p(specs))
    ) |>
    # Step 8: Add effect size descriptions
    dplyr::mutate(
      description_effect_size = purrr::map_chr(
        .data$specs, \(specs) get_description_effect_size(specs)
      )
    )
}

#' Process configuration into complete GSD analysis
#'
#' Transforms raw study configuration into comprehensive group sequential design analysis
#' with graphical multiple testing procedures. Orchestrates sequential processing steps
#' to generate analysis schedules, hypothesis testing boundaries, operating characteristics,
#' and comprehensive reporting outputs.
#'
#' @param config Study configuration list with 7 required components:
#'
#' **Study Metadata:**
#' - `study_name`: Character string identifying the study
#' - `study_description`: Brief description of study design
#' - `alpha`: Overall Type I error rate (typically 0.025 for one-sided)
#'
#' **analyses:** Data frame defining analysis schedule. Each row specifies one planned
#' analysis with trigger conditions:
#' - `endpoint`: Endpoint triggering the analysis (e.g., "OS", "CR")
#' - `strata`: List of patient strata contributing to trigger
#' - `treatments`: List of treatment arms contributing to trigger
#' - `sample_size`: Target sample size for binary endpoints (NA for TTE)
#' - `events`: Target events for time-to-event endpoints (NA for binary)
#' - `power_subsets_any`: Named list of hypothesis subsets for "at least one rejection" power
#' - `power_subsets_all`: Named list of hypothesis subsets for "all rejections" power
#'
#' **hypotheses:** Data frame defining statistical hypotheses. Each row specifies one hypothesis:
#' - `type`: "Primary" or "Secondary"
#' - `endpoint`: Endpoint being tested
#' - `strata`: List of strata for this hypothesis
#' - `control`: Control treatment arm name
#' - `test`: Test treatment arm name
#' - `analyses_analysed`: Vector of analysis indices (from analyses data frame) testing this hypothesis
#' - `sf`: Spending function ("none", "asHSD", "asOF", "asP", "asKD", "asUser")
#' - `sfpar`: Spending function parameter (e.g., gamma for HSD; NULL if not applicable)
#' - `nominal`: Nominal alpha spending at interims (optional; NULL for spending function)
#' - `test_method`: Statistical test ("logrank", "stratified_logrank", "unpooled_proportions",
#'   "pooled_proportions", "cmh", or a WLR family string: "cpw(<t_star>)", "fh(<rho>,<gamma>)",
#'   "mb(<tau>,<w_max>)"). WLR families use a weighted log-rank test for power / boundary
#'   calculations and simulation. Default for TTE endpoints is "logrank".
#'
#' **enroll_rate:** Data frame specifying enrollment assumptions by stratum:
#' - `stratum`: Patient stratum identifier
#' - `treatments`: List of treatment arms for this stratum
#' - `rate`: Enrollment rate (patients per month)
#' - `duration`: Enrollment duration (months)
#' - `ratio`: Randomization ratio vector (e.g., c(1,1) for 1:1)
#'
#' **distribution_tte:** Data frame with time-to-event distribution parameters:
#' - `endpoint`: TTE endpoint name
#' - `stratum`: Patient stratum
#' - `treatment`: Treatment arm
#' - `duration`: Duration of constant hazard period (Inf = constant throughout)
#' - `fail_rate`: Hazard rate (events per month)
#' - `dropout_rate`: Dropout hazard rate (per month)
#'
#' **distribution_bin:** Data frame with binary endpoint parameters:
#' - `endpoint`: Binary endpoint name
#' - `stratum`: Patient stratum
#' - `treatment`: Treatment arm
#' - `rate`: Response rate (probability of success)
#' - `maturity_time`: Time (months) when endpoint can be evaluated
#'
#' **graph:** Graphical multiple testing procedure specification:
#' - `g`: Transition matrix (k×k for k hypotheses). Element g[i,j] = fraction of alpha
#'   from hypothesis i transferred to j when i is rejected. Diagonal = 0, row sums ≤ 1
#' - `w`: Initial weight vector (length k). Element w[i] = initial alpha allocation to
#'   hypothesis i. Sum must equal 1.0
#'
#' @return List with 22 components:
#' - `analyses`: Enriched analyses data frame (original + 11 computed columns including
#'   index, dist_type, hypotheses_analysed, time, description_trigger_short/long,
#'   hypotheses_information_fractions, hypotheses_information)
#' - `hypotheses`: Enriched hypotheses data frame (original + 18+ computed columns,
#'   expanded by weight scenarios, including information_fractions, specs, power,
#'   hurdles, nominal_p, description_effect_size)
#' - `tables`: List of 7 summary tables (table1-5: hypothesis/analysis summaries;
#'   table6a-b: operating characteristics by analysis and overall)
#' - `config`: Original configuration with processed distribution and enroll_rate
#' - `graph_figure`: ggplot object visualizing graphical testing procedure
#' - `information_figure`: ggplot showing information availability over time
#' - `alpha_spend_figure`: ggplot of alpha spending functions by hypothesis
#' - `timeline_type1_figure`: ggplot of study timeline (hypothesis-centric view)
#' - `timeline_type2_figure`: ggplot of study timeline (analysis-centric view)
#' - `bin_figure`: ggplot of binary endpoint distributions
#' - `bin_rd_figure`: ggplot of binary endpoint risk differences
#' - `tte_figure`: ggplot of time-to-event survival curves
#' - `tte_ahr_figure`: ggplot of average hazard ratio over time
#' - `tte_cumhaz_figure`: ggplot of cumulative hazard functions
#' - `tte_dropout_figure`: ggplot of dropout hazard rates
#' - `tte_dropout_probability_figure`: ggplot of dropout probabilities over time
#' - `tte_hazard_figure`: ggplot of hazard rate functions
#' - `tte_hr_figure`: ggplot of hazard ratios over time
#' - `tte_median_figure`: ggplot of median survival times
#' - `tte_quantiles_figure`: ggplot of survival quantiles
#' - `tte_weighted_figure`: ggplot of weighted survival curves
#' - `er_figure`: ggplot of enrollment rates by stratum
#' - `er_cum_figure`: ggplot of cumulative enrollment over time
#'
#' @examples
#' \dontrun{
#' # Load example configuration
#' config <- load_config_from_repository("dualEP_study")
#'
#' # Process configuration
#' results <- process_config(config)
#'
#' # Access outputs
#' print(results$tables$table1)  # Hypothesis summary
#' print(results$graph_figure)   # Graphical procedure
#' }
#'
#' @seealso
#' [load_config_from_repository()] for loading built-in configurations,
#' [create_study()] for creating new study setups,
#' [generate_report()] for creating comprehensive reports
#'
#' @export
process_config <- function(config) {
  # Step 1: Create empty distribution_bin if it doesn't exist (for TTE-only studies)
  if (is.null(config$distribution_bin)) {
    config$distribution_bin <- tibble::tibble(
      endpoint = character(0),
      stratum = character(0),
      treatment = character(0),
      rate = numeric(0),
      maturity_time = numeric(0)
    )
  }
  # Step 1: Combine TTE and binary distribution data with type indicators
  config$distribution <- process_distribution(config$distribution_tte,
                                             config$distribution_bin)
  # Step 2: Extract weight scenarios from graphical testing procedure
  weights            <- get_weights(config$graph)
  graph_figure       <- plot_graph(config$graph)

  config$enroll_rate <- process_enroll_rate(config$enroll_rate)
  # Step 3: First analyses processing - add timing and trigger information
  config$analyses    <- process_analyses_1(config$analyses, config$enroll_rate,
                                           config$distribution, config$hypotheses)
  # Step 4: Create information availability visualization
  information_figure <- plot_information(config)
  # Step 5: Process hypotheses - add lots of info including expand by weights
  config$hypotheses  <- process_hypotheses(config$hypotheses, config$analyses,
                                           config$enroll_rate, config$distribution,
                                           weights, alpha = config$alpha)
  # Step 6: Final analyses processing - link to hypothesis information
  config$analyses    <- process_analyses_2(config$analyses, config$hypotheses)
  # Step 7: Calculate OC by simulations
  sims        <- if (is.null(config$sims)) 1000L else as.integer(config$sims)
  sim_results <- exec_sims(config$analyses, config$hypotheses,
                            config$graph, method = "z", sims = sims,
                            alpha = config$alpha)
  # Step 8: Generate summary tables for reporting
  tables             <- create_summary_tables(config$analyses, config$hypotheses,
                                              config$graph, weights, sim_results,
                                              alpha = config$alpha)
  # Step 9: Create additional visualizations
  alpha_spend_figure             <- plot_spending_functions(config$hypotheses,
                                                            alpha = config$alpha)
  timeline_type1_figure          <- plot_timeline_type1(config)
  timeline_type2_figure          <- plot_timeline_type2(config$analyses)
  bin_figure                     <-
    plot_distribution_bin(config$distribution_bin)
  bin_rd_figure                  <- plot_distribution_bin_rd(config$hypotheses)
  time_grid                      <- seq(0, round(tail(config$analyses$time, 1)),
                                        0.5)
  landmark_times                 <- seq(0, round(tail(config$analyses$time, 1)),
                                        by = 12)
  tte_figure                     <- plot_distribution_tte(
    config$distribution_tte, time_grid, landmark_times
  )
  tte_ahr_figure                 <- plot_distribution_tte_ahr(
    config$hypotheses, config$enroll_rate, time_grid
  )
  tte_cumhaz_figure              <- plot_distribution_tte_cumhaz(
    config$distribution_tte, time_grid
  )
  tte_dropout_figure             <- plot_distribution_tte_dropout(
    config$distribution_tte, time_grid
  )
  tte_dropout_probability_figure <- plot_distribution_tte_dropout_probability(
    config$distribution_tte, time_grid
  )
  tte_hazard_figure              <- plot_distribution_tte_hazard(
    config$distribution_tte, time_grid
  )
  tte_hr_figure                  <- plot_distribution_tte_hr(
    config$hypotheses, time_grid
  )
  tte_median_figure              <- plot_distribution_tte_median(
    config$distribution_tte
  )
  tte_quantiles_figure           <- plot_distribution_tte_quantiles(
    config$distribution_tte
  )
  tte_weighted_figure            <- plot_distribution_tte_weighted(
    config$hypotheses, config$distribution_tte, config$enroll_rate, time_grid,
    landmark_times
  )
  er_figure                      <- plot_enroll_rate(config$enroll_rate)
  er_cum_figure                  <- plot_enroll_rate_cumulative(
    config$enroll_rate, time_grid
  )
  # Return comprehensive analysis package
  list(
    analyses           = config$analyses,
    hypotheses         = config$hypotheses,
    tables             = tables,
    config             = config,
    graph_figure       = graph_figure,
    information_figure = information_figure,
    alpha_spend_figure = alpha_spend_figure,
    timeline_type1_figure          = timeline_type1_figure,
    timeline_type2_figure          = timeline_type2_figure,
    bin_figure                     = bin_figure,
    bin_rd_figure                  = bin_rd_figure,
    tte_figure                     = tte_figure,
    tte_ahr_figure                 = tte_ahr_figure,
    tte_cumhaz_figure              = tte_cumhaz_figure,
    tte_dropout_figure             = tte_dropout_figure,
    tte_dropout_probability_figure = tte_dropout_probability_figure,
    tte_hazard_figure              = tte_hazard_figure,
    tte_hr_figure                  = tte_hr_figure,
    tte_median_figure              = tte_median_figure,
    tte_quantiles_figure           = tte_quantiles_figure,
    tte_weighted_figure            = tte_weighted_figure,
    er_figure                      = er_figure,
    er_cum_figure                  = er_cum_figure
  )
}

#' Create summary tables
#' @param analyses Processed analyses
#' @param hypotheses Processed hypotheses
#' @param graph Graph object
#' @param weights Weight scenarios
#' @param sim_results Simulation results (optional)
#' @param alpha Overall Type I error rate
#' @return List of summary tables
#' @export
create_summary_tables <- function(analyses, hypotheses, graph, weights, sim_results = NULL, alpha = 0.025) {
  # Table 1: Hypothesis summary
  # Build a lookup from hypothesis index to endpoint
  hyp_endpoint_lookup <- hypotheses |>
    dplyr::group_by(.data$index) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup()

  table1 <- hyp_endpoint_lookup %>%
    {
      tibble::tibble(
        Label = paste0("H", .$index),
        Endpoint = .$endpoint,
        Type = .$type,
        `Initial weight` = graph$w,
        `GSD spending fn` = .$description_sf,
        `Effect size` = .$description_effect_size,
        `Maximum events / sample size` = .$max_information_factor
      )
    }

  # Tables 2-3: Analysis details
  hyp_labels <- hyp_endpoint_lookup |>
    dplyr::transmute(
      hypotheses_analysed = .data$index,
      hyp_label           = paste0("H", .data$index, ": ", .data$endpoint)
    )
  tables2and3 <- analyses |>
    tidyr::unnest(c("hypotheses_analysed", "hypotheses_information_fractions", "hypotheses_information")) |>
    dplyr::left_join(hyp_labels, by = "hypotheses_analysed") %>%
    {
      tibble::tibble(
        Hypothesis = .$hyp_label,
        Analysis = .$index,
        `Criteria for conduct` = .$description_trigger_short,
        `Expected analysis time` = .$time,
        `Events / sample size` = .$hypotheses_information,
        `Information fraction` = .$hypotheses_information_fractions
      )
    }

  # Extract numeric index for proper sorting
  .hyp_num <- function(x) as.numeric(gsub("^H(\\d+).*", "\\1", x))
  table2 <- dplyr::arrange(tables2and3, .hyp_num(.data$Hypothesis))
  table3 <- dplyr::arrange(tables2and3, .data$Analysis)

  # Table 4: Weight scenarios — use lookup to map index to endpoint
  endpoint_by_index <- stats::setNames(
    hyp_endpoint_lookup$endpoint, hyp_endpoint_lookup$index
  )
  table4 <- weights |>
    dplyr::mutate(
      `Local alpha level` = alpha*.data$possible_weight,
      .after = "index"
    ) |>
    dplyr::rename(
      Hypothesis = "index",
      Weight = "possible_weight",
      `Testing scenario` = "scenario"
    ) |>
    dplyr::mutate(
      Hypothesis = paste0("H", .data$Hypothesis, ": ",
                          endpoint_by_index[as.character(.data$Hypothesis)])
    ) |>
    dplyr::arrange(.hyp_num(.data$Hypothesis))

  # Table 5: Boundaries Specs
  table5 <- hypotheses %>%
    {
      tibble::tibble(
        Hypothesis = paste("H", .$index, ": ", .$endpoint, sep = ""),
        `Local alpha level` = alpha*.$possible_weight,
        `Information fraction` = .$information_fractions,
        `Nominal p-value` = .$nominal_p,
        `Exit hurdle` = .$hurdles,
        `Local power` = .$power
      )
    } |>
    dplyr::mutate(
      Analysis = purrr::map(.data$`Information fraction`, \(x) seq_along(x)),
      .after = "Hypothesis"
    ) |>
    tidyr::unnest(c("Analysis", "Information fraction":"Local power"))

  # Table 6a: Power by analysis (tidy format)
  table6a <- if (!is.null(sim_results) && !is.null(sim_results$marginal_oc$oc_at_analyses)) {
    sim_results$marginal_oc$oc_at_analyses |>
      dplyr::rename(
        Analysis = "analysis_index",
        Metric = "metric",
        `Hypothesis subset` = "subset_name",
        Value = "value"
      ) |>
      dplyr::select("Analysis", "Metric", "Hypothesis subset", "Value") |>
      dplyr::arrange(.data$Analysis)
  } else {
    NULL
  }

  # Table 6b: Expected analysis summary (tidy format)
  table6b <- if (!is.null(sim_results) && !is.null(sim_results$marginal_oc$oc_across_analyses)) {
    sim_results$marginal_oc$oc_across_analyses |>
      dplyr::rename(
        Metric = "metric",
        `Hypothesis subset` = "subset_name",
        Value = "value"
      ) |>
      dplyr::select("Metric", "Hypothesis subset", "Value") |>
      dplyr::arrange(.data$Metric)
  } else {
    NULL
  }
  list(
    table1 = table1,
    table2 = table2,
    table3 = table3,
    table4 = table4,
    table5 = table5,
    table6a = table6a,
    table6b = table6b
  )
}
