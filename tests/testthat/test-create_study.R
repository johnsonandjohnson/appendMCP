test_that("resolve_config_source works with list", {
  config <- list(
    analyses = data.frame(
      endpoint = "OS", strata = I(list("A")), treatments = I(list("TRT")),
      sample_size = 100, events = NA
    ),
    hypotheses = data.frame(
      type = "tte", endpoint = "OS", strata = I(list("A")), control = "PBO",
      test = "TRT", analyses_analysed = I(list(1)), sf = "asOF"
    ),
    enroll_rate = data.frame(
      stratum = "A", treatments = I(list("TRT")), rate = 10, duration = 12, ratio = 1
    ),
    graph = list(g = matrix(0), w = 1),
    distribution_tte = data.frame(
      endpoint = "OS", stratum = "A", treatment = "TRT",
      duration = 12, fail_rate = 0.1, dropout_rate = 0.05
    )
  )
  result <- resolve_config_source(config)
  expect_identical(result$type, "object")
  expect_true(is.list(result$value))
  expect_true(all(names(config) %in% names(result$value)))
})

test_that("resolve_config_source works with file path", {
  temp_file <- tempfile(fileext = ".R")
  writeLines("config <- list()", temp_file)
  result <- resolve_config_source(temp_file)
  expect_identical(result$type, "file")
  expect_identical(result$value, temp_file)
  unlink(temp_file)
})

test_that("resolve_config_source errors on invalid input", {
  expect_error(resolve_config_source("nonexistent"))
})

test_that("resolve_rmd_template_source works with file path", {
  temp_file <- tempfile(fileext = ".Rmd")
  writeLines("# Template", temp_file)
  result <- resolve_rmd_template_source(temp_file)
  expect_identical(result, temp_file)
  unlink(temp_file)
})

test_that("resolve_rmd_template_source errors on invalid input", {
  expect_error(resolve_rmd_template_source("nonexistent"))
})

test_that("create_study creates files", {
  config <- list(
    analyses = data.frame(
      endpoint = "OS", strata = I(list("A")), treatments = I(list("TRT")),
      sample_size = 100, events = NA
    ),
    hypotheses = data.frame(
      type = "tte", endpoint = "OS", strata = I(list("A")), control = "PBO",
      test = "TRT", analyses_analysed = I(list(1)), sf = "asOF"
    ),
    enroll_rate = data.frame(
      stratum = "A", treatments = I(list("TRT")), rate = 10, duration = 12, ratio = 1
    ),
    graph = list(g = matrix(0), w = 1),
    distribution_tte = data.frame(
      endpoint = "OS", stratum = "A", treatment = "TRT",
      duration = 12, fail_rate = 0.1, dropout_rate = 0.05
    )
  )
  temp_template <- tempfile(fileext = ".Rmd")
  writeLines("# Template", temp_template)
  temp_dir <- file.path(tempdir(), paste0("test_study_", Sys.getpid()))

  on.exit({
    unlink(temp_template)
    unlink(temp_dir, recursive = TRUE)
  })

  create_study(config, temp_template, temp_dir)

  expect_true(file.exists(file.path(temp_dir, "study_config.R")))
  expect_true(file.exists(file.path(temp_dir, "report.Rmd")))
  expect_true(file.exists(file.path(temp_dir, "render_config.R")))
})

test_that("create_study renames config variable", {
  temp_config <- tempfile(fileext = ".R")
  writeLines("old_config <- list()", temp_config)
  temp_template <- tempfile(fileext = ".Rmd")
  writeLines("# Template", temp_template)
  temp_dir <- file.path(tempdir(), "test_rename")

  create_study(temp_config, temp_template, temp_dir)

  content <- readLines(file.path(temp_dir, "study_config.R"))
  expect_true(any(grepl("study_config <-", content)))

  unlink(temp_config)
  unlink(temp_template)
  unlink(temp_dir, recursive = TRUE)
})
