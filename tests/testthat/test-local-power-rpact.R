# test-local-power-rpact.R
#
# Tier 2: rpact cross-validation of local power for TTE hypotheses.
#
# Validates that appendMCP's local power values (Table 5) agree with an
# independent analytical calculation from rpact::getPowerSurvival() using the
# Schoenfeld method. This directly exercises the info_scale = "h0_info" fix
# in get_boundaries() (commit a365a64).
#
# Config: tests/testthat/fixtures/local_power_validation_config.R
#   Single stratum, 1:4 allocation (Trt:Ctrl), HR=0.55, piecewise hazard,
#   asOF spending. Designed specifically for this validation — not a real study.
#
#   H1 = MRD binary — skipped (rpact binary comparison not in scope here)
#   H2 = OS TTE     — asOF, 3 analyses, 2 weight scenarios (w=0.9, w=1.0)
#
# All inputs to rpact are derived from config and result — no hardcoded numerics
# except TOLERANCE (a design decision, not a config property).
#
# Tolerance: 0.002 (0.2 pp) — consistent with known gsDesign2/rpact rounding
# differences documented in rpact vignette "rpact vs gsDesign" (June 2026).
# Observed max difference: 2e-06.
#
# Skipped on CRAN (requires rpact Suggests dependency).

library(appendMCP)

skip_if_not_installed("rpact")
skip_on_cran()

TOLERANCE <- 0.002

# ── Reference implementation (independent of appendMCP) ───────────────────────
# Computes cumulative local power via rpact::getPowerSurvival() with Schoenfeld
# method. cumsum(rejectPerStage) matches appendMCP's cumulative power column.

rpact_power_tte <- function(alpha_eff, info_rates, sf, gamma,
                            pw_starts, lambda2, hr,
                            max_events, max_subjects,
                            alloc_ratio  = 1,
                            dropout_rate = 0.03,
                            dropout_time = 12) {
  design <- rpact::getDesignGroupSequential(
    sided            = 1,
    alpha            = alpha_eff,
    informationRates = info_rates,
    typeOfDesign     = sf,
    gammaA           = if (is.na(gamma)) NA_real_ else gamma
  )
  res <- rpact::getPowerSurvival(
    design                 = design,
    typeOfComputation      = "Schoenfeld",
    thetaH0                = 1,
    directionUpper         = FALSE,
    hazardRatio            = hr,
    piecewiseSurvivalTime  = pw_starts,
    lambda2                = lambda2,
    dropoutRate1           = dropout_rate,
    dropoutRate2           = dropout_rate,
    dropoutTime            = dropout_time,
    allocationRatioPlanned = alloc_ratio,
    maxNumberOfEvents      = max_events,
    maxNumberOfSubjects    = max_subjects
  )
  cumsum(as.numeric(res$rejectPerStage))
}

# ── Load fixture and run process_config once for the whole file ────────────────

e <- new.env()
source(testthat::test_path("fixtures", "local_power_validation_config.R"), local = e)
config <- e$config

result <- process_config(config)
hyp    <- result$hypotheses

# ── Derive all rpact inputs from config — no hardcoded numerics ───────────────

# H2 is OS TTE — index 2 in hypotheses
hyp_idx     <- 2L
hyp_config  <- config$hypotheses[hyp_idx, ]
h2_rows     <- dplyr::filter(hyp, index == hyp_idx, possible_weight > 0)

# Spending function and parameter
sf    <- hyp_config$sf
gamma <- hyp_config$sfpar[[1]]   # NULL for asOF
gamma <- if (is.null(gamma)) NA_real_ else as.numeric(gamma)

# Control arm distribution: piecewise starts and lambda
ctrl_arm  <- hyp_config$control
test_arm  <- hyp_config$test
dist_ctrl <- config$distribution_tte |>
  dplyr::filter(.data$endpoint == hyp_config$endpoint,
                .data$treatment == ctrl_arm,
                .data$stratum == "All")
dist_trt  <- config$distribution_tte |>
  dplyr::filter(.data$endpoint == hyp_config$endpoint,
                .data$treatment == test_arm,
                .data$stratum == "All")

# pw_starts: cumulative interval starts (rpact convention)
# from durations c(6, Inf) -> finite = c(6) -> starts = c(0, 6)
finite_durs <- dist_ctrl$duration[is.finite(dist_ctrl$duration)]
pw_starts   <- c(0, cumsum(finite_durs))   # c(0, 6)
lambda2     <- dist_ctrl$fail_rate         # control hazard rates per interval

# HR: ratio of test/control fail rate (constant across segments)
hr <- dist_trt$fail_rate[1] / dist_ctrl$fail_rate[1]

# Max events: from the final analysis row for this hypothesis
final_analysis_idx <- max(unlist(hyp_config$analyses_analysed))
max_events         <- as.integer(config$analyses$events[final_analysis_idx])

# Max subjects: total enrolled (both arms)
max_subjects <- as.integer(
  sum(config$enroll_rate$rate * config$enroll_rate$duration)
)

# Allocation ratio: Trt/Ctrl
ratio_vec  <- config$enroll_rate$ratio[[1]]
trt_pos    <- match(test_arm,  config$enroll_rate$treatments[[1]])
ctrl_pos   <- match(ctrl_arm, config$enroll_rate$treatments[[1]])
alloc_ratio <- ratio_vec[trt_pos] / ratio_vec[ctrl_pos]

# Dropout: annual probability back-converted from monthly rate
dropout_annual <- 1 - exp(-dist_ctrl$dropout_rate[1] * 12)

# ── Tests: H2 OS across all non-zero weight scenarios ─────────────────────────

test_that("H2 OS local power matches rpact across all weight scenarios (local_power_validation)", {
  expect_gt(nrow(h2_rows), 0L)

  for (i in seq_len(nrow(h2_rows))) {
    w          <- h2_rows$possible_weight[i]
    info_rates <- unlist(h2_rows$information_fractions[[i]])
    amcp       <- unlist(h2_rows$power[[i]])

    ref <- rpact_power_tte(
      alpha_eff    = config$alpha * w,
      info_rates   = info_rates,
      sf           = sf,
      gamma        = gamma,
      pw_starts    = pw_starts,
      lambda2      = lambda2,
      hr           = hr,
      max_events   = max_events,
      max_subjects = max_subjects,
      alloc_ratio  = alloc_ratio,
      dropout_rate = dropout_annual
    )

    expect_equal(amcp, ref, tolerance = TOLERANCE,
      label = sprintf("H2 OS cumulative power at weight=%.6f", w))
  }
})
