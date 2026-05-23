#' Resolve config source (name, path, or list)
#' @param config Config name, file path, or config list object
#' @return List with type ("file" or "object") and value (path or config object)
resolve_config_source       <- function(
  config
) {
  # Check if config is a list object
  if (is.list(config)) {
    #check_config(config)
    return(list(type = "object", value = config))
  }
  # Check if config is a file path
  if (file.exists(config) && grepl("\\.R$", config)) {
    return(list(type = "file", value = config))
  }
  # Check if config is in repository
  if (config %in% list_config_repository()) {
    return(list(type = "file", value = get_config_path(config)))
  }
  stop(
    "Config '", config, "' not found. ",
    "Provide one of the following:\n",
    "  - Valid config list object\n",
    "  - Valid file path to .R config file\n",
    "  - Config name from repository: ",
    glue::glue_collapse(list_config_repository(), sep = ", ", last = " and ")
  )
}

#' Resolve rmd_template source (name or path)
#' @param rmd_template Rmd template name or file path
#' @return Path to rmd_template file
resolve_rmd_template_source <- function(
  rmd_template
) {
  if (file.exists(rmd_template) && grepl("\\.Rmd$", rmd_template)) {
    return(rmd_template)
  }
  if (rmd_template %in% list_rmd_template_repository()) {
    return(get_rmd_template_path(rmd_template))
  }
  stop(
    "Rmd template '", rmd_template, "' not found. ",
    "Provide one of the following:\n",
    "  - Valid file path to .Rmd template file\n",
    "  - Rmd template name from repository: ",
    glue::glue_collapse(list_rmd_template_repository(), sep = ", ",
                        last = " and ")
  )
}

#' Create new study from config and template
#' @param config Either a config list object, config name from repository, or path to .R config file
#' @param rmd_template Either a template name or path to .Rmd template file (default: "gsd_detailed")
#' @param output_dir Directory to create study files
#' @export
create_study                <- function(
  config,
  rmd_template = "gsd_detailed",
  output_dir   = "."
) {
  # Resolve sources
  config_source            <- resolve_config_source(config)
  rmd_template_source_file <- resolve_rmd_template_source(rmd_template)
  # Create output directory if it doesn't exist
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  # Handle config file creation
  config_file              <- file.path(output_dir, "study_config.R")
  if (config_source$type == "file") {
    # Copy and modify existing config file
    config_content         <- readLines(config_source$value)
    # Replace any *_config variable assignment with study_config
    config_content         <- gsub("^\\s*[a-zA-Z_][a-zA-Z0-9_]*_config\\s*<-",
                                   "study_config <-", config_content)
    writeLines(config_content, config_file)
  } else {
    # Create config file from list object
    config_content         <- c(
      "# Study configuration created from list object",
      "",
      paste0("study_config <- ", deparse(config_source$value,
                                         width.cutoff = 80))
    )
    writeLines(config_content, config_file)
  }
  # Copy Rmd template
  file.copy(rmd_template_source_file, file.path(output_dir, "report.Rmd"),
            overwrite = TRUE)

  # Create analysis script
  config_file_abs          <- file.path(getwd(), output_dir, "study_config.R")
  rmd_file_abs             <- file.path(getwd(), output_dir, "report.Rmd")
  output_dir_abs           <- file.path(getwd(), output_dir)
  analysis_script          <- glue::glue('
  # Load required libraries
  library(appendMCP)

  # Load study configuration
  source("{config_file_abs}")

  # Run analysis
  results <- process_config(study_config)

  # View results
  print(results$tables$table1)
  print(results$tables$table2)

  # Generate report (if available)
  if (file.exists("{rmd_file_abs}")) {{
    rmarkdown::render("{rmd_file_abs}",
                     params = list(config = study_config),
                     output_dir = "{output_dir_abs}",
                     output_file = "report.html")
  }}
  ')
  writeLines(analysis_script, file.path(output_dir, "render_config.R"))
  message("Study created successfully in: ", output_dir)
  message("Files created:")
  if (config_source$type == "file") {
    message("  - study_config.R (config variable renamed to 'study_config')")
  } else {
    message("  - study_config.R (created from config list object)")
  }
  message("  - render_config.R (run this to execute the analysis)")
  message("  - report.Rmd (report template from: ",
          basename(rmd_template_source_file), ")")
  invisible(output_dir)
}
