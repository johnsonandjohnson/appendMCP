config <- list(
  study_name        = "Dual Endpoint Study",
  study_description = "A 3-hypothesis group sequential design with binary and time-to-event endpoints",
  alpha             = 0.025,

  # Analysis specifications
  analyses = tibble::tribble(
    ~endpoint, ~strata,      ~treatments,                  ~sample_size, ~events, ~power_subsets_any,        ~power_subsets_all,
    "MRD",     "A",          c("Arm 1", "Arm 2", "Arm 3"), 875*0.8,      NA,      list("H1 v H2" = c(1, 2)), list("H1, H2" = c(1, 2)),
    "EFS",     c("A", "B"),  c("Arm 1", "Arm 3"),          NA,           288,     list("H1 v H2" = c(1, 2)), list("H1, H2" = c(1, 2)),
    "OS",      c("A", "B"),  c("Arm 1", "Arm 3"),          NA,           246,     list("H1 v H2" = c(1, 2)), list("H1, H2" = c(1, 2)),
    "OS",      c("A", "B"),  c("Arm 1", "Arm 3"),          NA,           270,     list("H1 v H2" = c(1, 2)), list("H1, H2" = c(1, 2))
  ),

  # Hypothesis specifications
  hypotheses = tibble::tribble(
    ~type,       ~endpoint, ~strata,      ~control, ~test,               ~analyses_analysed, ~sf,     ~sfpar, ~nominal, ~test_method,
    "Primary",   "MRD",     "A",          "Arm 3",  c("Arm 1", "Arm 2"), 1,                  "none",  NULL,   NULL,     "pooled_proportions",
    "Primary",   "EFS",     c("A", "B"),  "Arm 3",  "Arm 1",             1:2,                "asOF",  NULL,   NULL,     "logrank",
    "Secondary", "OS",      c("A", "B"),  "Arm 3",  "Arm 1",             1:4,                "asHSD", -1,     NULL,     "logrank"
  ),

  # Enrollment rates by strata
  enroll_rate = tibble::tribble(
    ~stratum, ~treatments,                  ~rate,  ~duration, ~ratio,
    "A",      c("Arm 1", "Arm 2", "Arm 3"), 0.8*22, 875/22,    c(2, 1, 2),
    "B",      c("Arm 1", "Arm 2", "Arm 3"), 0.2*22, 875/22,    c(2, 1, 2)
  ),

  # Time-to-event distributions (EFS, OS)
  distribution_tte = tibble::tribble(
    ~endpoint, ~stratum, ~treatment, ~duration, ~fail_rate,       ~dropout_rate,
    "EFS",     "B",      "Arm 1",    1/30,      0.68*3.835001145, -log(1 - 0.03)/12,
    "EFS",     "B",      "Arm 1",    6 - 1/30,  0.68*0.013891787, -log(1 - 0.03)/12,
    "EFS",     "B",      "Arm 1",    6,         0.68*0.021961546, -log(1 - 0.03)/12,
    "EFS",     "B",      "Arm 1",    12,        0.68*0.022807986, -log(1 - 0.03)/12,
    "EFS",     "B",      "Arm 1",    12,        0.68*0.009815253, -log(1 - 0.03)/12,
    "EFS",     "B",      "Arm 1",    Inf,       0.68*0.005378210, -log(1 - 0.03)/12,
    "EFS",     "B",      "Arm 3",    1/30,      3.835001145,      -log(1 - 0.03)/12,
    "EFS",     "B",      "Arm 3",    6 - 1/30,  0.013891787,      -log(1 - 0.03)/12,
    "EFS",     "B",      "Arm 3",    6,         0.021961546,      -log(1 - 0.03)/12,
    "EFS",     "B",      "Arm 3",    12,        0.022807986,      -log(1 - 0.03)/12,
    "EFS",     "B",      "Arm 3",    12,        0.009815253,      -log(1 - 0.03)/12,
    "EFS",     "B",      "Arm 3",    Inf,       0.005378210,      -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 1",    1/30,      0.68*3.835001145, -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 1",    6 - 1/30,  0.68*0.013891787, -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 1",    6,         0.68*0.021961546, -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 1",    12,        0.68*0.022807986, -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 1",    12,        0.68*0.009815253, -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 1",    Inf,       0.68*0.005378210, -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 3",    1/30,      3.835001145,      -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 3",    6 - 1/30,  0.013891787,      -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 3",    6,         0.021961546,      -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 3",    12,        0.022807986,      -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 3",    12,        0.009815253,      -log(1 - 0.03)/12,
    "EFS",     "A",      "Arm 3",    Inf,       0.005378210,      -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 1",    6,         0.7*0.021305562,  -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 1",    6,         0.7*0.017981494,  -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 1",    12,        0.7*0.016255049,  -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 1",    12,        0.7*0.009495355,  -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 1",    12,        0.7*0.005954914,  -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 1",    Inf,       0.7*0.001557678,  -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 3",    6,         0.021305562,      -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 3",    6,         0.017981494,      -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 3",    12,        0.016255049,      -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 3",    12,        0.009495355,      -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 3",    12,        0.005954914,      -log(1 - 0.03)/12,
    "OS",      "B",      "Arm 3",    Inf,       0.001557678,      -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 1",    6,         0.7*0.021305562,  -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 1",    6,         0.7*0.017981494,  -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 1",    12,        0.7*0.016255049,  -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 1",    12,        0.7*0.009495355,  -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 1",    12,        0.7*0.005954914,  -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 1",    Inf,       0.7*0.001557678,  -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 3",    6,         0.021305562,      -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 3",    6,         0.017981494,      -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 3",    12,        0.016255049,      -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 3",    12,        0.009495355,      -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 3",    12,        0.005954914,      -log(1 - 0.03)/12,
    "OS",      "A",      "Arm 3",    Inf,       0.001557678,      -log(1 - 0.03)/12
  ),

  # Binary distributions (MRD)
  distribution_bin = tibble::tribble(
    ~endpoint, ~stratum, ~treatment, ~rate,        ~maturity_time,
    "MRD",     "A",      "Arm 1",    0.425 + 0.15, 2,
    "MRD",     "A",      "Arm 2",    0.425 + 0.15, 2,
    "MRD",     "A",      "Arm 3",    0.425,        2
  ),

  # Graphical test procedure
  graph = list(
    g = rbind(c(0, 1, 0),
              c(0, 0, 1),
              c(1, 0, 0)),
    w = c(0.005, 0.045, 0)/0.05
  )
)
