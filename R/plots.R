#' Get consistent treatment colors
#' @param treatments Character vector of treatment names
#' @return Named vector of colors
get_treatment_colors <- function(
  treatments
) {
  okabe_ito <- c("#000000", "#E69F00", "#56B4E9", "#009E73", "#F0E442",
                 "#0072B2", "#D55E00", "#CC79A7", "#999999")
  n        <- length(treatments)
  if (n <= length(okabe_ito)) {
    colors <- okabe_ito[seq_len(n)]
  } else {
    colors <- grDevices::rainbow(n)
  }
  rlang::set_names(colors, treatments)
}

#' Create multiplicity graph visualization
#'
#' Generates a visual representation of a graphical multiple comparison
#' procedure using the gMCPLite package. The graph shows hypotheses as nodes
#' with their initial alpha weights and transition probabilities between
#' hypotheses.
#'
#' @param graph A list containing graph structure with elements:
#'   \describe{
#'     \item{g}{Square matrix of transition probabilities between hypotheses}
#'     \item{w}{Numeric vector of initial alpha weights for each hypothesis}
#'   }
#'
#' @return A graph object from \code{\link[gMCPLite]{hGraph}} that can be
#' plotted
#'
#' @details
#' The function validates the input graph structure and creates a visual
#' representation where:
#' \itemize{
#'   \item Nodes represent hypotheses with their alpha weights
#'   \item Edges show transition probabilities when hypotheses are rejected
#'   \item Self-loops are automatically handled by gMCPLite
#' }
#'
#' @examples
#' \dontrun{
#' # Create a simple 2-hypothesis graph
#' graph <- list(
#'   g = matrix(c(0, 1, 1, 0), nrow = 2),
#'   w = c(0.025, 0.025)
#' )
#' fig   <- plot_graph(graph)
#' plot(fig)
#' }
#'
#' @seealso \code{\link[gMCPLite]{hGraph}} for the underlying visualization
#' function
#'
#' @export
plot_graph <- function(
  graph
) {
  # Extract custom hGraph parameters if provided in config
  hgraph_params <- graph$plot_params

  # Default parameters
  default_params <- list(
    nHypotheses     = ncol(graph$g),
    alphaHypotheses = graph$w,
    m               = graph$g,
    wchar           = "w"
  )

  # Merge custom parameters with defaults (custom params override defaults)
  if (!is.null(hgraph_params)) {
    params <- utils::modifyList(default_params, hgraph_params)
  } else {
    params <- default_params
  }

  # Call hGraph with merged parameters
  do.call(gMCPLite::hGraph, params)
}

#' Plot information factor or fraction over time for each hypothesis
#' @param config Configuration list
#' @param time_grid Time sequence for plotting
#' @param use_fraction Logical, if TRUE plot information fraction, if FALSE plot information factor
#' @return ggplot object
#' @export
plot_information        <- function(
  config,
  time_grid    = seq(0, 50, 1),
  use_fraction = FALSE
) {
  hypotheses      <- config$hypotheses
  analyses        <- config$analyses
  enroll_rate     <- config$enroll_rate
  distribution    <- config$distribution
  data_to_plot    <- hypotheses |>
    dplyr::select(-c("sf", "sfpar", "nominal")) |>
    dplyr::mutate(
      index     = seq_len(nrow(hypotheses)),
      dist_type = purrr::map_chr(
        .data$endpoint,
        \(en) dplyr::filter(distribution, .data$endpoint == en) |>
          dplyr::pull(.data$dist_type) %>% .[1]
      ),
      .before   = all_of("endpoint")
    ) |>
    dplyr::mutate(
      treatments = purrr::map2(.data$control, .data$test, \(co, te) c(co, te)),
      .after     = all_of("test")
    ) |>
    dplyr::mutate(
      enroll_rate   = purrr::pmap(
        list(.data$strata, .data$control, .data$test),
        \(st, co, te) enroll_rate |>
          dplyr::mutate(rate = purrr::map2_dbl(.data$rate, .data$treatments,
                                               \(r, tr) r/length(tr))) |>
          tidyr::unnest(all_of("treatments")) |>
          dplyr::filter(.data$stratum %in% st &
                          .data$treatments %in% c(co, te)) |>
          dplyr::mutate(stratum_treatment = paste(.data$stratum,
                                                  .data$treatments, sep = "-"))
      ),
      distribution  = purrr::pmap(
        list(.data$dist_type, .data$endpoint, .data$strata, .data$control,
             .data$test),
        \(ty, en, st, co, te) {
          filtered_dist <- dplyr::filter(distribution,
                                        .data$endpoint == en &
                                          .data$stratum %in% st &
                                          .data$treatment %in% c(co, te)) |>
            dplyr::select(-c("dist_type", "endpoint"))

          if (ty == "bin") {
            # Remove TTE-specific columns if they exist
            tte_cols <- c("duration", "fail_rate", "dropout_rate")
            existing_tte_cols <- intersect(tte_cols, names(filtered_dist))
            if (length(existing_tte_cols) > 0) {
              filtered_dist <- dplyr::select(filtered_dist, -all_of(existing_tte_cols))
            }
          } else {
            # Remove binary-specific columns if they exist
            bin_cols <- c("rate", "maturity_time")
            existing_bin_cols <- intersect(bin_cols, names(filtered_dist))
            if (length(existing_bin_cols) > 0) {
              filtered_dist <- dplyr::select(filtered_dist, -all_of(existing_bin_cols))
            }
          }
          filtered_dist
        }
      ),
      maturity_time = purrr::map2_dbl(
        .data$dist_type, .data$distribution,
        \(ty, di) `if`(ty == "bin",
                       di |> dplyr::pull(.data$maturity_time) %>% .[1],
                       NA)
      )
    )  |>
    dplyr::mutate(
      time_since_fpr         = list(time_grid),
      information_factor     = purrr::pmap(
        list(.data$dist_type, .data$enroll_rate, .data$distribution,
             .data$maturity_time, .data$time_since_fpr),
        \(ty, en, di, ma, t) `if`(
          ty == "bin",
          expected_n_at_t(t, ma,
                          dplyr::mutate(en, stratum = .data$stratum_treatment)),
          expected_d_at_t(t,
                          dplyr::mutate(di, stratum = .data$stratum_treatment),
                          dplyr::mutate(en, stratum = .data$stratum_treatment))
        )
      ),
      max_information_time   = purrr::map(.data$analyses_analysed,
                                          \(an) analyses$time[max(an)]),
      max_information_factor = purrr::pmap(
        list(.data$dist_type, .data$enroll_rate, .data$distribution,
             .data$maturity_time, .data$max_information_time),
        \(ty, en, di, ma, t) `if`(
          ty == "bin",
          expected_n_at_t(t, ma,
                          dplyr::mutate(en, stratum = .data$stratum_treatment)),
          expected_d_at_t(t,
                          dplyr::mutate(di, stratum = .data$stratum_treatment),
                          dplyr::mutate(en, stratum = .data$stratum_treatment))
        )
      ),
      information_fractions  = purrr::map2(
        .data$information_factor, .data$max_information_factor,
        \(inf, minf) inf/minf
      )
    )
  # Create plotting data
  plot_data       <- data_to_plot |>
    dplyr::select("index", "type", "endpoint", "time_since_fpr",
                  "information_factor", "information_fractions") |>
    tidyr::unnest(all_of(c("time_since_fpr", "information_factor",
                           "information_fractions"))) |>
    dplyr::mutate(
      hypothesis =
        paste0("H", .data$index, ": ", .data$type, " ", .data$endpoint),
      y_value    = if (use_fraction) .data$information_fractions else
        .data$information_factor
    )
  # Add enrollment data to plot_data
  enrolled_values <-
    purrr::map_dbl(time_grid, ~gsDesign2::expected_accrual(.x, enroll_rate))
  max_enrolled    <- max(enrolled_values)
  enroll_data     <- tibble::tibble(
    time_since_fpr = time_grid,
    y_value        =
      if (use_fraction) enrolled_values / max_enrolled else enrolled_values,
    hypothesis     = "Randomized"
  )
  combined_data   <- dplyr::bind_rows(plot_data, enroll_data)
  ggplot2::ggplot(combined_data,
                  ggplot2::aes(x     = .data$time_since_fpr,
                               y     = .data$y_value,
                               color = .data$hypothesis)) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::geom_vline(mapping  = ggplot2::aes(xintercept = .data$time),
                        data     = analyses,
                        alpha    = 0.7,
                        color    = "gray50",
                        linetype = "dashed") +
    ggplot2::geom_text(
      mapping = ggplot2::aes(x     = .data$time,
                             y     = 0,
                             label = .data$description_trigger_short),
      data = analyses,
      angle       = 45,
      color       = "black",
      hjust       = 0,
      inherit.aes = FALSE,
      size        = 3,
      vjust       = 0
    ) +
    ggplot2::labs(
      x     = "Time (months)",
      y     =
        if (use_fraction) "Information Fraction" else "Information Factor",
      color = "Legend",
      title = paste("Information", if (use_fraction) "Fraction" else "Factor",
                    "Over Time"),
    ) +
    ggplot2::scale_x_continuous(breaks = seq(0, max(time_grid), 12)) +
    ggplot2::theme_minimal() +
    ggplot2::scale_color_brewer(palette = "Set1",
                                type    = "qual")
}

#' Plot alpha spending functions
#' @param hypotheses Object from process_config(config)$hypotheses
#' @param alpha Type I familywise error-rate
#' @param digits Number of digits for rounding
#' @return ggplot object
#' @export
plot_spending_functions <- function(
  hypotheses,
  alpha  = 0.025,
  digits = 6
) {
  extract_spending_data <- function(hypotheses, alpha) {
    if (is.null(hypotheses)) return(NULL)
    # Extract spending function data
    hypotheses %>%
      dplyr::filter(!is.na(.data$sf), .data$sf != "none") |>
      dplyr::select("index", "endpoint", "description_sf", "possible_weight",
                    "information_fractions", "specs") |>
      dplyr::mutate(
        alpha_spend = purrr::map(.data$specs, \(specs) get_cum_alpha_spend(specs))
      ) |>
      tidyr::unnest(c("information_fractions", "alpha_spend")) |>
      dplyr::mutate(
        hypothesis  = paste0("H", .data$index, ": ", .data$endpoint),
        alpha_level = factor(round(.data$possible_weight * alpha,
                                   digits = digits))
      )
  }
  spending_data         <- extract_spending_data(hypotheses, alpha)
  if (is.null(spending_data) || nrow(spending_data) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(
          mapping = ggplot2::aes(
            x     = 0.5,
            y     = 0.5,
            label = "No spending functions to display"
          ),
          size    = 5) +
        ggplot2::theme_void()
    )
  }
  ggplot2::ggplot(data    = spending_data,
                  mapping = ggplot2::aes(x        = .data$information_fractions,
                                         y        = .data$alpha_spend,
                                         colour   = .data$alpha_level,
                                         linetype = .data$description_sf)) +
    ggplot2::facet_wrap(~ .data$hypothesis, ncol = 1, scales = "free_y") +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::geom_point(size = 2) +
    ggplot2::labs(x        = "Information fraction",
                  y        = "Cumulative alpha spend",
                  colour   = "Alpha level",
                  linetype = "Spending function") +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text        = ggplot2::element_text(size = 10),
      axis.title       = ggplot2::element_text(size = 12),
      legend.direction = "vertical",
      legend.position  = "bottom",
      strip.text       = ggplot2::element_text(size = 12)
    )
}

#' Plot binary endpoint rates
#' @param distribution_bin Binary distribution data frame with columns: endpoint, stratum, treatment, rate
#' @return ggplot object
#' @export
plot_distribution_bin <- function(
  distribution_bin
) {
  if (is.null(distribution_bin) || nrow(distribution_bin) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No binary endpoints"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  distribution_bin |>
    dplyr::mutate(rate_label = paste0(round(.data$rate * 100, 1), "%")) |>
    ggplot2::ggplot(ggplot2::aes(x    = .data$treatment,
                                 y    = 100*.data$rate,
                                 fill = .data$treatment)) +
    ggplot2::geom_bar(stat = "identity") +
    ggplot2::scale_fill_manual(
      values = get_treatment_colors(unique(distribution_bin$treatment))
    ) +
    ggplot2::geom_label(ggplot2::aes(label = .data$rate_label),
                        fill  = "white",
                        size  = 3,
                        vjust = -0.2) +
    ggplot2::facet_grid(
      paste("Strata:", stratum) ~ paste("Endpoint:", endpoint)
    ) +
    ggplot2::ylim(0, 100) +
    ggplot2::labs(x    = "Treatment",
                  y    = "Rate, %",
                  fill = "Treatment") +
    ggplot2::theme_bw() +
    ggplot2::theme(axis.text.x     = ggplot2::element_text(angle = 45,
                                                           hjust = 1),
                   legend.position = "bottom")
}

#' Plot time-to-event survival curves
#' @param distribution_tte Time-to-event distribution data frame with columns: endpoint, stratum, treatment, duration, fail_rate, dropout_rate
#' @param time_grid Time sequence for plotting (default: 0 to 60 months)
#' @param landmark_times Times for survival rate labels (default: 12, 24, 36 months)
#' @return ggplot object
#' @export
plot_distribution_tte <- function(
  distribution_tte,
  time_grid      = seq(0, 60, 0.5),
  landmark_times = c(12, 24, 36)
) {
  if (is.null(distribution_tte) || nrow(distribution_tte) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No time-to-event endpoints"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  distribution_tte |>
    dplyr::group_by(.data$endpoint, .data$stratum, .data$treatment) |>
    dplyr::summarise(
      duration     = list(.data$duration),
      fail_rate    = list(.data$fail_rate),
      .groups      = "drop"
    ) |>
    dplyr::mutate(
      t = list(time_grid),
      S = purrr::pmap(list(.data$duration, .data$fail_rate, .data$t),
                      \(dur, rate, t) gsDesign2::ppwe(t, dur, rate))
    ) |>
    tidyr::unnest(c("t", "S")) ->
    plot_data
  distribution_tte |>
    dplyr::group_by(.data$endpoint, .data$stratum, .data$treatment) |>
    dplyr::summarise(
      duration     = list(.data$duration),
      fail_rate    = list(.data$fail_rate),
      .groups      = "drop"
    ) |>
    dplyr::mutate(
      t = list(landmark_times),
      S = purrr::pmap(list(.data$duration, .data$fail_rate, .data$t),
                      \(dur, rate, t) gsDesign2::ppwe(t, dur, rate))
    ) |>
    tidyr::unnest(c("t", "S")) |>
    dplyr::mutate(
      label = paste0(round(.data$S*100, 1), "%")
    ) ->
    landmark_data
  ggplot2::ggplot(data    = plot_data,
                  mapping = ggplot2::aes(x        = .data$t,
                                         y        = 100*.data$S,
                                         color    = .data$treatment,
                                         linetype = .data$treatment)) +
    ggplot2::geom_line() +
    ggplot2::scale_color_manual(
      values = get_treatment_colors(unique(plot_data$treatment))
    ) +
    ggplot2::geom_label(data          = landmark_data,
                        mapping       = ggplot2::aes(label = .data$label),
                        size          = 2.5,
                        fill          = "white",
                        label.padding = ggplot2::unit(0.15, "lines")) +
    ggplot2::facet_grid(
      paste("Strata:", stratum) ~ paste("Endpoint:", endpoint)
    ) +
    ggplot2::labs(x        = "Time, mo",
                  y        = "Survival probability, %",
                  color    = "Treatment",
                  linetype = "Treatment") +
    ggplot2::scale_x_continuous(breaks = seq(0, max(time_grid), 12)) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "bottom")
}

#' Plot time-to-event hazard rates
#' @param distribution_tte Time-to-event distribution data frame with columns: endpoint, stratum, treatment, duration, fail_rate, dropout_rate
#' @param time_grid Time sequence for plotting (default: 0 to 60 months)
#' @return ggplot object
#' @export
plot_distribution_tte_hazard <- function(
  distribution_tte,
  time_grid = seq(0, 60, 0.5)
) {
  if (is.null(distribution_tte) || nrow(distribution_tte) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No time-to-event endpoints"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  distribution_tte |>
    dplyr::group_by(.data$endpoint, .data$stratum, .data$treatment) |>
    dplyr::summarise(
      duration  = list(.data$duration),
      fail_rate = list(.data$fail_rate),
      .groups   = "drop"
    ) |>
    tidyr::expand_grid(t = time_grid) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      cum_dur = list(cumsum(.data$duration)),
      h       = .data$fail_rate[findInterval(.data$t, c(0, .data$cum_dur))]
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-c("duration", "fail_rate", "cum_dur")) ->
    plot_data
  ggplot2::ggplot(data    = plot_data,
                  mapping = ggplot2::aes(x        = .data$t,
                                         y        = .data$h,
                                         color    = .data$treatment,
                                         linetype = .data$treatment)) +
    ggplot2::geom_line() +
    ggplot2::scale_color_manual(
      values = get_treatment_colors(unique(plot_data$treatment))
    ) +
    ggplot2::facet_grid(
      paste("Strata:", stratum) ~ paste("Endpoint:", endpoint)
    ) +
    ggplot2::labs(x        = "Time, mo",
                  y        = "Hazard rate",
                  color    = "Treatment",
                  linetype = "Treatment") +
    ggplot2::scale_x_continuous(breaks = seq(0, max(time_grid), 12)) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "bottom")
}

plot_timeline_type1       <- function(
  config
) {
  analyses                   <- config$analyses
  hypotheses                 <- config$hypotheses
  enroll_rate                <- config$enroll_rate
  analyses |>
    dplyr::mutate(
      month       = round(.data$time, 0),
      month_label = purrr::map_chr(
        .data$month, \(m) ifelse(m > 0, paste0("~", m, " mo"), "0 mo")
      ),
      # Create text by looking up hypotheses analyzed at each analysis
      text        = purrr::map2_chr(
        .data$hypotheses_analysed, .data$hypotheses_information,
        function(hyp_ids, info_vals) {
          if (length(hyp_ids) == 0) return(NA_character_)
          text_parts <- purrr::map2_chr(hyp_ids, info_vals, \(id, info) {
            hyp_row  <- hypotheses[hypotheses$index == id, ]
            if (nrow(hyp_row) == 0) return("")
            max_info <- hyp_row$max_information_factor[1]
            if_pct   <- round(100 * info / max_info, 0)
            type     <- `if`(hyp_row$dist_type[1] == "bin",
                             "outcomes", "events")
            if (if_pct == 100) {
              paste0(round(info), " ", hyp_row$endpoint[1], " ", type)
            } else {
              paste0(round(info), " ", hyp_row$endpoint[1], " outcomes (",
                     if_pct, "%IF)")
            }
          })
          paste(text_parts[text_parts != ""], collapse = "\n")
        }
      ),
      milestone   = c(paste0("IA", seq_len(nrow(analyses) - 1)), "FA")
    ) |>
    # Add FPR at time 0
    dplyr::add_row(
      month       = 0,
      month_label = "0 mo",
      milestone   = "FPR",
      text        = NA_character_,
      .before     = 1
    ) |>
    dplyr::select("month", "month_label", "text", "milestone") ->
    df_milestone
  enroll_rate |>
    dplyr::group_by(.data$stratum, .data$treatments) |>
    dplyr::summarise(enrollment_duration = sum(.data$duration), .groups = "drop") |>
    dplyr::pull(.data$enrollment_duration) |>
    max() ->
    lpr_time
  # Add LPR to df_milestone
  df_milestone |>
    dplyr::add_row(
      month       = round(lpr_time, 0),
      month_label = paste0("~", round(lpr_time, 0), " mo"),
      milestone   = "LPR",
      text        = NA_character_
    ) |>
    dplyr::group_by(.data$month) |>
    dplyr::summarise(
      month_label = dplyr::first(.data$month_label),
      milestone   = paste(.data$milestone[!is.na(.data$milestone)], collapse = " & "),
      text        = paste(.data$text[!is.na(.data$text)], collapse = "\n"),
      .groups     = "drop"
    ) |>
    dplyr::mutate(text = dplyr::if_else(.data$text == "", NA_character_, .data$text)) |>
    dplyr::arrange(.data$month) ->
    df_milestone
  break_start                <- 3
  break_end                  <-
    min(df_milestone$month[df_milestone$month > 0]) - 1
  break_length               <- 2
  df_milestone |>
    dplyr::mutate(
      month_compressed = dplyr::case_when(
        .data$month <= break_start ~ .data$month,
        .data$month >= break_end   ~ .data$month - (break_end - break_start) + break_length,
        TRUE                 ~ break_start + (.data$month - break_start)*break_length/
          (break_end - break_start)
      )
    ) ->
    df_milestone_compressed
  fpr_pos                    <- 0  # FPR is at month 0
  first_milestone_compressed <-
    df_milestone_compressed$month_compressed[df_milestone_compressed$milestone != "FPR"][1]
  dot_center                 <- (fpr_pos + first_milestone_compressed)/2
  ggplot2::ggplot(df_milestone_compressed,
                  ggplot2::aes(x     = .data$month_compressed,
                               y     = 0,
                               label = .data$milestone)) +
    ggplot2::theme_classic() +
    ggplot2::geom_segment(mapping = ggplot2::aes(x    = 0,
                                                 xend = dot_center - 0.4,
                                                 y    = 0,
                                                 yend = 0),
                          color     = "firebrick",
                          linewidth = 0.5) +
    ggplot2::geom_point(mapping     = ggplot2::aes(x = .data$x,
                                                   y = .data$y),
                        data        = data.frame(x = seq(dot_center - 0.3,
                                                         dot_center + 0.3,
                                                         length.out = 3),
                                                 y = 0),
                        color       = "firebrick",
                        inherit.aes = FALSE,
                        size        = 1) +
    ggplot2::geom_segment(
      mapping   = ggplot2::aes(x    = dot_center + 0.4,
                               xend = 1.05*max(.data$month_compressed),
                               y    = 0,
                               yend = 0),
      arrow     = grid::arrow(length = grid::unit(0.25, "cm")),
      color     = "firebrick",
      linewidth = 0.5) +
    ggplot2::ylim(-0.02, 0.06) +
    ggplot2::geom_point(mapping = ggplot2::aes(y = 0),
                        color   = "dodgerblue4",
                        size    = 3) +
    ggplot2::geom_text(mapping  = ggplot2::aes(x     = .data$month_compressed,
                                               y     = -0.01,
                                               label = .data$month_label),
                       color    = "black",
                       fontface = "bold",
                       size     = 2.5) +
    ggrepel::geom_label_repel(
      mapping            = ggplot2::aes(x     = .data$month_compressed,
                                        y     = 0,
                                        label = .data$text),
      color              = "dodgerblue4",
      data               = df_milestone_compressed,
      direction          = "y",
      fill               = "white",
      label.size         = NA,
      min.segment.length = 0,
      segment.color      = "dodgerblue4",
      size               = 2.5,
      ylim               = c(0.025, 0.1)
    ) +
    ggplot2::geom_label(mapping    = ggplot2::aes(x        = .data$month_compressed,
                                                  y        = 0.015,
                                                  label    = .data$milestone),
                        color      = "dodgerblue4",
                        fontface   = "bold",
                        label.size = NA,
                        size       = 3) +
    ggplot2::theme(axis.line.y     = ggplot2::element_blank(),
                   axis.text.y     = ggplot2::element_blank(),
                   axis.title.x    = ggplot2::element_blank(),
                   axis.title.y    = ggplot2::element_blank(),
                   axis.ticks.y    = ggplot2::element_blank(),
                   axis.text.x     = ggplot2::element_blank(),
                   axis.ticks.x    = ggplot2::element_blank(),
                   axis.line.x     = ggplot2::element_blank(),
                   legend.position = "none")
}

plot_timeline_type2 <- function(
  analyses
) {
  analyses |>
    dplyr::select("index", "endpoint", "time", "description_trigger_short") |>
    dplyr::arrange(.data$time) |>
    ggplot2::ggplot(ggplot2::aes(x = .data$time, y = factor(.data$index))) +
    ggplot2::geom_point(color = "steelblue",
                        size  = 3) +
    ggplot2::geom_text(ggplot2::aes(label = .data$description_trigger_short),
                       hjust = -0.05,
                       size  = 3) +
    ggplot2::labs(
      title = "Expected Analysis Timeline",
      x     = "Expected Time (months)",
      y     = "Analysis"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(axis.text.y = ggplot2::element_text(size = 10))
}

#' Plot enrollment rates over time
#' @param enroll_rate Enrollment rate data frame with columns: stratum, treatments, rate, duration, ratio
#' @param time_grid Time sequence for plotting
#' @return ggplot object
#' @export
plot_enroll_rate <- function(
  enroll_rate,
  time_grid = NULL
) {
  if (is.null(enroll_rate) || nrow(enroll_rate) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No enrollment data"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  if (is.null(time_grid)) {
    max_time  <- enroll_rate |>
      dplyr::summarise(max_time = sum(.data$duration), .by = "stratum") |>
      dplyr::pull(.data$max_time) |>
      max()
    time_grid <- seq(0, max_time, 0.5)
  }
  enroll_rate |>
    tidyr::unnest(c("treatments", "proportion")) |>
    dplyr::mutate(arm_rate = .data$rate * .data$proportion) |>
    dplyr::group_by(.data$stratum, .data$treatments) |>
    dplyr::summarise(
      duration = list(.data$duration),
      arm_rate = list(.data$arm_rate),
      .groups  = "drop"
    ) |>
    tidyr::expand_grid(t = time_grid) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      cum_dur = list(cumsum(.data$duration)),
      rate    = .data$arm_rate[findInterval(.data$t, c(0, .data$cum_dur))]
    ) |>
    dplyr::ungroup() |>
    dplyr::select("stratum", treatment = "treatments", "t", "rate") ->
    plot_data
  ggplot2::ggplot(data    = plot_data,
                  mapping = ggplot2::aes(x        = .data$t,
                                         y        = .data$rate,
                                         color    = .data$treatment,
                                         linetype = .data$treatment)) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::scale_color_manual(
      values = get_treatment_colors(unique(plot_data$treatment))
    ) +
    ggplot2::facet_wrap(~ paste("Strata:", stratum)) +
    ggplot2::labs(x        = "Time, mo",
                  y        = "Enrollment rate, pts/mo",
                  color    = "Treatment",
                  linetype = "Treatment") +
    ggplot2::scale_x_continuous(breaks = seq(0, max(time_grid), 12)) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "bottom") +
    ggplot2::ylim(0, NA)
}

#' Plot cumulative enrollment over time
#' @param enroll_rate Enrollment rate data frame
#' @param time_grid Time sequence for plotting
#' @return ggplot object
#' @export
plot_enroll_rate_cumulative <- function(
  enroll_rate,
  time_grid = NULL
) {
  if (is.null(enroll_rate) || nrow(enroll_rate) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No enrollment data"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  if (is.null(time_grid)) {
    max_time  <- enroll_rate |>
      dplyr::summarise(max_time = sum(.data$duration), .by = "stratum") |>
      dplyr::pull(.data$max_time) |>
      max()
    time_grid <- seq(0, max_time, 0.5)
  }
  enroll_rate |>
    tidyr::unnest(c("treatments", "proportion")) |>
    dplyr::mutate(arm_rate = .data$rate * .data$proportion) ->
    enroll_expanded

  # Calculate enrollment for each unique stratum-treatment combination
  unique_combos <- enroll_expanded |>
    dplyr::distinct(.data$stratum, .data$treatments)

  purrr::pmap_dfr(
    list(unique_combos$stratum, unique_combos$treatments),
    \(s, tr) {
      enr_data <- dplyr::filter(enroll_expanded,
                                .data$stratum == s,
                                .data$treatments == tr)
      tibble::tibble(
        stratum = s,
        treatment = tr,
        t = time_grid,
        n = purrr::map_dbl(time_grid, \(time) {
          expected_n_at_t(time, 0, tibble::tibble(
            stratum = s,
            duration = enr_data$duration,
            rate = enr_data$arm_rate
          ))
        })
      )
    }
  ) ->
    plot_data
  plot_data |>
    dplyr::summarise(n = sum(.data$n), .by = c("treatment", "t")) |>
    dplyr::mutate(stratum = "Total across strata") ->
    total_by_arm
  plot_data |>
    dplyr::summarise(n = sum(.data$n), .by = c("stratum", "t")) |>
    dplyr::mutate(treatment = "Total across arms") ->
    total_by_stratum
  plot_data |>
    dplyr::summarise(n = sum(.data$n), .by = "t") |>
    dplyr::mutate(stratum = "Total across strata", treatment = "Total across arms") ->
    total_all
  dplyr::bind_rows(plot_data, total_by_arm, total_by_stratum, total_all) ->
    combined_data
  ggplot2::ggplot(data    = combined_data,
                  mapping = ggplot2::aes(x        = .data$t,
                                         y        = .data$n,
                                         color    = .data$treatment,
                                         linetype = .data$treatment)) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::scale_color_manual(
      values = get_treatment_colors(unique(combined_data$treatment))
    ) +
    ggplot2::facet_wrap(~ paste("Strata:", stratum)) +
    ggplot2::labs(x        = "Time, mo",
                  y        = "Cumulative enrollment, pts",
                  color    = "Treatment",
                  linetype = "Treatment") +
    ggplot2::scale_x_continuous(breaks = seq(0, max(time_grid), 12)) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "bottom")
}

#' Plot cumulative hazard
#' @param distribution_tte Time-to-event distribution data frame
#' @param time_grid Time sequence for plotting
#' @return ggplot object
#' @export
plot_distribution_tte_cumhaz <- function(
  distribution_tte,
  time_grid = seq(0, 60, 0.5)
) {
  if (is.null(distribution_tte) || nrow(distribution_tte) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No time-to-event endpoints"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  distribution_tte |>
    dplyr::group_by(.data$endpoint, .data$stratum, .data$treatment) |>
    dplyr::summarise(
      duration  = list(.data$duration),
      fail_rate = list(.data$fail_rate),
      .groups   = "drop"
    ) |>
    dplyr::mutate(
      t = list(time_grid),
      H = purrr::pmap(list(.data$duration, .data$fail_rate, .data$t),
                      \(dur, rate, t) -log(gsDesign2::ppwe(t, dur, rate)))
    ) |>
    tidyr::unnest(c("t", "H")) ->
    plot_data
  ggplot2::ggplot(data    = plot_data,
                  mapping = ggplot2::aes(x        = .data$t,
                                         y        = .data$H,
                                         color    = .data$treatment,
                                         linetype = .data$treatment)) +
    ggplot2::geom_line() +
    ggplot2::scale_color_manual(
      values = get_treatment_colors(unique(plot_data$treatment))
    ) +
    ggplot2::facet_grid(
      paste("Strata:", stratum) ~ paste("Endpoint:", endpoint)
    ) +
    ggplot2::labs(x        = "Time, mo",
                  y        = "Cumulative hazard",
                  color    = "Treatment",
                  linetype = "Treatment") +
    ggplot2::scale_x_continuous(breaks = seq(0, max(time_grid), 12)) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "bottom")
}

#' Plot enrollment-weighted survival by hypothesis
#' @param hypotheses Hypotheses object from processed config
#' @param distribution_tte Time-to-event distribution data frame
#' @param enroll_rate Enrollment rate data frame
#' @param time_grid Time sequence for plotting
#' @param landmark_times Times for survival rate labels
#' @return ggplot object
#' @export
plot_distribution_tte_weighted <- function(hypotheses,
                                           distribution_tte,
                                           enroll_rate,
                                           time_grid = seq(0, 60, 0.5),
                                           landmark_times = c(12, 24, 36)) {
  hypotheses |>
    dplyr::filter(.data$dist_type == "tte") |>
    dplyr::group_by(.data$index) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup() ->
    tte_hyp
  if (nrow(tte_hyp) == 0) {
    return(ggplot2::ggplot() +
             ggplot2::geom_text(ggplot2::aes(x = 0.5, y = 0.5, label = "No time-to-event hypotheses"), size = 5) +
             ggplot2::theme_void())
  }
  enroll_rate |>
    tidyr::unnest(c("treatments", "proportion")) |>
    dplyr::summarise(
      n   = sum(.data$rate * .data$duration * .data$proportion),
      .by = c("stratum", "treatments")
    ) |>
    dplyr::select("stratum", treatment = "treatments", "n") ->
    sample_sizes
  tte_hyp |>
    dplyr::rowwise() |>
    dplyr::mutate(
      hyp_data = list(
        .data$distribution |>
          dplyr::group_by(.data$stratum, .data$treatment) |>
          dplyr::summarise(
            duration  = list(.data$duration),
            fail_rate = list(.data$fail_rate),
            .groups   = "drop"
          ) |>
          dplyr::mutate(
            t = list(time_grid),
            S = purrr::pmap(list(.data$duration, .data$fail_rate, .data$t),
                            \(dur, rate, t) gsDesign2::ppwe(t, dur, rate))
          ) |>
          tidyr::unnest(c("t", "S")) |>
          dplyr::left_join(sample_sizes, by = c("stratum", "treatment")) |>
          dplyr::summarise(
            S   = sum(.data$S * .data$n) / sum(.data$n),
            .by = c("treatment", "t")
          )
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::mutate(hypothesis = paste0("H", .data$index, ": ", .data$endpoint)) |>
    tidyr::unnest("hyp_data") ->
    weighted_data
  weighted_data |>
    dplyr::filter(.data$t %in% landmark_times) |>
    dplyr::mutate(label = paste0(round(.data$S * 100, 1), "%")) ->
    landmark_data
  ggplot2::ggplot(data    = weighted_data,
                  mapping = ggplot2::aes(x        = .data$t,
                                         y        = 100*.data$S,
                                         color    = .data$treatment,
                                         linetype = .data$treatment)) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::scale_color_manual(
      values = get_treatment_colors(unique(weighted_data$treatment))
    ) +
    ggplot2::geom_label(data    = landmark_data,
                        mapping = ggplot2::aes(label = .data$label),
                        size    = 2.5,
                        fill = "white",
                        label.padding = ggplot2::unit(0.15, "lines")) +
    ggplot2::facet_wrap(~ hypothesis) +
    ggplot2::labs(x        = "Time, mo",
                  y        = "Enrollment weighted survival probability, %",
                  color    = "Treatment",
                  linetype = "Treatment") +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "bottom") +
    ggplot2::scale_x_continuous(breaks = seq(0, max(time_grid), 12))
}

#' Plot dropout rate over time
#' @param distribution_tte Time-to-event distribution data frame
#' @param time_grid Time sequence for plotting
#' @return ggplot object
#' @export
plot_distribution_tte_dropout <- function(
  distribution_tte,
  time_grid = seq(0, 60, 0.5)
) {
  if (is.null(distribution_tte) || nrow(distribution_tte) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No time-to-event endpoints"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  distribution_tte |>
    dplyr::group_by(.data$endpoint, .data$stratum, .data$treatment) |>
    dplyr::summarise(
      duration     = list(.data$duration),
      dropout_rate = list(.data$dropout_rate),
      .groups      = "drop"
    ) |>
    tidyr::expand_grid(t = time_grid) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      cum_dur = list(cumsum(.data$duration)),
      d       = .data$dropout_rate[findInterval(.data$t, c(0, .data$cum_dur))]
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-c("duration", "dropout_rate", "cum_dur")) ->
    plot_data
  ggplot2::ggplot(data    = plot_data,
                  mapping = ggplot2::aes(x        = .data$t,
                                         y        = .data$d,
                                         color    = .data$treatment,
                                         linetype = .data$treatment)) +
    ggplot2::geom_line() +
    ggplot2::scale_color_manual(
      values = get_treatment_colors(unique(plot_data$treatment))
    ) +
    ggplot2::facet_grid(
      paste("Strata:", stratum) ~ paste("Endpoint:", endpoint)
    ) +
    ggplot2::labs(x        = "Time, mo",
                  y        = "Dropout rate",
                  color    = "Treatment",
                  linetype = "Treatment") +
    ggplot2::scale_x_continuous(breaks = seq(0, max(time_grid), 12)) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "bottom") +
    ggplot2::ylim(0, NA)
}

#' Plot dropout patterns
#' @param distribution_tte Time-to-event distribution data frame
#' @param time_grid Time sequence for plotting
#' @return ggplot object
#' @export
plot_distribution_tte_dropout_probability <- function(
  distribution_tte,
  time_grid = seq(0, 60, 0.5)
) {
  if (is.null(distribution_tte) || nrow(distribution_tte) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No time-to-event endpoints"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  distribution_tte |>
    dplyr::group_by(.data$endpoint, .data$stratum, .data$treatment) |>
    dplyr::summarise(
      duration     = list(.data$duration),
      dropout_rate = list(.data$dropout_rate),
      .groups      = "drop"
    ) |>
    dplyr::mutate(
      t = list(time_grid),
      S = purrr::pmap(list(.data$duration, .data$dropout_rate, .data$t),
                      \(dur, rate, t) gsDesign2::ppwe(t, dur, rate,
                                                      lower_tail = TRUE))
    ) |>
    tidyr::unnest(c("t", "S")) ->
    plot_data
  ggplot2::ggplot(data    = plot_data,
                  mapping = ggplot2::aes(x        = .data$t,
                                         y        = 100*.data$S,
                                         color    = .data$treatment,
                                         linetype = .data$treatment)) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::scale_color_manual(
      values = get_treatment_colors(unique(plot_data$treatment))
    ) +
    ggplot2::facet_grid(
      paste("Strata:", stratum) ~ paste("Endpoint:", endpoint)
    ) +
    ggplot2::labs(x        = "Time, mo",
                  y        = "Cumulative drop-out probability, %",
                  color    = "Treatment",
                  linetype = "Treatment") +
    ggplot2::scale_x_continuous(breaks = seq(0, max(time_grid), 12)) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "bottom")
}

#' Plot quantiles
#' @param distribution_tte Time-to-event distribution data frame
#' @return ggplot object
#' @export
plot_distribution_tte_quantiles <- function(
  distribution_tte
) {
  if (is.null(distribution_tte) || nrow(distribution_tte) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No time-to-event endpoints"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  distribution_tte |>
    dplyr::group_by(.data$endpoint, .data$stratum, .data$treatment) |>
    dplyr::summarise(
      duration  = list(.data$duration),
      fail_rate = list(.data$fail_rate),
      .groups   = "drop"
    ) |>
    tidyr::expand_grid(quantile = c(0.25, 0.5, 0.75)) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      time = if (length(.data$fail_rate) == 1) {
        rpact::getPiecewiseExponentialQuantile(
          quantile = .data$quantile,
          piecewiseLambda = .data$fail_rate
        )
      } else {
        rpact::getPiecewiseExponentialQuantile(
          quantile = .data$quantile,
          piecewiseLambda = .data$fail_rate,
          piecewiseSurvivalTime = c(0, cumsum(.data$duration)[-length(.data$duration)])
        )
      }
    ) |>
    dplyr::ungroup() |>
    tidyr::pivot_wider(names_from   = "quantile",
                       values_from  = time,
                       names_prefix = "q") |>
    dplyr::mutate(
      label_q25 = paste0("Q25=", round(.data$q0.25, 1)),
      label_q50 = paste0("Q50=", round(.data$q0.5, 1)),
      label_q75 = paste0("Q75=", round(.data$q0.75, 1))
    ) ->
    quantile_data
  ggplot2::ggplot(quantile_data,
                  ggplot2::aes(x     = .data$treatment,
                               color = .data$treatment)) +
    ggplot2::geom_linerange(ggplot2::aes(ymin = .data$q0.25,
                                         ymax = .data$q0.75),
                            linewidth = 1) +
    ggplot2::geom_point(ggplot2::aes(y = .data$q0.5),
                        size = 3) +
    ggplot2::geom_text(ggplot2::aes(y     = .data$q0.25,
                                    label = .data$label_q25),
                       hjust = 1.2,
                       size = 2.5) +
    ggplot2::geom_text(ggplot2::aes(y     = .data$q0.5,
                                    label = .data$label_q50),
                       hjust = -0.2,
                       size = 2.5) +
    ggplot2::geom_text(ggplot2::aes(y     = .data$q0.75,
                                    label = .data$label_q75),
                       hjust = 1.2,
                       size  = 2.5) +
    ggplot2::scale_color_manual(
      values = get_treatment_colors(unique(quantile_data$treatment))
    ) +
    ggplot2::facet_grid(
      paste("Strata:", stratum) ~ paste("Endpoint:", endpoint)
    ) +
    ggplot2::labs(x     = "Treatment",
                  y     = "Survival time, mo",
                  color = "Treatment") +
    ggplot2::theme_bw() +
    ggplot2::theme(axis.text.x     = ggplot2::element_text(angle = 45,
                                                           hjust = 1),
                   legend.position = "bottom")
}

#' Plot hazard ratio over time by hypothesis
#' @param hypotheses Hypotheses object from processed config
#' @param time_grid Time sequence for plotting
#' @return ggplot object
#' @export
plot_distribution_tte_hr <- function(
  hypotheses,
  time_grid = seq(0, 60, 0.5)
) {
  hypotheses |>
    dplyr::filter(.data$dist_type == "tte") |>
    dplyr::group_by(.data$index) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup() ->
    tte_hyp
  if (nrow(tte_hyp) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No time-to-event hypotheses"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  tte_hyp |>
    dplyr::mutate(
      hr_data = purrr::pmap(
        list(.data$distribution, .data$control, .data$test),
        \(dist, ctrl, tst) {
          wide_data <- tidyr::pivot_wider(
            dist,
            names_from  = "treatment",
            values_from = "fail_rate",
            id_cols     = c("stratum", "duration", "dropout_rate"),
            values_fn   = list
          ) |>
            tidyr::unnest_longer(-("stratum":"dropout_rate"))
          wide_data$hr <- wide_data[[tst]] / wide_data[[ctrl]]
          wide_data |>
            dplyr::group_by(.data$stratum) |>
            dplyr::summarise(
              duration = list(.data$duration),
              hr       = list(.data$hr),
              .groups  = "drop"
            ) |>
            tidyr::expand_grid(t = time_grid) |>
            dplyr::rowwise() |>
            dplyr::mutate(
              cum_dur = list(cumsum(.data$duration)),
              hr_val  = .data$hr[findInterval(.data$t, c(0, .data$cum_dur))]
            ) |>
            dplyr::ungroup() |>
            dplyr::select("stratum", "t", hr = "hr_val")
        }
      )
    ) |>
    dplyr::mutate(
      hypothesis = paste0("H", .data$index, ": ", .data$endpoint)
    ) |>
    tidyr::unnest("hr_data") ->
    plot_data
  ggplot2::ggplot(data    = plot_data,
                  mapping = ggplot2::aes(x = .data$t,
                                         y = .data$hr)) +
    ggplot2::geom_line(linewidth = 1,
                       color     = "steelblue") +
    ggplot2::geom_hline(yintercept = 1,
                        linetype   = "dashed",
                        color      = "red",
                        alpha      = 0.5) +
    ggplot2::facet_grid(paste("Strata:", stratum) ~ hypothesis) +
    ggplot2::labs(x = "Time, mo",
                  y = "Hazard ratio") +
    ggplot2::scale_x_continuous(breaks = seq(0, max(time_grid), 12)) +
    ggplot2::theme_bw()
}

#' Plot average hazard ratio over time by hypothesis
#' @param hypotheses Hypotheses object from processed config
#' @param enroll_rate Enrollment rate data frame
#' @param time_grid Time sequence for plotting
#' @return ggplot object
#' @export
plot_distribution_tte_ahr <- function(
  hypotheses,
  enroll_rate,
  time_grid = seq(0, 60, 0.5)
) {
  hypotheses |>
    dplyr::filter(.data$dist_type == "tte") |>
    dplyr::group_by(.data$index) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup() ->
    tte_hyp
  if (nrow(tte_hyp) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No time-to-event hypotheses"),
                           size = 5) +
             ggplot2::theme_void()
    )
  }
  tte_hyp |>
    dplyr::mutate(
      ahr_data = purrr::pmap(
        list(.data$distribution, .data$enroll_rate, .data$control, .data$test),
        \(dist, enr, ctrl, tst) {
          fail_rate_wide <- tidyr::pivot_wider(
            dist,
            names_from  = "treatment",
            values_from = c("fail_rate", "dropout_rate"),
            id_cols     = c("stratum", "duration"),
            values_fn   = list
          ) |>
            tidyr::unnest_longer(-("stratum":"duration")) %>%
            {tibble::tibble(
              duration       = .$duration,
              fail_rate      = .[[paste0("fail_rate_", ctrl)]],
              dropout_rate_c = .[[paste0("dropout_rate_", ctrl)]],
              dropout_rate_e = .[[paste0("dropout_rate_", tst)]],
              hr             = .[[paste0("fail_rate_", tst)]] / .[[paste0("fail_rate_", ctrl)]],
              stratum        = .$stratum
            )}
          enroll_rate_hyp <- dplyr::group_by(
            enr, .data$stratum, .data$rate, .data$duration
          ) |>
            dplyr::summarise(rate = sum(.data$arm_rate), .groups = "drop")
          ratio_val       <- dplyr::filter(enr, .data$treatments == tst)$ratio[1] /
            dplyr::filter(enr, .data$treatments == ctrl)$ratio[1]
          ahr_dd(enroll_rate_hyp, fail_rate_wide,
                 time_grid[time_grid > 0], ratio_val) |>
            dplyr::select(t = "time", "ahr")
        }
      )
    ) |>
    dplyr::mutate(
      hypothesis = paste0("H", .data$index, ": ", .data$endpoint)
    ) |>
    tidyr::unnest("ahr_data") ->
    plot_data
  ggplot2::ggplot(data    = plot_data,
                  mapping = ggplot2::aes(x = .data$t, y = .data$ahr)) +
    ggplot2::geom_line(linewidth = 1,
                       color = "steelblue") +
    ggplot2::geom_hline(yintercept = 1,
                        linetype   = "dashed",
                        color      = "red",
                        alpha      = 0.5) +
    ggplot2::facet_wrap(~ hypothesis) +
    ggplot2::labs(x = "Time, mo",
                  y = "Average hazard ratio") +
    ggplot2::scale_x_continuous(breaks = seq(0, max(time_grid), 12)) +
    ggplot2::theme_bw()
}

#' Plot risk difference for binary endpoints
#' @param hypotheses Hypotheses object from processed config
#' @return ggplot object
#' @export
plot_distribution_bin_rd <- function(hypotheses) {
  hypotheses |>
    dplyr::filter(.data$dist_type == "bin") |>
    dplyr::group_by(.data$index) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup() ->
    bin_hyp
  if (nrow(bin_hyp) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No binary endpoints"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  bin_hyp |>
    dplyr::mutate(
      rd = .data$test_pooled_rate - .data$control_pooled_rate,
      rd_label = paste0(round(.data$rd * 100, 1), "%"),
      hypothesis = paste0("H", .data$index, ": ", .data$endpoint)
    ) ->
    rd_data
  ggplot2::ggplot(data    = rd_data,
                  mapping = ggplot2::aes(x = .data$hypothesis,
                                         y = 100*.data$rd)) +
    ggplot2::geom_bar(stat = "identity",
                      fill = "steelblue") +
    ggplot2::geom_label(ggplot2::aes(label = .data$rd_label),
                        fill  = "white",
                        size  = 3,
                        vjust = -0.2) +
    ggplot2::geom_hline(alpha      = 0.5,
                        color      = "red",
                        linetype   = "dashed",
                        yintercept = 0) +
    ggplot2::labs(x = "Hypothesis",
                  y = "Absolute risk difference, %") +
    ggplot2::theme_bw() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45,
                                                       hjust = 1))
}

#' Plot median survival time
#' @param distribution_tte Time-to-event distribution data frame
#' @return ggplot object
#' @export
plot_distribution_tte_median <- function(
  distribution_tte
) {
  if (is.null(distribution_tte) || nrow(distribution_tte) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_text(ggplot2::aes(x     = 0.5,
                                        y     = 0.5,
                                        label = "No time-to-event endpoints"),
                           size = 5) +
        ggplot2::theme_void()
    )
  }
  distribution_tte |>
    dplyr::group_by(.data$endpoint, .data$stratum, .data$treatment) |>
    dplyr::summarise(
      duration  = list(.data$duration),
      fail_rate = list(.data$fail_rate),
      .groups   = "drop"
    ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      median_surv = if (length(.data$fail_rate) == 1) {
        rpact::getPiecewiseExponentialQuantile(
          quantile = 0.5,
          piecewiseLambda = .data$fail_rate
        )
      } else {
        rpact::getPiecewiseExponentialQuantile(
          quantile = 0.5,
          piecewiseLambda = .data$fail_rate,
          piecewiseSurvivalTime = c(0, cumsum(.data$duration)[-length(.data$duration)])
        )
      },
      median_label = paste0(round(.data$median_surv, 1), " mo")
    ) |>
    dplyr::ungroup() ->
    median_data
  ggplot2::ggplot(median_data,
                  ggplot2::aes(x    = .data$treatment,
                               y    = .data$median_surv,
                               fill = .data$treatment)) +
    ggplot2::geom_bar(stat = "identity") +
    ggplot2::scale_fill_manual(
      values = get_treatment_colors(unique(median_data$treatment))
    ) +
    ggplot2::geom_label(ggplot2::aes(label = .data$median_label),
                        vjust = -0.2,
                        fill  = "white",
                        size  = 3) +
    ggplot2::facet_grid(
      paste("Strata:", stratum) ~ paste("Endpoint:", endpoint)
    ) +
    ggplot2::labs(x    = "Treatment",
                  y    = "Median survival time, mo",
                  fill = "Treatment") +
    ggplot2::theme_bw() +
    ggplot2::theme(axis.text.x     = ggplot2::element_text(angle = 45,
                                                           hjust = 1),
                   legend.position = "bottom")
}
