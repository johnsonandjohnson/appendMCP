#' Check if config is a valid list with required structure
#' @param config Configuration object to validate
#' @return TRUE if valid, throws error otherwise
#' @export
check_config_by_element <- function(config) {
  # Check config is a list
  if (!is.list(config)) {
    stop("Config must be a list")
  }

  # Check optional character fields
  check_optional_character(config, "study_name")
  check_optional_character(config, "study_description")

  # Check optional date field
  check_optional_date(config, "study_fpr_date")

  # Check optional sims field
  if ("sims" %in% names(config)) {
    if (!is.numeric(config$sims) || length(config$sims) != 1 ||
        config$sims < 1 || config$sims != as.integer(config$sims)) {
      stop("sims must be a single positive integer")
    }
  }

  # Check required alpha field
  check_required_numeric_bounded(config, "alpha", 0, 1, strict = TRUE)

  # Check required data.frame fields
  check_required_dataframe(config, "analyses")
  check_required_dataframe(config, "hypotheses")
  check_required_dataframe(config, "enroll_rate")

  # Check at least one distribution is present
  check_distribution_presence(config)

  # Check graph field
  check_required_list(config, "graph")

  # Check detailed structure of each component
  check_analyses_structure(config$analyses)
  check_hypotheses_structure(config$hypotheses)
  check_enroll_rate_structure(config$enroll_rate)
  if ("distribution_tte" %in% names(config)) {
    check_distribution_tte_structure(config$distribution_tte)
  }
  if ("distribution_bin" %in% names(config)) {
    check_distribution_bin_structure(config$distribution_bin)
  }
  check_graph_structure(config$graph)
  config
}

#' Check optional character field
#' @param config Configuration list
#' @param field_name Name of field to check
check_optional_character <- function(config, field_name) {
  if (field_name %in% names(config)) {
    field_value <- config[[field_name]]
    if (!is.character(field_value) || length(field_value) != 1) {
      stop(paste(field_name, "must be a single character string"))
    }
  }
}

#' Check optional date field
#' @param config Configuration list
#' @param field_name Name of field to check
check_optional_date <- function(config, field_name) {
  if (field_name %in% names(config)) {
    field_value <- config[[field_name]]
    tryCatch({
      as.Date(field_value)
      invisible()
    }, error = function(e) {
      stop(paste(field_name, "must be a date or coercible to a date"))
    })
  }
}

#' Check required numeric field with bounds
#' @param config Configuration list
#' @param field_name Name of field to check
#' @param lower_bound Lower bound (exclusive if strict=TRUE)
#' @param upper_bound Upper bound (exclusive if strict=TRUE)
#' @param strict If TRUE, bounds are exclusive; if FALSE, inclusive
check_required_numeric_bounded <- function(config, field_name, lower_bound, upper_bound, strict = FALSE) {
  if (!field_name %in% names(config)) {
    stop(paste(field_name, "is required"))
  }
  field_value <- config[[field_name]]
  if (!is.numeric(field_value) || length(field_value) != 1) {
    stop(paste(field_name, "must be a single numeric value"))
  }

  if (strict) {
    if (field_value <= lower_bound || field_value >= upper_bound) {
      stop(paste(field_name, "must be strictly between", lower_bound, "and", upper_bound))
    }
  } else {
    if (field_value < lower_bound || field_value > upper_bound) {
      stop(paste(field_name, "must be between", lower_bound, "and", upper_bound, "(inclusive)"))
    }
  }
}

#' Check required data.frame field
#' @param config Configuration list
#' @param field_name Name of field to check
check_required_dataframe <- function(config, field_name) {
  if (!field_name %in% names(config)) {
    stop(paste(field_name, "is required"))
  }
  if (!is.data.frame(config[[field_name]])) {
    stop(paste(field_name, "must be a data.frame"))
  }
}

#' Check required list field
#' @param config Configuration list
#' @param field_name Name of field to check
check_required_list <- function(config, field_name) {
  if (!field_name %in% names(config)) {
    stop(paste(field_name, "is required"))
  }
  if (!is.list(config[[field_name]])) {
    stop(paste(field_name, "must be a list"))
  }
}

#' Check at least one distribution is present
#' @param config Configuration list
check_distribution_presence <- function(config) {
  has_tte <- "distribution_tte" %in% names(config)
  has_bin <- "distribution_bin" %in% names(config)

  if (!has_tte && !has_bin) {
    stop("At least one of distribution_tte or distribution_bin is required")
  }

  if (has_tte && !is.data.frame(config[["distribution_tte"]])) {
    stop("distribution_tte must be a data.frame")
  }

  if (has_bin && !is.data.frame(config[["distribution_bin"]])) {
    stop("distribution_bin must be a data.frame")
  }

  # Check no common endpoints between distributions
  if (has_tte && has_bin) {
    if ("endpoint" %in% names(config$distribution_tte) && "endpoint" %in% names(config$distribution_bin)) {
      tte_endpoints <- unique(config$distribution_tte$endpoint)
      bin_endpoints <- unique(config$distribution_bin$endpoint)
      common_endpoints <- intersect(tte_endpoints, bin_endpoints)
      if (length(common_endpoints) > 0) {
        stop(paste("Endpoints cannot be common between distribution_tte and distribution_bin:", paste(common_endpoints, collapse = ", ")))
      }
    }
  }
}

#' Check analyses data.frame structure
#' @param analyses Analyses data.frame
check_analyses_structure <- function(analyses) {
  allowed_cols <- c("tag", "endpoint", "strata", "treatments", "sample_size", "events", "time", "hypothesis_index", "inf_frac", "power", "alpha", "power_subsets_any", "power_subsets_all")
  check_allowed_columns(analyses, "analyses", allowed_cols)

  if ("tag" %in% names(analyses)) check_character_column(analyses, "tag")
  if ("endpoint" %in% names(analyses)) check_character_or_na_column(analyses, "endpoint")
  if ("strata" %in% names(analyses)) check_character_vector_or_na_column(analyses, "strata")
  if ("treatments" %in% names(analyses)) check_character_vector_or_na_column(analyses, "treatments")
  if ("sample_size" %in% names(analyses)) check_positive_integer_or_na_column(analyses, "sample_size")
  if ("events" %in% names(analyses)) check_positive_integer_or_na_column(analyses, "events")
  if ("time" %in% names(analyses)) check_positive_double_or_na_column(analyses, "time")
  if ("hypothesis_index" %in% names(analyses)) check_positive_integer_or_na_column(analyses, "hypothesis_index")
  if ("inf_frac" %in% names(analyses)) check_positive_double_or_na_column(analyses, "inf_frac")
  if ("power" %in% names(analyses)) check_positive_double_or_na_column(analyses, "power")
  if ("alpha" %in% names(analyses)) check_positive_double_or_na_column(analyses, "alpha")
}

#' Check hypotheses data.frame structure
#' @param hypotheses Hypotheses data.frame
check_hypotheses_structure <- function(hypotheses) {
  allowed_cols <- c("type", "endpoint", "strata", "control", "treatment", "analyses_analysed", "sf", "sfpar", "nominal", "test", "test_method")
  check_allowed_columns(hypotheses, "hypotheses", allowed_cols)

  if ("type" %in% names(hypotheses)) check_character_column(hypotheses, "type")
  if ("endpoint" %in% names(hypotheses)) check_character_column(hypotheses, "endpoint")
  if ("strata" %in% names(hypotheses)) check_character_vector_or_na_column(hypotheses, "strata")
  if ("control" %in% names(hypotheses)) check_character_column(hypotheses, "control")
  if ("treatment" %in% names(hypotheses)) check_character_column(hypotheses, "treatment")
  if ("analyses_analysed" %in% names(hypotheses)) check_positive_integer_vector_column(hypotheses, "analyses_analysed")
  if ("sf" %in% names(hypotheses)) check_character_column(hypotheses, "sf")
  if ("sfpar" %in% names(hypotheses)) check_double_or_null_column(hypotheses, "sfpar")
  if ("nominal" %in% names(hypotheses)) check_positive_double_vector_or_null_column(hypotheses, "nominal")
  if ("test" %in% names(hypotheses)) check_character_column(hypotheses, "test")
  if ("test_method" %in% names(hypotheses)) check_test_method_column(hypotheses, "test_method")
}

#' Check enroll_rate data.frame structure
#' @param enroll_rate Enroll_rate data.frame
check_enroll_rate_structure <- function(enroll_rate) {
  allowed_cols <- c("stratum", "treatments", "rate", "duration", "ratio")
  check_allowed_columns(enroll_rate, "enroll_rate", allowed_cols)

  if ("stratum" %in% names(enroll_rate)) check_character_column(enroll_rate, "stratum")
  if ("treatments" %in% names(enroll_rate)) check_character_vector_or_na_column(enroll_rate, "treatments")
  if ("rate" %in% names(enroll_rate)) check_positive_double_column(enroll_rate, "rate")
  if ("duration" %in% names(enroll_rate)) check_positive_double_column(enroll_rate, "duration")
  if ("ratio" %in% names(enroll_rate)) check_positive_double_column(enroll_rate, "ratio")
}

#' Check distribution_tte data.frame structure
#' @param distribution_tte Distribution_tte data.frame
check_distribution_tte_structure <- function(distribution_tte) {
  allowed_cols <- c("endpoint", "stratum", "treatment", "duration", "fail_rate", "dropout_rate")
  check_allowed_columns(distribution_tte, "distribution_tte", allowed_cols)

  # Treatment column is required
  if (!"treatment" %in% names(distribution_tte)) {
    stop("treatment column is required in distribution_tte")
  }

  if ("endpoint" %in% names(distribution_tte)) check_character_column(distribution_tte, "endpoint")
  if ("stratum" %in% names(distribution_tte)) check_character_column(distribution_tte, "stratum")
  check_character_column(distribution_tte, "treatment")

  # Check treatment has at least 2 unique values
  if (length(unique(distribution_tte$treatment)) < 2) {
    stop("distribution_tte treatment column must contain at least 2 unique values")
  }

  if ("duration" %in% names(distribution_tte)) check_positive_double_or_inf_column(distribution_tte, "duration")
  if ("fail_rate" %in% names(distribution_tte)) check_positive_double_column(distribution_tte, "fail_rate")
  if ("dropout_rate" %in% names(distribution_tte)) check_nonnegative_double_column(distribution_tte, "dropout_rate")
}

#' Check distribution_bin data.frame structure
#' @param distribution_bin Distribution_bin data.frame
check_distribution_bin_structure <- function(distribution_bin) {
  allowed_cols <- c("endpoint", "stratum", "treatment", "rate", "maturity_time")
  check_allowed_columns(distribution_bin, "distribution_bin", allowed_cols)

  # Treatment column is required
  if (!"treatment" %in% names(distribution_bin)) {
    stop("treatment column is required in distribution_bin")
  }

  if ("endpoint" %in% names(distribution_bin)) check_character_column(distribution_bin, "endpoint")
  if ("stratum" %in% names(distribution_bin)) check_character_column(distribution_bin, "stratum")
  check_character_column(distribution_bin, "treatment")

  # Check treatment has at least 2 unique values
  if (length(unique(distribution_bin$treatment)) < 2) {
    stop("distribution_bin treatment column must contain at least 2 unique values")
  }

  if ("rate" %in% names(distribution_bin)) check_bounded_double_column(distribution_bin, "rate", 0, 1, strict = FALSE)
  if ("maturity_time" %in% names(distribution_bin)) check_nonnegative_double_column(distribution_bin, "maturity_time")
}

#' Check graph list structure
#' @param graph Graph list
check_graph_structure <- function(graph) {
  required_items <- c("g", "w")
  for (item in required_items) {
    if (!item %in% names(graph)) {
      stop(paste("graph must contain", item))
    }
  }

  # Check g is matrix
  if (!is.matrix(graph$g) || !is.numeric(graph$g)) {
    stop("graph$g must be a numeric matrix")
  }

  # Check g dimensions and values
  if (nrow(graph$g) != ncol(graph$g)) {
    stop("graph$g must be a square matrix")
  }

  if (any(graph$g < 0 | graph$g > 1)) {
    stop("All elements of graph$g must be between 0 and 1 (inclusive)")
  }

  if (any(diag(graph$g) != 0)) {
    stop("Diagonal elements of graph$g must be zero (no self-loops)")
  }

  if (!all(rowSums(graph$g) <= 1 + 1e-10)) {
    stop("Each row of graph$g must sum to at most 1")
  }

  # Check w is numeric vector
  if (!is.numeric(graph$w) || !is.vector(graph$w)) {
    stop("graph$w must be a numeric vector")
  }

  if (any(graph$w < 0 | graph$w > 1)) {
    stop("All elements of graph$w must be between 0 and 1 (inclusive)")
  }

  if (abs(sum(graph$w) - 1) > 1e-10) {
    stop("graph$w must sum to 1")
  }

  if (length(graph$w) != nrow(graph$g)) {
    stop("Length of graph$w must match number of rows/columns of graph$g")
  }
}

# Helper functions for column validation

#' Check allowed columns
#' @param df Data.frame to check
#' @param name Name of data.frame for error messages
#' @param allowed_cols Vector of allowed column names
check_allowed_columns <- function(df, name, allowed_cols) {
  extra_cols <- setdiff(names(df), allowed_cols)
  if (length(extra_cols) > 0) {
    stop(paste(name, "contains invalid columns:", paste(extra_cols, collapse = ", ")))
  }
}

#' Check character column
#' @param df Data.frame
#' @param col_name Column name
check_character_column <- function(df, col_name) {
  if (!is.character(df[[col_name]])) {
    stop(paste(col_name, "must be character"))
  }
}

#' Check test_method column
#'
#' Validates that every non-NA value in a \code{test_method} column is either a
#' plain method name or a correctly-formed parametric WLR string.  Calls
#' \code{parse_test_method()} on each value so that bad strings (e.g.
#' \code{"cpw(bad)"}, \code{"unknown(1)"}) produce a clear error at
#' config-validation time rather than later in processing.
#'
#' @param df       Data frame containing the column.
#' @param col_name Name of the \code{test_method} column.
check_test_method_column <- function(df, col_name) {
  col <- df[[col_name]]
  if (!is.character(col)) {
    stop(col_name, " must be a character column.")
  }
  for (i in seq_along(col)) {
    val <- col[i]
    if (!is.na(val)) {
      tryCatch(
        parse_test_method(val),
        error = function(e) {
          stop("hypotheses row ", i, ": invalid test_method '", val, "': ",
               conditionMessage(e), call. = FALSE)
        }
      )
    }
  }
}

#' Check character or NA column
#' @param df Data.frame
#' @param col_name Column name
check_character_or_na_column <- function(df, col_name) {
  col <- df[[col_name]]
  if (!all(is.character(col) | is.na(col))) {
    stop(paste(col_name, "must be character or NA"))
  }
}

#' Check character vector or NA column (list column)
#' @param df Data.frame
#' @param col_name Column name
check_character_vector_or_na_column <- function(df, col_name) {
  col <- df[[col_name]]
  if (is.list(col)) {
    for (i in seq_along(col)) {
      if (!(length(col[[i]]) == 1 && is.na(col[[i]])) && !is.character(col[[i]])) {
        stop(paste(col_name, "must contain character vectors or NA"))
      }
    }
  } else {
    stop(paste(col_name, "must be a list column containing character vectors or NA"))
  }
}

#' Check positive integer or NA column
#' @param df Data.frame
#' @param col_name Column name
check_positive_integer_or_na_column <- function(df, col_name) {
  col <- df[[col_name]]
  if (!all(is.na(col) | (is.numeric(col) & col > 0 & col == as.integer(col)))) {
    stop(paste(col_name, "must contain strictly positive integers or NA"))
  }
}

#' Check positive double or NA column
#' @param df Data.frame
#' @param col_name Column name
check_positive_double_or_na_column <- function(df, col_name) {
  col <- df[[col_name]]
  if (!all(is.na(col) | (is.numeric(col) & col > 0))) {
    stop(paste(col_name, "must contain strictly positive doubles or NA"))
  }
}

#' Check positive integer vector column (list column)
#' @param df Data.frame
#' @param col_name Column name
check_positive_integer_vector_column <- function(df, col_name) {
  col <- df[[col_name]]
  if (is.list(col)) {
    for (i in seq_along(col)) {
      if (!is.numeric(col[[i]]) || !all(col[[i]] > 0 & col[[i]] == as.integer(col[[i]]))) {
        stop(paste(col_name, "must contain vectors of strictly positive integers"))
      }
    }
  } else {
    stop(paste(col_name, "must be a list column containing vectors of strictly positive integers"))
  }
}

#' Check positive double column
#' @param df Data.frame
#' @param col_name Column name
check_positive_double_column <- function(df, col_name) {
  col <- df[[col_name]]
  if (!is.numeric(col) || !all(col > 0)) {
    stop(paste(col_name, "must contain strictly positive doubles"))
  }
}

#' Check positive double or Inf column
#' @param df Data.frame
#' @param col_name Column name
check_positive_double_or_inf_column <- function(df, col_name) {
  col <- df[[col_name]]
  if (!is.numeric(col) || !all(col > 0 | is.infinite(col))) {
    stop(paste(col_name, "must contain strictly positive doubles or Inf"))
  }
}

#' Check non-negative double column
#' @param df Data.frame
#' @param col_name Column name
check_nonnegative_double_column <- function(df, col_name) {
  col <- df[[col_name]]
  if (!is.numeric(col) || !all(col >= 0)) {
    stop(paste(col_name, "must contain non-negative doubles"))
  }
}

#' Check bounded double column
#' @param df Data.frame
#' @param col_name Column name
#' @param lower_bound Lower bound
#' @param upper_bound Upper bound
#' @param strict If TRUE, bounds are exclusive
check_bounded_double_column <- function(df, col_name, lower_bound, upper_bound, strict = FALSE) {
  col <- df[[col_name]]
  if (!is.numeric(col)) {
    stop(paste(col_name, "must be numeric"))
  }

  if (strict) {
    if (!all(col > lower_bound & col < upper_bound)) {
      stop(paste(col_name, "must be strictly between", lower_bound, "and", upper_bound))
    }
  } else {
    if (!all(col >= lower_bound & col <= upper_bound)) {
      stop(paste(col_name, "must be between", lower_bound, "and", upper_bound, "(inclusive)"))
    }
  }
}

#' Check double or NULL column
#' @param df Data.frame
#' @param col_name Column name
check_double_or_null_column <- function(df, col_name) {
  col <- df[[col_name]]
  if (is.list(col)) {
    for (i in seq_along(col)) {
      if (!is.null(col[[i]]) && !is.numeric(col[[i]])) {
        stop(paste(col_name, "must contain doubles or NULL"))
      }
    }
  } else {
    if (!all(is.numeric(col) | is.null(col))) {
      stop(paste(col_name, "must contain doubles or NULL"))
    }
  }
}

#' Check positive double vector or NULL column (list column)
#' @param df Data.frame
#' @param col_name Column name
check_positive_double_vector_or_null_column <- function(df, col_name) {
  col <- df[[col_name]]
  if (is.list(col)) {
    for (i in seq_along(col)) {
      if (!is.null(col[[i]]) && (!is.numeric(col[[i]]) || !all(col[[i]] > 0))) {
        stop(paste(col_name, "must contain vectors of strictly positive doubles or NULL"))
      }
    }
  } else {
    stop(paste(col_name, "must be a list column containing vectors of strictly positive doubles or NULL"))
  }
}
#' Check dependencies between config components
#' @param config Configuration list
check_config_dependencies <- function(config) {
  check_analyses_dependencies(config)
  check_hypotheses_dependencies(config)
  check_enroll_rate_dependencies(config)
  check_graph_dependencies(config)
  config
}

#' Check analyses dependencies
#' @param config Full config for cross-references
check_analyses_dependencies <- function(config) {
  analyses <- config$analyses
  for (i in seq_len(nrow(analyses))) {
    row <- analyses[i, ]

    # Check only one of sample_size, events, time, hypothesis_index is given
    non_na_count <- sum(!is.na(c(row$sample_size, row$events, row$time, row$hypothesis_index)))
    if (non_na_count != 1) {
      stop(paste("Row", i, "in analyses: exactly one of sample_size, events, time, hypothesis_index must be specified"))
    }

    # Check hypothesis_index requirements
    if (!is.na(row$hypothesis_index)) {
      # Validate hypothesis_index range
      if (row$hypothesis_index < 1 || row$hypothesis_index > nrow(config$hypotheses)) {
        stop(paste("Row", i, "in analyses: hypothesis_index must be between 1 and", nrow(config$hypotheses)))
      }

      # Check inf_frac or (power and alpha) are specified
      has_inf_frac <- !is.na(row$inf_frac)
      has_power_alpha <- !is.na(row$power) && !is.na(row$alpha)

      if (!has_inf_frac && !has_power_alpha) {
        stop(paste("Row", i, "in analyses: when hypothesis_index is specified, either inf_frac or both power and alpha must be specified"))
      }

      if (has_inf_frac && has_power_alpha) {
        stop(paste("Row", i, "in analyses: cannot specify both inf_frac and power/alpha together"))
      }

      # Get analyses for this hypothesis
      hyp_analyses <- config$hypotheses$analyses_analysed[[row$hypothesis_index]]

      if (has_inf_frac) {
        # Check inf_frac bounds
        if (row$inf_frac <= 0 || row$inf_frac >= 100) {
          stop(paste("Row", i, "in analyses: inf_frac must be strictly between 0 and 100"))
        }

        # Check this is not the final analysis
        if (i == max(hyp_analyses)) {
          stop(paste("Row", i, "in analyses: inf_frac cannot be used for the final analysis of hypothesis", row$hypothesis_index))
        }
      }

      if (has_power_alpha) {
        # Check power and alpha bounds
        if (row$power <= 0 || row$power >= 100) {
          stop(paste("Row", i, "in analyses: power must be strictly between 0 and 100"))
        }
        if (row$alpha <= 0 || row$alpha >= 1) {
          stop(paste("Row", i, "in analyses: alpha must be strictly between 0 and 1"))
        }

        # Check this is the final analysis
        if (i != max(hyp_analyses)) {
          stop(paste("Row", i, "in analyses: power and alpha can only be used for the final analysis of hypothesis", row$hypothesis_index))
        }
      }

      # When hypothesis_index is specified, endpoint, strata, treatments must be NA
      if (!is.na(row$endpoint) || !all(is.na(row$strata[[1]])) || !all(is.na(row$treatments[[1]]))) {
        stop(paste("Row", i, "in analyses: when hypothesis_index is given, endpoint, strata, treatments must be NA"))
      }
    }

    # Check time row requirements
    if (!is.na(row$time)) {
      if (!is.na(row$endpoint) || !all(is.na(row$strata[[1]])) || !all(is.na(row$treatments[[1]]))) {
        stop(paste("Row", i, "in analyses: when time is given, endpoint, strata, treatments must be NA"))
      }
    }

    # Check sample_size/events row requirements
    if (!is.na(row$sample_size) || !is.na(row$events)) {
      if (is.na(row$endpoint) || any(is.na(row$strata[[1]])) || any(is.na(row$treatments[[1]]))) {
        stop(paste("Row", i, "in analyses: when sample_size or events given, endpoint, strata, treatments must be present"))
      }

      # Check distribution presence
      if (!is.na(row$events)) {
        check_distribution_combinations(row$endpoint, row$strata[[1]], row$treatments[[1]],
                                        config$distribution_tte, NULL, "events", i)
      } else {
        check_distribution_combinations(row$endpoint, row$strata[[1]], row$treatments[[1]],
                                        config$distribution_tte, config$distribution_bin, "sample_size", i)
      }
    }
  }
}

#' Check hypotheses dependencies
#' @param config Full config for cross-references
check_hypotheses_dependencies <- function(config) {
  hypotheses <- config$hypotheses

  # Check all analysis indices are referenced
  all_analyses_referenced <- unique(unlist(hypotheses$analyses_analysed))
  expected_analyses <- seq_len(nrow(config$analyses))
  missing_analyses <- setdiff(expected_analyses, all_analyses_referenced)
  if (length(missing_analyses) > 0) {
    stop(paste("All analyses must be referenced in hypotheses. Missing:", paste(missing_analyses, collapse = ", ")))
  }

  for (i in seq_len(nrow(hypotheses))) {
    row <- hypotheses[i, ]

    # Check type values
    if (!row$type %in% c("Primary", "Secondary")) {
      stop(paste("Row", i, "in hypotheses: type must be 'Primary' or 'Secondary'"))
    }

    # Check distribution presence for control and treatment
    check_distribution_combinations(row$endpoint, row$strata[[1]], row$control,
                                    config$distribution_tte, config$distribution_bin, "control", i)
    check_distribution_combinations(row$endpoint, row$strata[[1]], row$treatment,
                                    config$distribution_tte, config$distribution_bin, "treatment", i)

    # Check analyses_analysed values
    analyses_analysed <- row$analyses_analysed[[1]]
    n_analyses <- nrow(config$analyses)
    if (!all(analyses_analysed >= 1 & analyses_analysed <= n_analyses)) {
      stop(paste("Row", i, "in hypotheses: analyses_analysed must be between 1 and", n_analyses))
    }
    if (length(unique(analyses_analysed)) != length(analyses_analysed)) {
      stop(paste("Row", i, "in hypotheses: analyses_analysed cannot have duplicates"))
    }
    if (!identical(analyses_analysed, sort(analyses_analysed))) {
      stop(paste("Row", i, "in hypotheses: analyses_analysed must be in ascending order"))
    }

    # Check sf and sfpar
    sfpar_value <- if (is.list(row$sfpar)) row$sfpar[[1]] else row$sfpar
    check_sf_sfpar(row$sf, sfpar_value, length(analyses_analysed), config$alpha, i)

    # Check nominal
    if (!is.null(row$nominal[[1]])) {
      nominal <- row$nominal[[1]]
      if (!all(nominal > 0 & nominal <= config$alpha)) {
        stop(paste("Row", i, "in hypotheses: nominal values must be in (0, alpha]"))
      }
      if (sum(nominal) > config$alpha) {
        stop(paste("Row", i, "in hypotheses: nominal values must sum to <= alpha"))
      }
      if (length(nominal) > length(analyses_analysed)) {
        stop(paste("Row", i, "in hypotheses: nominal length must be <= analyses_analysed length"))
      }
    }
  }
}

#' Check enroll_rate dependencies
#' @param config Full config
check_enroll_rate_dependencies <- function(config) {
  # Get all combinations from hypotheses
  hyp_combinations <- get_hypothesis_combinations(config$hypotheses)

  # Get enroll_rate combinations (unnested treatments)
  enroll_combinations <- get_enroll_rate_combinations(config$enroll_rate)

  # Check all hypothesis combinations are in enroll_rate
  missing <- setdiff(hyp_combinations, enroll_combinations)
  if (length(missing) > 0) {
    stop("Missing combinations in enroll_rate: ", paste(missing, collapse = ", "))
  }
}

#' Check graph dependencies
#' @param config Full config
check_graph_dependencies <- function(config) {
  n_hypotheses <- nrow(config$hypotheses)
  if (length(config$graph$w) != n_hypotheses) {
    stop(paste("Length of graph$w (", length(config$graph$w), ") must match number of hypotheses (", n_hypotheses, ")"))
  }
}

# Helper functions

#' Check distribution combinations exist
#' @param endpoint Endpoint name
#' @param strata Strata vector
#' @param treatments Treatments vector
#' @param dist_tte TTE distribution data.frame
#' @param dist_bin Binary distribution data.frame
#' @param field_name Field name for error messages
#' @param row_num Row number for error messages
check_distribution_combinations <- function(endpoint, strata, treatments, dist_tte, dist_bin, field_name, row_num) {
  combinations <- expand.grid(endpoint = endpoint, stratum = strata, treatment = treatments, stringsAsFactors = FALSE)

  # Check in distribution_tte
  found_tte <- FALSE
  if (!is.null(dist_tte)) {
    tte_combinations <- paste(dist_tte$endpoint, dist_tte$stratum, dist_tte$treatment)
    check_combinations <- paste(combinations$endpoint, combinations$stratum, combinations$treatment)
    found_tte <- all(check_combinations %in% tte_combinations)
  }

  # Check in distribution_bin
  found_bin <- FALSE
  if (!is.null(dist_bin)) {
    bin_combinations <- paste(dist_bin$endpoint, dist_bin$stratum, dist_bin$treatment)
    check_combinations <- paste(combinations$endpoint, combinations$stratum, combinations$treatment)
    found_bin <- all(check_combinations %in% bin_combinations)
  }

  if (field_name == "events" && !found_tte) {
    stop(paste("Row", row_num, ": events requires all combinations in distribution_tte"))
  } else if (field_name %in% c("sample_size", "control", "treatment") && !found_tte && !found_bin) {
    stop(paste("Row", row_num, ":", field_name, "requires all combinations in distribution_tte or distribution_bin"))
  }
}

#' Check sf and sfpar combination
#' @param sf Spending function
#' @param sfpar Spending function parameter
#' @param n_analyses Number of analyses
#' @param alpha Alpha level
#' @param row_num Row number for error messages
check_sf_sfpar <- function(sf, sfpar, n_analyses, alpha, row_num) {
  valid_sf <- c("none", "asHSD", "asOF", "asP", "asKD", "asUser")
  if (!sf %in% valid_sf) {
    stop(paste("Row", row_num, "in hypotheses: sf must be one of:", paste(valid_sf, collapse = ", ")))
  }

  if (sf == "none" && n_analyses != 1) {
    stop(paste("Row", row_num, "in hypotheses: sf can only be 'none' if analyses_analysed has length 1"))
  }

  if (sf %in% c("none", "asOF", "asP") && !is.null(sfpar)) {
    stop(paste("Row", row_num, "in hypotheses: sfpar should be NULL for sf =", sf))
  }

  if (sf == "asHSD" && (!is.numeric(sfpar) || sfpar < -40 || sfpar > 40)) {
    stop(paste("Row", row_num, "in hypotheses: sfpar must be in [-40, 40] for sf = 'asHSD'"))
  }

  if (sf == "asKD" && (!is.numeric(sfpar) || sfpar <= 0 || sfpar > 50)) {
    stop(paste("Row", row_num, "in hypotheses: sfpar must be in (0, 50] for sf = 'asKD'"))
  }

  if (sf == "asUser") {
    if (!is.numeric(sfpar) || length(sfpar) != n_analyses) {
      stop(paste("Row", row_num, "in hypotheses: sfpar must be vector of length", n_analyses, "for sf = 'asUser'"))
    }
    if (!all(sfpar > 0 & sfpar <= alpha)) {
      stop(paste("Row", row_num, "in hypotheses: sfpar values must be in (0, alpha] for sf = 'asUser'"))
    }
    if (!identical(sfpar, sort(sfpar))) {
      stop(paste("Row", row_num, "in hypotheses: sfpar must be monotonically non-decreasing for sf = 'asUser'"))
    }
    if (abs(sfpar[length(sfpar)] - alpha) > 1e-10) {
      stop(paste("Row", row_num, "in hypotheses: final sfpar value must equal alpha for sf = 'asUser'"))
    }
  }
}

#' Get all hypothesis combinations
#' @param hypotheses Hypotheses data.frame
#' @return Character vector of combinations
get_hypothesis_combinations <- function(hypotheses) {
  combinations <- character(0)
  for (i in seq_len(nrow(hypotheses))) {
    row <- hypotheses[i, ]
    strata <- row$strata[[1]]

    # Control combinations
    control_combs <- expand.grid(stratum = strata, treatment = row$control, stringsAsFactors = FALSE)
    combinations <- c(combinations, paste(control_combs$stratum, control_combs$treatment))

    # Treatment combinations
    treatment_combs <- expand.grid(stratum = strata, treatment = row$treatment, stringsAsFactors = FALSE)
    combinations <- c(combinations, paste(treatment_combs$stratum, treatment_combs$treatment))
  }
  unique(combinations)
}

#' Get enroll_rate combinations (unnested)
#' @param enroll_rate Enroll_rate data.frame
#' @return Character vector of combinations
get_enroll_rate_combinations <- function(enroll_rate) {
  combinations <- character(0)
  for (i in seq_len(nrow(enroll_rate))) {
    row <- enroll_rate[i, ]
    treatments <- row$treatments[[1]]
    for (treatment in treatments) {
      combinations <- c(combinations, paste(row$stratum, treatment))
    }
  }
  combinations
}

#' Check column consistency across config components
#' @param config Configuration list
check_config_column_consistency <- function(config) {
  has_tte <- "distribution_tte" %in% names(config)
  has_bin <- "distribution_bin" %in% names(config)

  # Get unique treatment values from distributions
  all_treatments <- character(0)
  if (has_tte) all_treatments <- c(all_treatments, config$distribution_tte$treatment)
  if (has_bin) all_treatments <- c(all_treatments, config$distribution_bin$treatment)
  unique_treatments <- unique(all_treatments)

  # Check control/treatment columns in hypotheses based on number of unique treatments
  if (length(unique_treatments) > 2) {
    if (!all(c("control", "treatment") %in% names(config$hypotheses))) {
      stop("control and treatment columns are required in hypotheses when more than 2 unique treatment values exist in distributions")
    }
  }

  # Check endpoint consistency
  if (has_tte && has_bin) {
    # Both distributions present - endpoint required everywhere
    objects <- list(analyses = config$analyses, hypotheses = config$hypotheses,
                    distribution_tte = config$distribution_tte, distribution_bin = config$distribution_bin)
    check_column_presence(objects, "endpoint", "when both distribution_tte and distribution_bin are present")
  } else if (has_tte || has_bin) {
    # Only one distribution present - endpoint either omitted or present everywhere
    dist_obj <- if (has_tte) config$distribution_tte else config$distribution_bin
    dist_name <- if (has_tte) "distribution_tte" else "distribution_bin"
    objects <- list(analyses = config$analyses, hypotheses = config$hypotheses)
    objects[[dist_name]] <- dist_obj
    check_column_all_or_none(objects, "endpoint")
  }

  # Check strata consistency
  objects <- list(analyses = config$analyses, hypotheses = config$hypotheses, enroll_rate = config$enroll_rate)
  col_map <- list(analyses = "strata", hypotheses = "strata", enroll_rate = "stratum")
  if (has_tte) { objects$distribution_tte <- config$distribution_tte; col_map$distribution_tte <- "stratum" }
  if (has_bin) { objects$distribution_bin <- config$distribution_bin; col_map$distribution_bin <- "stratum" }
  check_column_all_or_none_mapped(objects, col_map, "strata/stratum")

  # Check treatment consistency (only if control/treatment not mandatory)
  if (length(unique_treatments) <= 2) {
    col_map <- list(analyses = "treatments", hypotheses = c("control", "treatment"), enroll_rate = "treatments")
    if (has_tte) col_map$distribution_tte <- "treatment"
    if (has_bin) col_map$distribution_bin <- "treatment"
    check_column_all_or_none_mapped(objects, col_map, "treatment")
  }
  config
}

#' Check that all objects have specified column
#' @param objects Named list of data.frames
#' @param col_name Column name to check
#' @param context Context for error message
check_column_presence <- function(objects, col_name, context) {
  for (obj_name in names(objects)) {
    if (!col_name %in% names(objects[[obj_name]])) {
      stop(paste(col_name, "column required in", obj_name, context))
    }
  }
}

#' Check that column is present in all objects or none
#' @param objects Named list of data.frames
#' @param col_name Column name to check
check_column_all_or_none <- function(objects, col_name) {
  presence <- sapply(objects, function(obj) col_name %in% names(obj))
  if (!all(presence) && any(presence)) {
    missing <- names(objects)[!presence]
    stop(paste(col_name, "column must be present in all objects or none. Missing in:", paste(missing, collapse = ", ")))
  }
}

#' Check that mapped columns are present in all objects or none
#' @param objects Named list of data.frames
#' @param col_map Named list mapping object names to column names
#' @param col_desc Description for error message
check_column_all_or_none_mapped <- function(objects, col_map, col_desc) {
  presence <- sapply(names(objects), function(obj_name) {
    cols <- col_map[[obj_name]]
    all(cols %in% names(objects[[obj_name]]))
  })
  if (!all(presence) && any(presence)) {
    missing <- names(objects)[!presence]
    stop(paste(col_desc, "columns must be present in all objects or none. Missing in:", paste(missing, collapse = ", ")))
  }
}
