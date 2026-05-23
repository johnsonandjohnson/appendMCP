# Template management functions

# Repository listing functions ----

#' Get available config repository entries
#' @return Character vector of available config names
#' @export
list_config_repository <- function() {
  config_dir <- system.file("config_repository", package = "appendMCP")
  if (config_dir == "" || !dir.exists(config_dir)) return(character(0))
  list.files(config_dir, pattern = "\\.R$", full.names = FALSE) |>
    tools::file_path_sans_ext()
}

#' Get available Rmd template repository entries
#' @return Character vector of available rmd_template names
#' @export
list_rmd_template_repository <- function() {
  rmd_template_dir <- system.file("rmarkdown", "templates", package = "appendMCP")
  if (rmd_template_dir == "" || !dir.exists(rmd_template_dir)) return(character(0))
  list.dirs(rmd_template_dir, full.names = FALSE, recursive = FALSE)
}

# Path resolution functions ----

#' Get path to config file from repository
#' @param config_name Name of config in repository
#' @return Path to config file
#' @export
get_config_path <- function(config_name) {
  config_file <- system.file("config_repository", paste0(config_name, ".R"), package = "appendMCP")
  if (config_file == "") {
    stop("Config not found in repository. Available configs: ",
         paste(list_config_repository(), collapse = ", "))
  }
  return(config_file)
}

#' Get path to Rmd template skeleton
#' @param rmd_template_name Name of Rmd template
#' @return Path to skeleton.Rmd file
#' @export
get_rmd_template_path <- function(rmd_template_name) {
  rmd_template_path <- system.file("rmarkdown", "templates", rmd_template_name, "skeleton", "skeleton.Rmd", package = "appendMCP")
  if (rmd_template_path == "") {
    stop("Rmd template not found in repository. Available rmd_templates: ",
         paste(list_rmd_template_repository(), collapse = ", "))
  }
  return(rmd_template_path)
}

# Repository loading functions ----

#' Load config from repository
#' @param config_name Name of config to load from repository
#' @return Study configuration list
#' @export
load_config_from_repository <- function(config_name) {
  config_file <- get_config_path(config_name)

  # Source config in isolated environment
  config_env <- new.env()
  source(config_file, local = config_env)

  # Find any list object in the environment
  objects <- ls(config_env)
  list_objects <- objects[sapply(objects, function(x) is.list(get(x, envir = config_env)))]

  if (length(list_objects) == 0) {
    stop("Config file must define at least one list object")
  }

  if (length(list_objects) > 1) {
    stop("Config file contains multiple list objects: ", paste(list_objects, collapse = ", "),
         ". Please define only one list object.")
  }

  return(get(list_objects[1], envir = config_env))
}

#' Load Rmd template from repository
#' @param rmd_template_name Name of rmd_template to load from repository
#' @return Path to rmd_template file
#' @export
load_rmd_template_from_repository <- function(rmd_template_name) {
  return(get_rmd_template_path(rmd_template_name))
}

# File loading functions ----

#' Load study configuration from file path
#' @param file_path Full path to configuration R file
#' @return Study configuration list
#' @export
load_config <- function(file_path) {
  # Validate file exists
  if (!file.exists(file_path)) {
    stop("Configuration file not found: ", file_path)
  }

  # Validate file extension
  if (!grepl("\\.R$", file_path, ignore.case = TRUE)) {
    stop("Configuration file must have .R extension")
  }

  # Source config in isolated environment
  config_env <- new.env()
  tryCatch({
    source(file_path, local = config_env)
  }, error = function(e) {
    stop("Error loading configuration file: ", e$message)
  })

  # Find any list object in the environment
  objects <- ls(config_env)
  list_objects <- objects[sapply(objects, function(x) is.list(get(x, envir = config_env)))]

  if (length(list_objects) == 0) {
    stop("Config file must define at least one list object")
  }

  if (length(list_objects) > 1) {
    stop("Config file contains multiple list objects: ", paste(list_objects, collapse = ", "),
         ". Please define only one list object.")
  }

  # Validate configuration
  config <- get(list_objects[1], envir = config_env)
  validate_config(config)

  # Store file path as attribute for use by generate_report
  attr(config, "config_file_path") <- file_path

  return(config)
}

#' Load Rmd template from file path
#' @param file_path Full path to rmd_template Rmd file
#' @return Path to rmd_template file (validated)
#' @export
load_rmd_template <- function(file_path) {
  # Validate file exists
  if (!file.exists(file_path)) {
    stop("Rmd template file not found: ", file_path)
  }

  # Validate file extension
  if (!grepl("\\.Rmd$", file_path, ignore.case = TRUE)) {
    stop("Rmd template file must have .Rmd extension")
  }

  return(file_path)
}



#' Validate study configuration
#' @param config Study configuration list
#' @return TRUE if valid, otherwise throws error
#' @export
validate_config <- function(config) {
  # Required top-level fields
  required_fields <- c("analyses", "hypotheses", "enroll_rate", "graph")
  missing_fields <- setdiff(required_fields, names(config))
  if (length(missing_fields) > 0) {
    stop("Missing required configuration fields: ",
         paste(missing_fields, collapse = ", "))
  }

  # At least one distribution type required
  if (!"distribution_tte" %in% names(config) && !"distribution_bin" %in% names(config)) {
    stop("At least one of 'distribution_tte' or 'distribution_bin' is required")
  }

  # Validate analyses structure
  if (!is.data.frame(config$analyses)) {
    stop("analyses must be a data frame")
  }
  analyses_cols <- c("endpoint", "strata", "treatments", "sample_size", "events")
  missing_analyses_cols <- setdiff(analyses_cols, names(config$analyses))
  if (length(missing_analyses_cols) > 0) {
    stop("analyses missing columns: ", paste(missing_analyses_cols, collapse = ", "))
  }
  # Validate analyses column types
  for (i in seq_len(nrow(config$analyses))) {
    row <- config$analyses[i, ]
    if (!is.character(row$endpoint) || length(row$endpoint) != 1) {
      stop("analyses row ", i, ": endpoint must be a single string")
    }
    s <- row$strata[[1]]
    if (!is.character(s) || length(s) < 1) {
      stop("analyses row ", i, ": strata must be a character vector")
    }
    tr <- row$treatments[[1]]
    if (!is.character(tr) || length(tr) < 1) {
      stop("analyses row ", i, ": treatments must be a character vector")
    }
    if (!(is.numeric(row$sample_size) || is.na(row$sample_size))) {
      stop("analyses row ", i, ": sample_size must be numeric or NA")
    }
    if (!(is.numeric(row$events) || is.na(row$events))) {
      stop("analyses row ", i, ": events must be numeric or NA")
    }
    if ("power_subsets_any" %in% names(config$analyses)) {
      if (!is.list(row$power_subsets_any[[1]])) {
        stop("analyses row ", i, ": power_subsets_any must be a named list")
      }
    }
    if ("power_subsets_all" %in% names(config$analyses)) {
      if (!is.list(row$power_subsets_all[[1]])) {
        stop("analyses row ", i, ": power_subsets_all must be a named list")
      }
    }
  }

  # Validate hypotheses structure
  if (!is.data.frame(config$hypotheses)) {
    stop("hypotheses must be a data frame")
  }
  # Required columns (sfpar and nominal are optional depending on configuration)
  required_hypotheses_cols <- c("type", "endpoint", "strata", "control", "test", "analyses_analysed", "sf")
  missing_hypotheses_cols <- setdiff(required_hypotheses_cols, names(config$hypotheses))
  if (length(missing_hypotheses_cols) > 0) {
    stop("hypotheses missing required columns: ", paste(missing_hypotheses_cols, collapse = ", "))
  }
  # Validate hypotheses column types
  for (i in seq_len(nrow(config$hypotheses))) {
    row <- config$hypotheses[i, ]
    if (!is.character(row$type) || length(row$type) != 1) {
      stop("hypotheses row ", i, ": type must be a single string")
    }
    if (!is.character(row$endpoint) || length(row$endpoint) != 1) {
      stop("hypotheses row ", i, ": endpoint must be a single string")
    }
    s <- row$strata[[1]]
    if (!is.character(s) || length(s) < 1) {
      stop("analyses row ", i, ": strata must be a character vector")
    }
    if (!is.character(row$control) || length(row$control) != 1) {
      stop("hypotheses row ", i, ": control must be a single string")
    }
    t <- row$test[[1]]
    if (!is.character(t) || length(t) < 1) {
      stop("analyses row ", i, ": test must be a character vector")
    }
    aa <- row$analyses_analysed[[1]]
    if (!is.numeric(aa) || length(aa) < 1) {
      stop("hypotheses row ", i, ": analyses_analysed must be a numeric vector")
    }
    if (!is.character(row$sf) || length(row$sf) != 1) {
      stop("hypotheses row ", i, ": sf must be a single string")
    }
    if ("sfpar" %in% names(config$hypotheses)) {
      if (!is.null(row$sfpar[[1]]) && !is.numeric(row$sfpar[[1]])) {
        stop("hypotheses row ", i, ": sfpar must be numeric or NULL")
      }
    }
    if ("nominal" %in% names(config$hypotheses)) {
      if (!is.null(row$nominal[[1]]) && !is.numeric(row$nominal[[1]])) {
        stop("hypotheses row ", i, ": nominal must be numeric or NULL")
      }
      if (row$sf == "none" && !is.null(row$nominal[[1]]) && !all(is.na(row$nominal[[1]]))) {
        warning("hypotheses row ", i, ": 'nominal' is ignored when sf = 'none' (no spending function)")
      }
    }
    if ("test_method" %in% names(config$hypotheses)) {
      if (!is.character(row$test_method) || length(row$test_method) != 1) {
        stop("hypotheses row ", i, ": test_method must be a single string")
      }
    }
  }

  # Validate enroll_rate structure
  if (!is.data.frame(config$enroll_rate)) {
    stop("enroll_rate must be a data frame")
  }
  enroll_cols <- c("stratum", "treatments", "rate", "duration", "ratio")
  missing_enroll_cols <- setdiff(enroll_cols, names(config$enroll_rate))
  if (length(missing_enroll_cols) > 0) {
    stop("enroll_rate missing columns: ", paste(missing_enroll_cols, collapse = ", "))
  }
  # Validate enroll_rate column types
  for (i in seq_len(nrow(config$enroll_rate))) {
    row <- config$enroll_rate[i, ]
    if (!is.character(row$stratum) || length(row$stratum) != 1) {
      stop("enroll_rate row ", i, ": stratum must be a single string")
    }
    tr <- row$treatments[[1]]
    if (!is.character(tr) || length(tr) < 1) {
      stop("enroll_rate row ", i, ": treatments must be a character vector")
    }
    if (!is.numeric(row$rate) || length(row$rate) != 1) {
      stop("enroll_rate row ", i, ": rate must be a single number")
    }
    if (!is.numeric(row$duration) || length(row$duration) != 1) {
      stop("enroll_rate row ", i, ": duration must be a single number")
    }
    r <- row$ratio[[1]]
    if (!is.numeric(r) || length(r) < 1) {
      stop("enroll_rate row ", i, ": ratio must be a numeric vector")
    }
  }

  # Validate distribution_tte if present
  if ("distribution_tte" %in% names(config)) {
    if (!is.data.frame(config$distribution_tte)) {
      stop("distribution_tte must be a data frame")
    }
    tte_cols <- c("endpoint", "stratum", "treatment", "duration", "fail_rate", "dropout_rate")
    missing_tte_cols <- setdiff(tte_cols, names(config$distribution_tte))
    if (length(missing_tte_cols) > 0) {
      stop("distribution_tte missing columns: ", paste(missing_tte_cols, collapse = ", "))
    }
    # Validate distribution_tte column types
    for (i in seq_len(nrow(config$distribution_tte))) {
      row <- config$distribution_tte[i, ]
      if (!is.character(row$endpoint) || length(row$endpoint) != 1) {
        stop("distribution_tte row ", i, ": endpoint must be a single string")
      }
      if (!is.character(row$stratum) || length(row$stratum) != 1) {
        stop("distribution_tte row ", i, ": stratum must be a single string")
      }
      if (!is.character(row$treatment) || length(row$treatment) != 1) {
        stop("distribution_tte row ", i, ": treatment must be a single string")
      }
      if (!is.numeric(row$duration) || length(row$duration) != 1) {
        stop("distribution_tte row ", i, ": duration must be a single number")
      }
      if (!is.numeric(row$fail_rate) || length(row$fail_rate) != 1) {
        stop("distribution_tte row ", i, ": fail_rate must be a single number")
      }
      if (!is.numeric(row$dropout_rate) || length(row$dropout_rate) != 1) {
        stop("distribution_tte row ", i, ": dropout_rate must be a single number")
      }
    }
  }

  # Validate distribution_bin if present
  if ("distribution_bin" %in% names(config)) {
    if (!is.data.frame(config$distribution_bin)) {
      stop("distribution_bin must be a data frame")
    }
    bin_cols <- c("endpoint", "stratum", "treatment", "rate", "maturity_time")
    missing_bin_cols <- setdiff(bin_cols, names(config$distribution_bin))
    if (length(missing_bin_cols) > 0) {
      stop("distribution_bin missing columns: ", paste(missing_bin_cols, collapse = ", "))
    }
    # Validate distribution_bin column types
    for (i in seq_len(nrow(config$distribution_bin))) {
      row <- config$distribution_bin[i, ]
      if (!is.character(row$endpoint) || length(row$endpoint) != 1) {
        stop("distribution_bin row ", i, ": endpoint must be a single string")
      }
      if (!is.character(row$stratum) || length(row$stratum) != 1) {
        stop("distribution_bin row ", i, ": stratum must be a single string")
      }
      if (!is.character(row$treatment) || length(row$treatment) != 1) {
        stop("distribution_bin row ", i, ": treatment must be a single string")
      }
      if (!is.numeric(row$rate) || length(row$rate) != 1) {
        stop("distribution_bin row ", i, ": rate must be a single number")
      }
      if (!is.numeric(row$maturity_time) || length(row$maturity_time) != 1) {
        stop("distribution_bin row ", i, ": maturity_time must be a single number")
      }
    }
  }

  # Validate graph structure
  if (!is.list(config$graph) || !all(c("g", "w") %in% names(config$graph))) {
    stop("graph must be a list with elements 'g' (matrix) and 'w' (weights)")
  }
  if (!is.matrix(config$graph$g)) {
    stop("graph$g must be a matrix")
  }
  if (!is.numeric(config$graph$w)) {
    stop("graph$w must be numeric")
  }
  if (nrow(config$graph$g) != ncol(config$graph$g)) {
    stop("graph$g must be a square matrix")
  }
  if (length(config$graph$w) != nrow(config$graph$g)) {
    stop("Length of graph$w must equal number of rows in graph$g")
  }
  if (any(diag(config$graph$g) != 0)) {
    stop("Diagonal elements of graph$g must be zero (no self-loops allowed)")
  }
  if (any(config$graph$w < 0)) {
    stop("All weights in graph$w must be non-negative")
  }

  # Validate analyses_analysed references
  n_analyses <- nrow(config$analyses)
  for (i in seq_len(nrow(config$hypotheses))) {
    analyses_ref <- config$hypotheses$analyses_analysed[[i]]
    if (any(analyses_ref < 1 | analyses_ref > n_analyses)) {
      invalid_refs <- analyses_ref[analyses_ref < 1 | analyses_ref > n_analyses]
      stop("Hypothesis ", i, " references invalid analysis indices: ",
           paste(invalid_refs, collapse = ", "),
           ". Valid range is 1 to ", n_analyses)
    }
  }

  TRUE
}
