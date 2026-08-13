library(appendMCP)

# Regression tests for enrollment-rate pooling in get_info_tite / get_dist_tite.
# Pooling arm-level enrollment down to stratum-level totals must preserve each
# stratum's sequence of enrollment periods. Grouping by (rate, duration) alone
# collapses same-valued periods ACROSS strata (e.g. shared zero-rate lead-ins
# for a sub-study that opens late), so all but the first stratum lose their
# delay and appear to start enrolling at time 0, inflating expected events,
# information, and simulated power.

# Two strata in a sub-study that opens at month 14: two zero-rate lead-in
# periods (6 + 8 months) shared by both strata, then 8 months of enrollment
# with 2:1 (Trt:Control) allocation.
make_enroll <- function() {
  tibble::tibble(
    stratum    = rep(c("S_Bpos", "S_Bpos", "S_Bneg", "S_Bneg"), times = 3),
    treatments = rep(c("Control", "Trt"), times = 6),
    rate       = c(rep(0, 8), 15, 15, 22.5, 22.5),
    duration   = rep(c(6, 8, 8), each = 4),
    ratio      = rep(c(1, 2), times = 6),
    arm_rate   = c(rep(0, 8), 5, 10, 7.5, 15),
    index      = rep(1:3, each = 4)
  ) |>
    dplyr::mutate(stratum_treatment = paste(stratum, treatments, sep = "-"))
}

make_fail <- function() {
  tibble::tibble(
    stratum      = rep(c("S_Bpos", "S_Bneg"), each = 2),
    treatment    = rep(c("Control", "Trt"), times = 2),
    duration     = Inf,
    fail_rate    = rep(c(log(2)/12, log(2)/18), times = 2),
    dropout_rate = 0.001
  )
}

# Reference enrollment with each stratum's 14-month lead-in explicitly kept
enroll_reference <- tibble::tibble(
  stratum  = rep(c("S_Bpos", "S_Bneg"), each = 3),
  duration = rep(c(6, 8, 8), times = 2),
  rate     = c(0, 0, 15, 0, 0, 22.5)
)

test_that("get_info_tite preserves per-stratum enrollment delays", {
  times <- c(30, 40)
  info <- get_info_tite("Control", "Trt", make_enroll(), make_fail(), times)

  # Independent reference: gsDesign2::ahr with the correct stratified enrollment
  fail_reference <- tibble::tibble(
    stratum      = c("S_Bpos", "S_Bneg"),
    duration     = Inf,
    fail_rate    = log(2)/12,
    hr           = (log(2)/18)/(log(2)/12),
    dropout_rate = 0.001
  )
  info_reference <- gsDesign2::ahr(enroll_reference, fail_reference, times, ratio = 2)$info

  expect_equal(info, info_reference, tolerance = 1e-6)
})

test_that("get_dist_tite uses each stratum's own enrollment periods", {
  times <- c(30, 40)
  dist <- get_dist_tite("Control", "Trt", make_enroll(), make_fail(), times)

  fail_dd <- tibble::tibble(
    stratum        = c("S_Bpos", "S_Bneg"),
    duration       = Inf,
    fail_rate      = log(2)/12,
    dropout_rate_c = 0.001,
    dropout_rate_e = 0.001,
    hr             = (log(2)/18)/(log(2)/12)
  )
  ref <- ahr_dd(enroll_reference, fail_dd, times, ratio = 2)

  expect_equal(dist$EZ, -log(ref$ahr)*sqrt(ref$info), tolerance = 1e-6)
  expect_equal(unname(dist$CovZ[1, 2]), sqrt(ref$info[1]/ref$info[2]), tolerance = 1e-6)
})
