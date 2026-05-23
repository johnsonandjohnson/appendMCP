# Helper functions, relating to formatting tables

# Width for huxtable tables: 6.5/6 for Word (fills 6.5in text area), 1 for HTML
.hux_width <- function() {
  if (isTRUE(knitr::pandoc_to() == "docx")) 6.5/6 else 1
}

#' Function to add hypothesis header rows (removes hypothesis column)
#' @param hux_table A hux table to modify
#' @param data the original data.frame version of the above table
#' @param n_cols Number of columns
#' @return Modified hux table
#' @export
add_hypothesis_headers <- function(hux_table, data, n_cols) {
  unique_hypotheses    <- unique(data$Hypothesis)
  offset               <- 0
  for (i in seq_along(unique_hypotheses)) {
    hyp                <- unique_hypotheses[i]
    # Calculate position accounting for previously inserted rows
    original_first_row <- min(which(data$Hypothesis == hyp))
    original_last_row  <- max(which(data$Hypothesis == hyp))
    first_row          <- original_first_row + 1 + offset  # +1 for header row
    last_data_row      <- original_last_row + 1 + offset  # +1 for header row
    # Insert hypothesis header row
    empty_cols         <- rep("", n_cols - 1)
    hux_table          <- huxtable::insert_row(hux_table,
                                               after = first_row - 1,
                                               hyp, empty_cols)
    # Merge across columns for hypothesis header
    hux_table          <- huxtable::merge_cells(hux_table,
                                                row = first_row,
                                                col = 1:n_cols)
    # Make hypothesis header bold and left-aligned
    hux_table          <- huxtable::set_bold(hux_table,
                                             row   = first_row,
                                             col   = 1,
                                             value = TRUE)
    hux_table          <- huxtable::set_align(hux_table,
                                              row   = first_row,
                                              col   = 1:n_cols,
                                              value = "left")
    hux_table          <- huxtable::set_header_rows(hux_table,
                                                    first_row,
                                                    FALSE)
    # Add border after section header
    hux_table          <- huxtable::set_bottom_border(hux_table,
                                                      row   = first_row,
                                                      col   = huxtable::everywhere,
                                                      value = 1)
    # Add border after section data rows
    hux_table          <- huxtable::set_bottom_border(hux_table,
                                                      row   = last_data_row + 1,
                                                      col   = huxtable::everywhere,
                                                      value = 1)
    offset             <- offset + 1
  }
  hux_table
}

#' Function to add criteria headers (removes criteria and time columns)
#' @param hux_table A hux table to modify
#' @param data the original data.frame version of the above table
#' @param n_cols Number of columns
#' @param time_digits Number of decimal places for expected analysis time
#' @return Modified hux table
#' @export
add_criteria_headers <- function(hux_table, data, n_cols, time_digits = 1) {
  unique_criteria      <- unique(data$`Criteria for conduct`)
  offset               <- 0
  for (i in seq_along(unique_criteria)) {
    criteria           <- unique_criteria[i]
    expected_time      <-
      unique(data$`Expected analysis time`[data$`Criteria for conduct` ==
                                             criteria])[1]
    # Calculate position accounting for previously inserted rows
    original_first_row <- min(which(data$`Criteria for conduct` == criteria))
    original_last_row  <- max(which(data$`Criteria for conduct` == criteria))
    first_row          <- original_first_row + 1 + offset  # +1 for header row
    last_data_row      <- original_last_row + 1 + offset  # +1 for header row
    # Create header text combining criteria and time
    header_text        <- paste0(criteria, " (Expected analysis time: ",
                                 sprintf(paste0("%-.", time_digits, "f"),
                                         expected_time), " mo)")
    # Insert criteria header row
    empty_cols         <- rep("", n_cols - 1)
    hux_table          <- huxtable::insert_row(hux_table,
                                               after = first_row - 1,
                                               header_text,
                                               empty_cols)
    # Merge across columns for criteria header
    hux_table          <- huxtable::merge_cells(hux_table,
                                                row = first_row,
                                                col = 1:n_cols)
    # Make criteria header bold
    hux_table          <- huxtable::set_bold(hux_table,
                                             row   = first_row,
                                             col   = 1,
                                             value = TRUE)
    hux_table          <- huxtable::set_align(hux_table,
                                              row   = first_row,
                                              col   = 1:n_cols,
                                              value = "left")
    hux_table          <- huxtable::set_header_rows(hux_table,
                                                    first_row,
                                                    FALSE)
    # Add border after section header
    hux_table          <- huxtable::set_bottom_border(hux_table,
                                                      row   = first_row,
                                                      col   = huxtable::everywhere,
                                                      value = 1)
    # Add border after section data rows
    hux_table          <- huxtable::set_bottom_border(hux_table,
                                                      row   = last_data_row + 1,
                                                      col   = huxtable::everywhere,
                                                      value = 1)
    offset             <- offset + 1
  }
  hux_table
}

#' Table 1: Trial Design Summary
#' @param table1 data.frame version of table1
#' @param n_digits Number of decimal places for maximum events / sample size
#' @param font_size Font size in points, or NULL to use document default
#' @return huxtable version of table1
#' @export
table1_hux <- function(table1, n_digits = 0, font_size = NULL) {
  table1 |>
    dplyr::mutate(
      `Maximum events / sample size` = sprintf(paste0("%-.", n_digits, "f"),
                                               .data$`Maximum events / sample size`)
    ) |>
    huxtable::as_hux() |>
    huxtable::set_bold(row = 1, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_align(row = huxtable::everywhere, col = huxtable::everywhere, value = "left") |>
    huxtable::set_align(row = huxtable::everywhere, col = c(4, 6, 7), value = "right") |>
    huxtable::set_valign(row = huxtable::everywhere, col = huxtable::everywhere, value = "top") |>
    huxtable::set_wrap(row = huxtable::everywhere, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_width(.hux_width()) |>
    huxtable::set_col_width(c(0.075, 0.075, 0.1, 0.125, 0.3, 0.125, 0.2)) |>
    huxtable::set_top_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_bottom_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_caption("Trial Design Summary") |>
    huxtable::set_header_rows(1, FALSE) ->
    temp
  temp[1, 6] <- "Effect size*"
  temp |>
    huxtable::add_footnote(
      "*For a hypothesis corresponding to a time-to-event variable subject to non-proportional hazards, the listed effect size is the average hazard ratio at the final analysis of this hypothesis."
    ) |>
    huxtable::set_bottom_border(row   = nrow(temp),
                                col   = huxtable::everywhere,
                                value = 1) |>
    huxtable::set_left_padding(row   = huxtable::everywhere,
                               col   = huxtable::everywhere,
                               value = 8) |>
    huxtable::set_right_padding(row   = huxtable::everywhere,
                                col   = huxtable::everywhere,
                                value = 8) |>
    huxtable::set_align(row   = 1,
                        col   = c(1, 2, 3, 5),
                        value = "left") |>
    huxtable::set_align(row   = 1,
                        col   = c(4, 6, 7),
                        value = "right") |>
    {\(ht) if (!is.null(font_size)) huxtable::set_font_size(ht, value = font_size) else ht}()
}

#' Table 2: Summary by hypothesis (with header rows)
#' @param table2 data.frame version of table2
#' @param n_digits Number of decimal places for events / sample size
#' @param time_digits Number of decimal places for expected analysis time
#' @param info_fraction_digits Number of decimal places for information fraction
#' @param font_size Font size in points, or NULL to use document default
#' @return huxtable version of table2
#' @export
table2_hux <- function(table2, n_digits = 0, time_digits = 1,
                       info_fraction_digits = 1, font_size = NULL) {
  table2 |>
    dplyr::mutate(
      `Expected analysis time, mo` = sprintf(
        paste0("%-.", time_digits, "f"), .data$`Expected analysis time`
      ),
      `Information fraction, %`    = paste0(
        sprintf(paste0("%-.", info_fraction_digits, "f"),
                .data$`Information fraction` * 100), "%"
      ),
      `Events / sample size`       = round(.data$`Events / sample size`, n_digits)
    ) |>
    dplyr::select(-"Hypothesis", -"Expected analysis time", -"Information fraction") |>
    huxtable::as_hux(add_colnames = TRUE) |>
    huxtable::set_bold(row = 1, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_align(row = huxtable::everywhere, col = c(3, 4, 5), value = "right") |>
    huxtable::set_align(row = huxtable::everywhere, col = c(1, 2), value = "left") |>
    huxtable::set_valign(row = huxtable::everywhere, col = huxtable::everywhere, value = "top") |>
    huxtable::set_wrap(row = huxtable::everywhere, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_width(.hux_width()) |>
    huxtable::set_top_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_bottom_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_caption("Summary of interim analyses by hypothesis") |>
    huxtable::set_header_rows(1, FALSE) |>
    add_hypothesis_headers(table2, 5) ->
    temp
  temp |>
    huxtable::set_bottom_border(row   = nrow(temp),
                                col   = huxtable::everywhere,
                                value = 1) |>
    huxtable::set_left_padding(row   = huxtable::everywhere,
                               col   = huxtable::everywhere,
                               value = 8) |>
    huxtable::set_right_padding(row   = huxtable::everywhere,
                                col   = huxtable::everywhere,
                                value = 8) |>
    huxtable::set_align(row   = 1,
                        col   = c(1, 2),
                        value = "left") |>
    huxtable::set_align(row   = 1,
                        col   = c(3, 4, 5),
                        value = "right") |>
    {\(ht) if (!is.null(font_size)) huxtable::set_font_size(ht, value = font_size) else ht}()
}

#' Table 3: Summary by criteria for conduct
#' @param table3 data.frame version of table3
#' @param n_digits Number of decimal places for events / sample size
#' @param time_digits Number of decimal places for expected analysis time
#' @param info_fraction_digits Number of decimal places for information fraction
#' @param font_size Font size in points, or NULL to use document default
#' @return huxtable version of table3
#' @export
table3_hux <- function(table3, n_digits = 0, time_digits = 1,
                       info_fraction_digits = 1, font_size = NULL) {
  table3 |>
    dplyr::mutate(
      `Information fraction, %` = paste0(
        sprintf(paste0("%-.", info_fraction_digits, "f"),
                .data$`Information fraction` * 100), "%"
      ),
      `Events / sample size`    = round(.data$`Events / sample size`, n_digits)
    ) |>
    dplyr::select(-"Criteria for conduct", -"Expected analysis time", -"Information fraction") |>
    huxtable::as_hux(add_colnames = TRUE) |>
    huxtable::set_bold(row = 1, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_align(row = huxtable::everywhere, col = c(2, 3, 4), value = "right") |>
    huxtable::set_align(row = huxtable::everywhere, col = 1, value = "left") |>
    huxtable::set_valign(row = huxtable::everywhere, col = huxtable::everywhere, value = "top") |>
    huxtable::set_wrap(row = huxtable::everywhere, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_width(.hux_width()) |>
    huxtable::set_top_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_bottom_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_caption("Summary of interim analyses by criteria for conduct") |>
    huxtable::set_header_rows(1, FALSE) |>
    add_criteria_headers(table3, 4, time_digits) ->
    temp
  temp |>
    huxtable::set_bottom_border(row   = nrow(temp),
                                col   = huxtable::everywhere,
                                value = 1) |>
    huxtable::set_left_padding(row   = huxtable::everywhere,
                               col   = huxtable::everywhere,
                               value = 8) |>
    huxtable::set_right_padding(row   = huxtable::everywhere,
                                col   = huxtable::everywhere,
                                value = 8) |>
    huxtable::set_align(row   = 1,
                        col   = 1,
                        value = "left") |>
    huxtable::set_align(row   = 1,
                        col   = c(2, 3, 4),
                        value = "right") |>
    {\(ht) if (!is.null(font_size)) huxtable::set_font_size(ht, value = font_size) else ht}()
}

#' Table 4: Summary of alpha allocation by hypothesis
#' @param table4 data.frame version of table4
#' @param pval_digits Number of decimal places for local alpha level
#' @param font_size Font size in points, or NULL to use document default
#' @return huxtable version of table4
#' @export
table4_hux <- function(table4, pval_digits = 5, font_size = NULL) {
  table4 |>
    dplyr::mutate(
      `Local alpha level` = sprintf(paste0("%-.", pval_digits, "f"),
                                    .data$`Local alpha level`)
    ) |>
    dplyr::select(-"Hypothesis") |>
    huxtable::as_hux(add_colnames = TRUE) |>
    huxtable::set_bold(row = 1, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_align(row = huxtable::everywhere, col = c(1, 2), value = "right") |>
    huxtable::set_align(row = huxtable::everywhere, col = 3, value = "left") |>
    huxtable::set_valign(row = huxtable::everywhere, col = huxtable::everywhere, value = "top") |>
    huxtable::set_wrap(row = huxtable::everywhere, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_width(.hux_width()) |>
    huxtable::set_top_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_bottom_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_caption("Summary of alpha allocation by hypothesis") |>
    huxtable::set_header_rows(1, FALSE) |>
    add_hypothesis_headers(table4, 3) ->
    temp
  temp |>
    huxtable::set_bottom_border(row   = nrow(temp),
                                col   = huxtable::everywhere,
                                value = 1) |>
    huxtable::set_left_padding(row   = huxtable::everywhere,
                               col   = huxtable::everywhere,
                               value = 8) |>
    huxtable::set_right_padding(row   = huxtable::everywhere,
                                col   = huxtable::everywhere,
                                value = 8) |>
    huxtable::set_align(row   = 1,
                        col   = 3,
                        value = "left") |>
    huxtable::set_align(row   = 1,
                        col   = c(1, 2),
                        value = "right") |>
    {\(ht) if (!is.null(font_size)) huxtable::set_font_size(ht, value = font_size) else ht}()
}

#' Table 5: Boundary specifications
#' @param table5 data.frame version of table5
#' @param info_fraction_digits Number of decimal places for information fraction
#' @param pval_digits Number of decimal places for nominal p-value and local alpha level
#' @param hurdle_digits Number of decimal places for exit hurdle
#' @param prob_digits Number of decimal places for local power (as percentage)
#' @param font_size Font size in points, or NULL to use document default
#' @return huxtable version of table5
#' @export
table5_hux <- function(table5, info_fraction_digits = 2, pval_digits = 5,
                       hurdle_digits = 3, prob_digits = 1, font_size = NULL) {
  table5 |>
    dplyr::mutate(
      `Information fraction, %` = paste0(
        sprintf(paste0("%-.", info_fraction_digits, "f"),
                .data$`Information fraction` * 100), "%"
      ),
      `Local alpha level`       = sprintf(paste0("%-.", pval_digits,   "f"), .data$`Local alpha level`),
      `Nominal p-value`         = sprintf(paste0("%-.", pval_digits,   "f"), .data$`Nominal p-value`),
      `Exit hurdle`             = sprintf(paste0("%-.", hurdle_digits, "f"), .data$`Exit hurdle`),
      `Local power`             = paste0(sprintf(paste0("%-.", prob_digits, "f"), .data$`Local power` * 100), "%")
    ) |>
    dplyr::select(-"Hypothesis", -"Information fraction") |>
    huxtable::as_hux(add_colnames = TRUE) |>
    huxtable::set_bold(row = 1, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_align(row = huxtable::everywhere, col = c(2, 3, 4, 5, 6), value = "right") |>
    huxtable::set_align(row = huxtable::everywhere, col = 1, value = "left") |>
    huxtable::set_valign(row = huxtable::everywhere, col = huxtable::everywhere, value = "top") |>
    huxtable::set_wrap(row = huxtable::everywhere, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_width(.hux_width()) |>
    huxtable::set_top_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_bottom_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_caption("Operating characteristics") |>
    huxtable::set_header_rows(1, FALSE) |>
    add_hypothesis_headers(table5, 6) |>
    huxtable::set_left_padding(row = huxtable::everywhere, col = huxtable::everywhere, value = 8) |>
    huxtable::set_right_padding(row = huxtable::everywhere, col = huxtable::everywhere, value = 8) ->
    temp
  # Add borders between local alpha level changes
  # Find where local alpha level changes within each hypothesis group
  for (hyp in unique(table5$Hypothesis)) {
    hyp_data <- table5[table5$Hypothesis == hyp, ]
    alpha_changes <- which(diff(hyp_data$`Local alpha level`) != 0)
    if (length(alpha_changes) > 0) {
      # Account for header rows and previous insertions
      hyp_start_row <- min(which(table5$Hypothesis == hyp))
      offset <- sum(unique(table5$Hypothesis) %in% unique(table5$Hypothesis)[1:which(unique(table5$Hypothesis) == hyp)])
      for (change_pos in alpha_changes) {
        border_row <- hyp_start_row + change_pos + offset + 1  # Added +1 here
        temp <- huxtable::set_top_border(temp, row = border_row, col = huxtable::everywhere, value = 1)
      }
    }
  }
  temp <- huxtable::set_bottom_border(temp, row = nrow(temp), col = huxtable::everywhere, value = 1)
  if (!is.null(font_size)) huxtable::set_font_size(temp, value = font_size) else temp
}

#' Table 6a: Operating characteristics by analysis
#' @param table6a data.frame version of table6a
#' @param prob_digits Number of decimal places for probability (as percentage)
#' @param font_size Font size in points, or NULL to use document default
#' @return huxtable version of table6a
#' @export
table6a_hux <- function(table6a, prob_digits = 1, font_size = NULL) {
  table6a |>
    dplyr::mutate(
      `Probability, %` = paste0(sprintf(paste0("%-.", prob_digits, "f"), .data$Value * 100), "%")
    ) |>
    dplyr::select(-"Value") |>
    huxtable::as_hux(add_colnames = TRUE) |>
    huxtable::set_bold(row = 1, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_align(row = huxtable::everywhere, col = c(1, 4), value = "right") |>
    huxtable::set_align(row = huxtable::everywhere, col = c(2, 3), value = "left") |>
    huxtable::set_valign(row = huxtable::everywhere, col = huxtable::everywhere, value = "top") |>
    huxtable::set_wrap(row = huxtable::everywhere, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_width(.hux_width()) |>
    huxtable::set_top_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_bottom_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_caption("Operating characteristics by analysis") |>
    huxtable::merge_repeated_rows(col = 1:2) |>
    huxtable::set_align(row = 1, col = c(2, 3), value = "left") |>
    huxtable::set_header_rows(1, FALSE) ->
    temp
  # Borders between analysis groups: bottom of last row in group for col 1 (merged),
  # top of first row of new group for cols 2-4
  analysis_group_ends <- which(diff(table6a$Analysis) != 0)  # last data row of each group
  for (r in analysis_group_ends) {
    temp <- huxtable::set_bottom_border(temp, row = r + 1, col = 1,                    value = 1)
    temp <- huxtable::set_top_border(   temp, row = r + 2, col = 2:4,                  value = 1)
  }
  # Borders between metric changes within each group: top border on cols 2-4
  metric_change_rows <- which(
    table6a$Analysis == dplyr::lag(table6a$Analysis) &
    table6a$Metric   != dplyr::lag(table6a$Metric)
  )  # data row indices where Metric changes but Analysis stays the same
  for (r in metric_change_rows) {
    temp <- huxtable::set_top_border(temp, row = r + 1, col = 2:4, value = 1)
  }
  temp |>
    huxtable::set_bottom_border(row = nrow(temp), col = huxtable::everywhere, value = 1) |>
    huxtable::set_left_padding(row = huxtable::everywhere, col = huxtable::everywhere, value = 8) |>
    huxtable::set_right_padding(row = huxtable::everywhere, col = huxtable::everywhere, value = 8) |>
    {\(ht) if (!is.null(font_size)) huxtable::set_font_size(ht, value = font_size) else ht}()
}

#' Table 6b: Operating characteristics across analyses
#' @param table6b data.frame version of table6b
#' @param analysis_digits Number of decimal places for expected analysis index
#' @param time_digits Number of decimal places for expected analysis time
#' @param font_size Font size in points, or NULL to use document default
#' @return huxtable version of table6b
#' @export
table6b_hux <- function(table6b, analysis_digits = 2, time_digits = 1,
                        font_size = NULL) {
  table6b |>
    dplyr::mutate(
      Value = dplyr::case_when(
        grepl("Analysis", Metric) ~ sprintf(paste0("%-.", analysis_digits, "f"), Value),
        grepl("Time",     Metric) ~ sprintf(paste0("%-.", time_digits,    "f"), Value)
      )
    ) |>
    huxtable::as_hux(add_colnames = TRUE) |>
    huxtable::set_bold(row = 1, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_align(row = huxtable::everywhere, col = 3, value = "right") |>
    huxtable::set_align(row = huxtable::everywhere, col = c(1, 2), value = "left") |>
    huxtable::set_valign(row = huxtable::everywhere, col = huxtable::everywhere, value = "top") |>
    huxtable::set_wrap(row = huxtable::everywhere, col = huxtable::everywhere, value = TRUE) |>
    huxtable::set_width(.hux_width()) |>
    huxtable::set_top_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_bottom_border(row = 1, col = huxtable::everywhere, value = 1) |>
    huxtable::set_caption("Operating characteristics across analyses") |>
    huxtable::merge_repeated_rows(col = 1) |>
    huxtable::set_align(row = 1, col = c(1, 2), value = "left") |>
    huxtable::set_header_rows(1, FALSE) ->
    temp
  # Bottom border on col 1 (merged) and top border on cols 2-3 at metric changes
  metric_change_rows <- which(table6b$Metric != dplyr::lag(table6b$Metric))
  for (r in metric_change_rows) {
    temp <- huxtable::set_bottom_border(temp, row = r,     col = 1,   value = 1)
    temp <- huxtable::set_top_border(   temp, row = r + 1, col = 2:3, value = 1)
  }
  temp |>
    huxtable::set_bottom_border(row = nrow(temp), col = huxtable::everywhere, value = 1) |>
    huxtable::set_left_padding(row = huxtable::everywhere, col = huxtable::everywhere, value = 8) |>
    huxtable::set_right_padding(row = huxtable::everywhere, col = huxtable::everywhere, value = 8) |>
    {\(ht) if (!is.null(font_size)) huxtable::set_font_size(ht, value = font_size) else ht}()
}
