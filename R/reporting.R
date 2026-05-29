# Reporting functions

#' Generate GSD Report
#' @param gsd_details Results object from process_config function
#' @param output_file Output file path (defaults to config name + extension)
#' @param template_type Type of report template ("html", "pdf", "word")
#' @param template_file Path to Rmd template file (defaults to package template)
#' @param output_dir Output directory (defaults to config file directory)
#' @export
generate_report <- function(gsd_details, output_file = NULL, template_type = "html", template_file = NULL, output_dir = NULL) {

  # Validate that gsd_details is a processed results object
  required_fields <- c("analyses", "hypotheses", "tables", "config")
  missing_fields <- setdiff(required_fields, names(gsd_details))
  if (length(missing_fields) > 0) {
    stop("gsd_details must be a results object from process_config(). Missing fields: ",
         paste(missing_fields, collapse = ", "))
  }

  results <- gsd_details
  study_config <- gsd_details$config
  config_file_path <- attr(gsd_details, "config_file_path")

  # Set default output directory
  if (is.null(output_dir)) {
    if (!is.null(config_file_path) && file.exists(config_file_path)) {
      output_dir <- dirname(config_file_path)
    } else {
      output_dir <- getwd()
    }
  }

  # Set default output file based on config name
  if (is.null(output_file)) {
    config_name <- if (!is.null(study_config$study_name)) {
      study_config$study_name
    } else {
      "gsd_report"
    }
    # Clean config name for filename
    config_name <- gsub("[^A-Za-z0-9_-]", "_", config_name)

    file_ext <- switch(template_type,
      "html" = ".html",
      "pdf" = ".pdf",
      "word" = ".docx",
      ".html"
    )
    output_file <- file.path(output_dir, paste0(config_name, file_ext))
  } else {
    # If output_file provided but no directory, use output_dir
    if (!grepl("/", output_file) && !grepl("\\\\", output_file)) {
      output_file <- file.path(output_dir, output_file)
    }
  }

  # Find report template
  if (is.null(template_file)) {
    template_file <- system.file("rmarkdown", "templates", "gsd_detailed", "skeleton", "skeleton.Rmd", package = "appendMCP")
  }

  if (!nzchar(template_file) || !file.exists(template_file)) {
    stop("Report template not found: ", template_file)
  }

  # Copy template to a writable temp directory (fixes read-only file systems:

  # Posit Connect, Docker, HPC shared libraries)
  render_dir <- tempfile("report_")
  dir.create(render_dir)
  tmpl_copy <- file.path(render_dir, basename(template_file))
  file.copy(template_file, tmpl_copy, overwrite = TRUE)
  on.exit(unlink(render_dir, recursive = TRUE), add = TRUE)

  # Determine output format — use bookdown if available (supports cross-references),
  # fall back to rmarkdown (renders without cross-refs but doesn't crash)
  output_format <- switch(template_type,
    "html" = if (requireNamespace("bookdown", quietly = TRUE)) {
      bookdown::html_document2(self_contained = TRUE)
    } else {
      rmarkdown::html_document(self_contained = TRUE)
    },
    "word" = if (requireNamespace("bookdown", quietly = TRUE)) {
      bookdown::word_document2()
    } else {
      rmarkdown::word_document()
    },
    "pdf" = rmarkdown::pdf_document(),
    rmarkdown::html_document(self_contained = TRUE)
  )

  # Render report
  rmarkdown::render(
    input = tmpl_copy,
    output_format = output_format,
    output_file = basename(output_file),
    output_dir = dirname(output_file),
    params = list(
      results = results,
      config = study_config
    ),
    envir = new.env()
  )

  message("Report generated: ", output_file)
  invisible(output_file)
}
