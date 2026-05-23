library(appendMCP)

test_that("example_study_config data object exists and has correct structure", {
  data("example_study_config", package = "appendMCP")

  expect_type(example_study_config, "list")

  # Check required top-level components
  required_fields <- c("study_name", "study_description", "alpha", "analyses",
                      "hypotheses", "enroll_rate", "distribution_tte",
                      "distribution_bin", "graph")
  expect_true(all(required_fields %in% names(example_study_config)))
})

test_that("example_study_config has valid data types", {
  data("example_study_config", package = "appendMCP")

  expect_type(example_study_config$study_name, "character")
  expect_type(example_study_config$study_description, "character")
  expect_type(example_study_config$alpha, "double")
  expect_s3_class(example_study_config$analyses, "data.frame")
  expect_s3_class(example_study_config$hypotheses, "data.frame")
  expect_s3_class(example_study_config$enroll_rate, "data.frame")
  expect_s3_class(example_study_config$distribution_tte, "data.frame")
  expect_s3_class(example_study_config$distribution_bin, "data.frame")
  expect_type(example_study_config$graph, "list")
})

test_that("example_study_config passes validation", {
  data("example_study_config", package = "appendMCP")

  expect_true(validate_config(example_study_config))
})

test_that("example_study_config can be processed", {
  data("example_study_config", package = "appendMCP")

  expect_no_error({
    result <- process_config(example_study_config)
    expect_type(result, "list")
  })
})
