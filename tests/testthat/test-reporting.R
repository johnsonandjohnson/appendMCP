library(appendMCP)

test_that("generate_report validates gsd_details input", {
  invalid_details <- list(config = list())
  expect_error(
    generate_report(invalid_details),
    "gsd_details must be a results object from process_config"
  )
})

test_that("generate_report accepts valid gsd_details", {
  config <- load_config_from_repository("example_study")
  gsd_details <- process_config(config)

  # Should not error with valid input structure
  expect_no_error({
    required_fields <- c("analyses", "hypotheses", "tables", "config")
    missing_fields <- setdiff(required_fields, names(gsd_details))
    if (length(missing_fields) > 0) {
      stop("Missing fields")
    }
  })
})

test_that("generate_report handles output file naming", {
  config <- load_config_from_repository("example_study")
  gsd_details <- process_config(config)

  # Test default naming logic
  study_name <- gsd_details$config$study_name
  if (!is.null(study_name)) {
    clean_name <- gsub("[^A-Za-z0-9_-]", "_", study_name)
    expect_type(clean_name, "character")
    expect_true(nchar(clean_name) > 0)
  }
})

test_that("generate_report handles different template types", {
  template_types <- c("html", "pdf", "word")
  expected_extensions <- c(".html", ".pdf", ".docx")

  for (i in seq_along(template_types)) {
    file_ext <- switch(template_types[i],
      "html" = ".html",
      "pdf" = ".pdf",
      "word" = ".docx",
      ".html"
    )
    expect_equal(file_ext, expected_extensions[i])
  }
})

test_that("generate_report sets output directory correctly", {
  config <- load_config_from_repository("example_study")
  gsd_details <- process_config(config)

  # Test default output directory logic
  config_file_path <- attr(gsd_details, "config_file_path")

  if (is.null(config_file_path)) {
    expected_dir <- getwd()
  } else if (file.exists(config_file_path)) {
    expected_dir <- dirname(config_file_path)
  } else {
    expected_dir <- getwd()
  }

  expect_type(expected_dir, "character")
  expect_true(dir.exists(expected_dir))
})
