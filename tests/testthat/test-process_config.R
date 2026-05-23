library(appendMCP)

test_that("process_distribution combines tte and bin data correctly", {
  tte_data <- tibble::tibble(
    endpoint = "OS", stratum = "A", treatment = "TRT",
    duration = 12, fail_rate = 0.1, dropout_rate = 0.05
  )
  bin_data <- tibble::tibble(
    endpoint = "ORR", stratum = "A", treatment = "TRT",
    rate = 0.3, maturity_time = 6
  )

  result <- process_distribution(tte_data, bin_data)

  expect_s3_class(result, "data.frame")
  expect_true("dist_type" %in% names(result))
  expect_true("stratum_treatment" %in% names(result))
  expect_equal(unique(result$dist_type), c("tte", "bin"))
  expect_equal(result$stratum_treatment, c("A-TRT", "A-TRT"))
})

test_that("process_config handles missing distribution data", {
  invalid_config <- list(
    analyses = data.frame(),
    hypotheses = data.frame(),
    enroll_rate = data.frame(),
    graph = list(g = matrix(0), w = 1)
  )
  expect_error(process_config(invalid_config))
})

test_that("process_config returns expected structure", {
  config <- load_config_from_repository("example_study")
  result <- process_config(config)

  expect_type(result, "list")
  expected_names <- c("analyses", "hypotheses", "tables", "config",
                     "graph_figure", "information_figure", "alpha_spend_figure")
  expect_true(all(expected_names %in% names(result)))
  expect_true(all(c(paste0("table", 1:5), "table6a", "table6b") %in% names(result$tables)))
})

test_that("create_summary_tables generates all required tables", {
  config <- load_config_from_repository("example_study")
  result <- process_config(config)

  expect_true(all(c(paste0("table", 1:5), "table6a", "table6b") %in% names(result$tables)))
  expect_s3_class(result$tables$table1, "data.frame")
  expect_s3_class(result$tables$table2, "data.frame")
  expect_s3_class(result$tables$table3, "data.frame")
  expect_s3_class(result$tables$table4, "data.frame")
  expect_s3_class(result$tables$table5, "data.frame")
  if (!is.null(result$tables$table6a)) {
    expect_s3_class(result$tables$table6a, "data.frame")
  }
  if (!is.null(result$tables$table6b)) {
    expect_s3_class(result$tables$table6b, "data.frame")
  }
})

test_that("process_analyses_1 adds required columns", {
  config <- load_config_from_repository("example_study")
  distribution <- process_distribution(config$distribution_tte, config$distribution_bin)
  enroll_rate <- process_enroll_rate(config$enroll_rate)
  result <- process_analyses_1(config$analyses, enroll_rate, distribution, config$hypotheses)

  expected_cols <- c("index", "dist_type", "hypotheses_analysed", "time",
                    "description_trigger_short", "description_trigger_long")
  expect_true(all(expected_cols %in% names(result)))
  expect_equal(nrow(result), nrow(config$analyses))
})

test_that("process_hypotheses adds OC information", {
  config <- load_config_from_repository("example_study")
  distribution <- process_distribution(config$distribution_tte, config$distribution_bin)
  enroll_rate <- process_enroll_rate(config$enroll_rate)
  analyses_1 <- process_analyses_1(config$analyses, enroll_rate, distribution, config$hypotheses)
  weights <- get_weights(config$graph)
  result <- process_hypotheses(config$hypotheses, analyses_1, enroll_rate, distribution, weights)

  expected_cols <- c("specs", "power", "hurdles", "nominal_p", "description_effect_size")
  expect_true(all(expected_cols %in% names(result)))
  expect_true(nrow(result) >= nrow(config$hypotheses))
})
