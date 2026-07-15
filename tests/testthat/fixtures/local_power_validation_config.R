# local_power_validation_config.R
#
# Minimal single-stratum config for rpact cross-validation of local power.
#
# Design choices:
#   - Single stratum "All" — rpact comparison is unconditionally valid
#     (no strata weighting needed; rpact handles single-population designs)
#   - 1:4 allocation (Trt:Ctrl) — exercises unequal allocation in get_boundaries()
#   - HR = 0.55 — strong effect, clearly non-null power values
#   - Piecewise exponential control (2 segments: h=0.025 for t<6, h=0.010 for t>=6)
#   - H1: binary (MRD) — single analysis, second node for graph (required; appendMCP
#     does not support single-hypothesis graphs)
#   - H2: OS TTE — asOF spending, 3 analyses
#   - Graph: serial H1 -> H2, w = (0.1, 0.9)
#   - N=1000 (rate=50/mo x 20mo), 1:4 → 200 Trt + 800 Ctrl
#   - Events at ~33%/60%/83% of 240 max: 80/144/200
#   - sims = 10L — minimal, just enough for process_config() to complete
#
# NOT a real study design. Exists solely as a validation fixture for testthat.
# The rpact cross-validation targets H2 (OS TTE) only.

config <- list(
  study_name = "local_power_validation",
  alpha      = 0.025,
  sims       = 10L,

  analyses = tibble::tribble(
    ~endpoint, ~strata, ~treatments,      ~sample_size, ~events, ~power_subsets_any, ~power_subsets_all,
    "MRD",     "All",   c("Trt", "Ctrl"), 1000,         NA,      list("H1" = 1L),    list("H1" = 1L),
    "OS",      "All",   c("Trt", "Ctrl"), NA,           80,      list("H2" = 2L),    list("H2" = 2L),
    "OS",      "All",   c("Trt", "Ctrl"), NA,           144,     list("H2" = 2L),    list("H2" = 2L),
    "OS",      "All",   c("Trt", "Ctrl"), NA,           200,     list("H2" = 2L),    list("H2" = 2L)
  ),

  hypotheses = tibble::tribble(
    ~type,     ~endpoint, ~strata, ~control, ~test,  ~analyses_analysed, ~sf,    ~sfpar, ~nominal, ~test_method,
    "Primary", "MRD",     "All",   "Ctrl",   "Trt",  1,                  "none", NULL,   NULL,     "pooled_proportions",
    "Primary", "OS",      "All",   "Ctrl",   "Trt",  2:4,                "asOF", NULL,   NULL,     "logrank"
  ),

  enroll_rate = tibble::tribble(
    ~stratum, ~treatments,       ~rate, ~duration, ~ratio,
    "All",    c("Trt", "Ctrl"),  50,    20,         c(1, 4)   # 1:4 allocation, N=1000 total
  ),

  distribution_tte = tibble::tribble(
    ~endpoint, ~stratum, ~treatment, ~duration, ~fail_rate,        ~dropout_rate,
    "OS",      "All",    "Ctrl",     6,         0.025,             -log(1 - 0.20) / 12,
    "OS",      "All",    "Ctrl",     Inf,       0.010,             -log(1 - 0.20) / 12,
    "OS",      "All",    "Trt",      6,         0.025 * 0.55,      -log(1 - 0.20) / 12,
    "OS",      "All",    "Trt",      Inf,       0.010 * 0.55,      -log(1 - 0.20) / 12
  ),

  distribution_bin = tibble::tribble(
    ~endpoint, ~stratum, ~treatment, ~rate,  ~maturity_time,
    "MRD",     "All",    "Ctrl",     0.30,   2,
    "MRD",     "All",    "Trt",      0.50,   2
  ),

  graph = list(
    g = rbind(c(0, 1),
              c(0, 0)),
    w = c(0.1, 0.9)
  )
)
