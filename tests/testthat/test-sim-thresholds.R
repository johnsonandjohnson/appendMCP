library(appendMCP)

# Regression tests for threshold/analysis alignment in the simulated operating
# characteristics: per-look group-sequential boundaries must be placed at each
# hypothesis's analyses_analysed columns, matching where
# get_maurer_bretz_z_raw_cpp places the observed p-values. A hypothesis whose
# first look is not analysis 1 (e.g. OS tested at analyses 2 & 3) previously
# had its interim boundary written to analysis 1 and its final boundary applied
# at the interim, inflating simulated power above the full-alpha local power.

staggered_config <- list(
  study_name = "staggered_looks", alpha = 0.025, sims = 4000L,
  analyses = tibble::tribble(
    ~endpoint, ~strata,  ~treatments,              ~sample_size, ~events,
    "PFS",     c("All"), c("Control", "Treatment"), NA,          300,
    "PFS",     c("All"), c("Control", "Treatment"), NA,          420,
    "OS",      c("All"), c("Control", "Treatment"), NA,          300),
  hypotheses = tibble::tribble(
    ~type,      ~endpoint, ~strata,  ~control,  ~test,       ~analyses_analysed, ~sf,    ~sfpar, ~nominal, ~test_method,
    "Primary",  "PFS",     c("All"), "Control", "Treatment", 1:2,                "asOF", NULL,   NULL,     "logrank",
    "Primary",  "OS",      c("All"), "Control", "Treatment", 2:3,                "asOF", NULL,   NULL,     "logrank"),
  enroll_rate = tibble::tribble(
    ~stratum, ~treatments,               ~rate, ~duration, ~ratio,
    "All",    c("Control", "Treatment"), 60,    18,        c(1, 1)),
  distribution_tte = tibble::tribble(
    ~endpoint, ~stratum, ~treatment,  ~duration, ~fail_rate, ~dropout_rate,
    "PFS",     "All",    "Control",   Inf,       log(2)/10,  0,
    "PFS",     "All",    "Treatment", Inf,       log(2)/15,  0,
    "OS",      "All",    "Control",   Inf,       log(2)/23,  0,
    "OS",      "All",    "Treatment", Inf,       log(2)/31,  0),
  graph = list(g = rbind(c(0, 1), c(0, 0)), w = c(1, 0)))

set.seed(1)
staggered_result <- process_config(staggered_config)

test_that("thresholds are placed at each hypothesis's analyses_analysed columns", {
  hyp <- process_rejection_rules(
    dplyr::mutate(staggered_result$hypotheses, information = information_factor),
    alpha = staggered_config$alpha
  )

  # H2 (OS, looks at analyses 2 & 3) holding full alpha
  M2 <- update_p_thresholds_cpp(staggered_result$analyses, hyp,
                                staggered_config$graph$g, c(0, 1))
  h2_bounds <- hyp$p_thresholds[hyp$index == 2 & hyp$possible_weight == 1][[1]]
  expect_length(h2_bounds, 2)
  # Interim boundary at analysis 2, final boundary at analysis 3
  expect_equal(M2[2, 2], h2_bounds[1])
  expect_equal(M2[2, 3], h2_bounds[2])
  # H2 has no look at analysis 1: threshold must stay at the -1 sentinel
  expect_equal(M2[2, 1], -1)
  # Sanity: alpha-spending interim boundary is stricter than the final one
  expect_lt(M2[2, 2], M2[2, 3])

  # H1 (PFS, looks at analyses 1 & 2) holding full alpha: placement unchanged,
  # with the final boundary carried forward to analysis 3 to mirror the
  # forward-fill of observed p-values
  M1 <- update_p_thresholds_cpp(staggered_result$analyses, hyp,
                                staggered_config$graph$g, c(1, 0))
  h1_bounds <- hyp$p_thresholds[hyp$index == 1 & hyp$possible_weight == 1][[1]]
  expect_equal(M1[1, 1], h1_bounds[1])
  expect_equal(M1[1, 2], h1_bounds[2])
  expect_equal(M1[1, 3], h1_bounds[2])
})

test_that("simulated power of a late-starting hypothesis respects its local power", {
  # Unconditional (simulated) power can never exceed the hypothesis's local
  # power at full alpha; before the alignment fix, H2's interim was tested
  # against its final-look boundary and exceeded it by ~10 percentage points.
  table5 <- as.data.frame(staggered_result$tables$table5)
  table6a <- as.data.frame(staggered_result$tables$table6a)

  local_h2 <- table5[grepl("H2", table5$Hypothesis), ]
  local_h2 <- local_h2[order(local_h2$Analysis), "Local power"]

  uncond_h2 <- table6a[table6a$Metric == "Power" &
                         table6a$`Hypothesis subset` == "H2", ]
  uncond_h2 <- uncond_h2[order(uncond_h2$Analysis), ]

  expect_equal(uncond_h2$Value[uncond_h2$Analysis == 1], 0)

  mc_tol <- 0.025 # ~3 binomial SDs at 4000 sims; the pre-fix violation was ~0.10
  expect_lte(uncond_h2$Value[uncond_h2$Analysis == 2], local_h2[1] + mc_tol)
  expect_lte(uncond_h2$Value[uncond_h2$Analysis == 3], local_h2[2] + mc_tol)
})
