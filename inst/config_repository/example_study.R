# Example study configuration list

example_study_config <- list(
  study_name = "Example Study",
  study_description = "A 3-hypotheses group sequential design",
  alpha = 0.025,
  sims  = 1000L,  # Number of simulations for operating characteristics (default: 1000)

  # Analysis specifications
  analyses = tibble::tribble(
    ~endpoint, ~strata,               ~treatments,    ~sample_size, ~events,  ~power_subsets_any,                                      ~power_subsets_all,
    "CR",      c("Type_A", "Type_B"), c("TRT", "PBO"), 500,          NA,       list("H1, H2"= c(1, 2), "H1, H2, H3" = c(1, 2, 3)),  list("H1, H2, H3" = c(1, 2, 3)),
    "OS",      c("Type_A", "Type_B"), c("TRT", "PBO"), NA,           234,      list("H1, H2"= c(1, 2), "H1, H2, H3" = c(1, 2, 3)),  list("H1, H2, H3" = c(1, 2, 3)),
    "OS",      c("Type_A", "Type_B"), c("TRT", "PBO"), NA,           284,      list("H1, H2"= c(1, 2), "H1, H2, H3" = c(1, 2, 3)),  list("H1, H2, H3" = c(1, 2, 3)),
    "OS",      c("Type_A", "Type_B"), c("TRT", "PBO"), NA,           334,      list("H1, H2"= c(1, 2), "H1, H2, H3" = c(1, 2, 3)),  list("H1, H2, H3" = c(1, 2, 3))
  ),

  # Hypothesis specifications
  hypotheses = tibble::tribble(
    ~type,       ~endpoint, ~strata,              ~control, ~test, ~analyses_analysed, ~sf,     ~sfpar, ~nominal, ~test_method,
    "Primary",   "CR",     c("Type_A", "Type_B"), "PBO",    "TRT", 1,                  "none",  NULL,  NULL,      "unpooled_proportions",
    "Primary",   "OS",     c("Type_A", "Type_B"), "PBO",    "TRT", 1:4,                "asHSD", -1,    0.001,     "logrank",
    "Secondary", "EFS",    c("Type_A", "Type_B"), "PBO",    "TRT", 1:4,                "asHSD", -1,    0.001,     "logrank"
  ),

  # Enrollment rates by strata
  enroll_rate = tibble::tribble(
    ~stratum, ~treatments,     ~rate,      ~duration, ~ratio,
    "Type_A", c("PBO", "TRT"), 0.8*600/28, 28,        c(1, 1),
    "Type_B", c("PBO", "TRT"), 0.2*600/28, 28,        c(1, 1)
  ),

  # Time-to-event distributions (OS, EFS)
  distribution_tte = tibble::tribble(
    ~endpoint, ~stratum, ~treatment, ~duration, ~fail_rate,         ~dropout_rate,
    "EFS",     "Type_A", "PBO",      Inf,       -log(0.33)/24,      -log(1 - 0.1)/12,
    "EFS",     "Type_B", "PBO",      Inf,       -log(0.06)/24,      -log(1 - 0.1)/12,
    "EFS",     "Type_A", "TRT",      Inf,       -0.68*log(0.33)/24, -log(1 - 0.1)/12,
    "EFS",     "Type_B", "TRT",      Inf,       -0.68*log(0.06)/24, -log(1 - 0.1)/12,
    "OS",      "Type_A", "PBO",      Inf,       log(2)/24,          -log(1 - 0.1)/12,
    "OS",      "Type_B", "PBO",      Inf,       log(2)/8,           -log(1 - 0.1)/12,
    "OS",      "Type_A", "TRT",      Inf,       0.69*log(2)/24,     -log(1 - 0.1)/12,
    "OS",      "Type_B", "TRT",      Inf,       0.69*log(2)/8,      -log(1 - 0.1)/12
  ),

  # Binary distributions (CR)
  distribution_bin = tibble::tribble(
    ~endpoint, ~stratum, ~treatment, ~rate,       ~maturity_time,
    "CR",      "Type_A", "PBO",      0.50,        100/(600/28),
    "CR",      "Type_B", "PBO",      0.40,        100/(600/28),
    "CR",      "Type_A", "TRT",      0.50 + 0.15, 100/(600/28),
    "CR",      "Type_B", "TRT",      0.40 + 0.15, 100/(600/28)
  ),

  # Graphical test procedure
  graph = list(
    g = rbind(c(0, 1, 0),
              c(0, 0, 1),
              c(1, 0, 0)),
    w = c(0.4, 0.6, 0)
  )
)
