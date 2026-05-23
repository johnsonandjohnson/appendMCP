# Tests for template management functions

# Repository listing functions ----

test_that("list_config_repository returns available configs", {
  configs <- list_config_repository()
  expect_type(configs, "character")
  expect_true("example_study" %in% configs)
})

test_that("list_rmd_template_repository returns available templates", {
  templates <- list_rmd_template_repository()
  expect_type(templates, "character")
  expect_true("gsd_default" %in% templates)
})

# Path resolution functions ----

test_that("get_config_path returns valid path for existing config", {
  path <- get_config_path("example_study")
  expect_true(file.exists(path))
  expect_match(path, "example_study\\.R$")
})

test_that("get_config_path errors for non-existent config", {
  expect_error(get_config_path("nonexistent"), "Config not found")
})

test_that("get_rmd_template_path returns valid path for existing template", {
  path <- get_rmd_template_path("gsd_default")
  expect_true(file.exists(path))
  expect_match(path, "skeleton\\.Rmd$")
})

test_that("get_rmd_template_path errors for non-existent template", {
  expect_error(get_rmd_template_path("nonexistent"), "Rmd template not found")
})

# Repository loading functions ----

test_that("load_config_from_repository loads valid config", {
  config <- load_config_from_repository("example_study")
  expect_type(config, "list")
  expect_true(all(c("analyses", "hypotheses", "enroll_rate", "graph") %in% names(config)))
})

test_that("load_config_from_repository errors for non-existent config", {
  expect_error(load_config_from_repository("nonexistent"), "Config not found")
})

test_that("load_rmd_template_from_repository returns valid path", {
  path <- load_rmd_template_from_repository("gsd_default")
  expect_true(file.exists(path))
  expect_match(path, "\\.Rmd$")
})

# File loading functions ----

test_that("load_config loads valid config file", {
  temp_file <- tempfile(fileext = ".R")
  config_content <- 'study_config <- list(
    analyses = data.frame(endpoint = "OS", strata = I(list("A")), treatments = I(list("TRT")), sample_size = 100, events = NA),
    hypotheses = data.frame(type = "tte", endpoint = "OS", strata = I(list("A")), control = "PBO", test = "TRT", analyses_analysed = I(list(1)), sf = "asOF"),
    enroll_rate = data.frame(stratum = "A", treatments = I(list("TRT")), rate = 10, duration = 12, ratio = 1),
    graph = list(g = matrix(0), w = 1),
    distribution_tte = data.frame(endpoint = "OS", stratum = "A", treatment = "TRT", duration = 12, fail_rate = 0.1, dropout_rate = 0.05)
  )'
  writeLines(config_content, temp_file)

  config <- load_config(temp_file)
  expect_type(config, "list")
  expect_equal(attr(config, "config_file_path"), temp_file)

  unlink(temp_file)
})

test_that("load_config errors for non-existent file", {
  expect_error(load_config("nonexistent.R"), "Configuration file not found")
})

test_that("load_config errors for non-R file", {
  temp_file <- tempfile(fileext = ".txt")
  writeLines("content", temp_file)
  expect_error(load_config(temp_file), "must have \\.R extension")
  unlink(temp_file)
})

test_that("load_config errors for file with no list objects", {
  temp_file <- tempfile(fileext = ".R")
  writeLines("x <- 1", temp_file)
  expect_error(load_config(temp_file), "must define at least one list object")
  unlink(temp_file)
})

test_that("load_config errors for file with multiple list objects", {
  temp_file <- tempfile(fileext = ".R")
  writeLines(c("list1 <- list()", "list2 <- list()"), temp_file)
  expect_error(load_config(temp_file), "multiple list objects")
  unlink(temp_file)
})

test_that("load_rmd_template validates file path", {
  temp_file <- tempfile(fileext = ".Rmd")
  writeLines("# Template", temp_file)

  result <- load_rmd_template(temp_file)
  expect_equal(result, temp_file)

  unlink(temp_file)
})

test_that("load_rmd_template errors for non-existent file", {
  expect_error(load_rmd_template("nonexistent.Rmd"), "Rmd template file not found")
})

test_that("load_rmd_template errors for non-Rmd file", {
  temp_file <- tempfile(fileext = ".txt")
  writeLines("content", temp_file)
  expect_error(load_rmd_template(temp_file), "must have \\.Rmd extension")
  unlink(temp_file)
})

# Configuration validation ----

test_that("validate_config passes for valid config", {
  config <- list(
    analyses = data.frame(endpoint = "OS", strata = I(list("A")), treatments = I(list("TRT")), sample_size = 100, events = NA),
    hypotheses = data.frame(type = "tte", endpoint = "OS", strata = I(list("A")), control = "PBO", test = "TRT", analyses_analysed = I(list(1)), sf = "asOF"),
    enroll_rate = data.frame(stratum = "A", treatments = I(list("TRT")), rate = 10, duration = 12, ratio = 1),
    graph = list(g = matrix(0), w = 1),
    distribution_tte = data.frame(endpoint = "OS", stratum = "A", treatment = "TRT", duration = 12, fail_rate = 0.1, dropout_rate = 0.05)
  )
  expect_true(validate_config(config))
})

test_that("validate_config errors for missing required fields", {
  config <- list(analyses = data.frame())
  expect_error(validate_config(config), "Missing required configuration fields")
})

test_that("validate_config errors when no distribution type provided", {
  config <- list(
    analyses = data.frame(endpoint = "OS", strata = I(list("A")), treatments = I(list("TRT")), sample_size = 100, events = NA),
    hypotheses = data.frame(type = "tte", endpoint = "OS", strata = I(list("A")), control = "PBO", test = "TRT", analyses_analysed = I(list(1)), sf = "asOF"),
    enroll_rate = data.frame(stratum = "A", treatments = I(list("TRT")), rate = 10, duration = 12, ratio = 1),
    graph = list(g = matrix(0), w = 1)
  )
  expect_error(validate_config(config), "At least one of 'distribution_tte' or 'distribution_bin' is required")
})

test_that("validate_config errors for invalid analyses structure", {
  config <- list(
    analyses = "not_a_dataframe",
    hypotheses = data.frame(),
    enroll_rate = data.frame(),
    graph = list(g = matrix(0), w = 1),
    distribution_tte = data.frame()
  )
  expect_error(validate_config(config), "analyses must be a data frame")
})

test_that("validate_config errors for missing analyses columns", {
  config <- list(
    analyses = data.frame(endpoint = "OS"),
    hypotheses = data.frame(type = "tte", endpoint = "OS", strata = I(list("A")), control = "PBO", test = "TRT", analyses_analysed = I(list(1)), sf = "asOF"),
    enroll_rate = data.frame(stratum = "A", treatments = I(list("TRT")), rate = 10, duration = 12, ratio = 1),
    graph = list(g = matrix(0), w = 1),
    distribution_tte = data.frame(endpoint = "OS", stratum = "A", treatment = "TRT", duration = 12, fail_rate = 0.1, dropout_rate = 0.05)
  )
  expect_error(validate_config(config), "analyses missing columns")
})

test_that("validate_config errors for invalid graph structure", {
  config <- list(
    analyses = data.frame(endpoint = "OS", strata = I(list("A")), treatments = I(list("TRT")), sample_size = 100, events = NA),
    hypotheses = data.frame(type = "tte", endpoint = "OS", strata = I(list("A")), control = "PBO", test = "TRT", analyses_analysed = I(list(1)), sf = "asOF"),
    enroll_rate = data.frame(stratum = "A", treatments = I(list("TRT")), rate = 10, duration = 12, ratio = 1),
    graph = list(g = "not_matrix", w = 1),
    distribution_tte = data.frame(endpoint = "OS", stratum = "A", treatment = "TRT", duration = 12, fail_rate = 0.1, dropout_rate = 0.05)
  )
  expect_error(validate_config(config), "graph\\$g must be a matrix")
})
