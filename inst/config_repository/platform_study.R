study_config <- list(
  study_name        = "platform_study",
  study_description = "Platform trial: TrtA monotherapy vs Control (Part 1), with TrtAB combination added midway (Part 2). Biomarker B+/B- stratification.",
  # alpha is set to 0.025 * 5 to allow power calculations for all 12 hypotheses.
  # The 5 primary hypotheses each receive initial weight 0.2, giving each a local
  # significance level of 0.2 * 0.125 = 0.025 (one-sided). Secondary hypotheses
  # have weight 0 and are not part of the formal FWER-controlled family; the
  # inflated alpha is an accounting device that enables process_config() to
  # compute their power under the graphical procedure.
  alpha             = 0.025 * 5,
  sims              = 5000,

  analyses = tibble::tribble(
    ~endpoint, ~strata,                                          ~treatments,                ~sample_size, ~events,
    "OS",      c("S1_Bpos", "S1_Bneg"),                         c("TrtA",  "Control"),       NA,           333,
    "OS",      c("S1_Bpos", "S1_Bneg"),                         c("TrtA",  "Control"),       NA,           444,
    "OS",      c("S1_Bpos", "S1_Bneg", "S2_Bpos", "S2_Bneg"),  c("TrtAB", "Control"),       NA,           330
  ),

  hypotheses = tibble::tribble(
    ~type,       ~endpoint, ~strata,                                         ~control,   ~test,   ~analyses_analysed, ~sf,     ~sfpar, ~nominal, ~test_method,

    # Part 1: TrtA vs Control (S1 patients only)
    "Primary",   "OS",      c("S1_Bpos", "S1_Bneg"),                        "Control", "TrtA",   1:2,                "asKD",   2.5,    NULL,     "logrank",
    "Secondary", "PFS",     c("S1_Bpos", "S1_Bneg"),                        "Control", "TrtA",    1,                 "none",   NULL,   NULL,     "logrank",

    # Part 2: TrtAB vs Control, pooled (S1+S2 patients)
    "Primary",   "OS",      c("S1_Bpos", "S1_Bneg", "S2_Bpos", "S2_Bneg"), "Control", "TrtAB",  2:3,                "asKD",   2.5,    NULL,     "logrank",
    "Secondary", "EFS",     c("S1_Bpos", "S1_Bneg", "S2_Bpos", "S2_Bneg"), "Control", "TrtAB",   2,                 "none",   NULL,   NULL,     "logrank",
    "Secondary", "PFS",     c("S1_Bpos", "S1_Bneg", "S2_Bpos", "S2_Bneg"), "Control", "TrtAB",   2,                 "none",   NULL,   NULL,     "logrank",
    "Secondary", "TSP",     c("S1_Bpos", "S1_Bneg", "S2_Bpos", "S2_Bneg"), "Control", "TrtAB",  2:3,                "asKD",   2,      NULL,     "logrank",
    "Secondary", "TTE",     c("S1_Bpos", "S1_Bneg", "S2_Bpos", "S2_Bneg"), "Control", "TrtAB",  2:3,                "asKD",   2,      NULL,     "logrank",

    # Part 2: TrtAB vs Control, concurrent (S2 patients only)
    "Primary",   "OS",      c("S2_Bpos", "S2_Bneg"),                        "Control", "TrtAB",  2:3,                "asKD",   2.5,    NULL,     "logrank",
    "Secondary", "PFS",     c("S2_Bpos", "S2_Bneg"),                        "Control", "TrtAB",  2:3,                "asKD",   2.5,    NULL,     "logrank",

    # Part 2: TrtAB vs TrtA (head-to-head, S1+S2)
    "Primary",   "OS",      c("S1_Bpos", "S1_Bneg", "S2_Bpos", "S2_Bneg"), "TrtA",   "TrtAB",  2:3,                "asKD",   2.5,    NULL,     "logrank",
    "Secondary", "PFS",     c("S1_Bpos", "S1_Bneg", "S2_Bpos", "S2_Bneg"), "TrtA",   "TrtAB",  2:3,                "asKD",   2.5,    NULL,     "logrank",

    # B+ biomarker subgroup: TrtAB vs Control (S1_Bpos + S2_Bpos only)
    "Primary",   "OS",      c("S1_Bpos", "S2_Bpos"),                        "Control", "TrtAB",   3,                 "none",   NULL,   NULL,     "logrank"
  ),

  enroll_rate = tibble::tribble(
    ~stratum,    ~treatments,                        ~rate,  ~duration,  ~ratio,
    # S1 strata: enroll only during Part 1 (months 0-14), then stop
    "S1_Bpos",  c("TrtA", "Control"),                13.2,    6.00,      c(2, 1),
    "S1_Bneg",  c("TrtA", "Control"),                19.8,    6.00,      c(2, 1),
    "S1_Bpos",  c("TrtA", "Control"),                23.2,    8.00,      c(2, 1),
    "S1_Bneg",  c("TrtA", "Control"),                34.8,    8.00,      c(2, 1),

    # S2 strata: zero enrollment during Part 1 (placeholder rows required),
    # then enroll from month 14 onwards when TrtAB arm opens
    "S2_Bpos",  c("TrtA", "Control", "TrtAB"),        0,      6.00,      c(1, 1, 4),
    "S2_Bneg",  c("TrtA", "Control", "TrtAB"),        0,      6.00,      c(1, 1, 4),
    "S2_Bpos",  c("TrtA", "Control", "TrtAB"),        0,      8.00,      c(1, 1, 4),
    "S2_Bneg",  c("TrtA", "Control", "TrtAB"),        0,      8.00,      c(1, 1, 4),
    "S2_Bpos",  c("TrtA", "Control", "TrtAB"),       15.0,    8.00,      c(1, 1, 4),
    "S2_Bneg",  c("TrtA", "Control", "TrtAB"),       22.5,    8.00,      c(1, 1, 4)
  ),

  distribution_tte = tibble::tribble(
    ~endpoint, ~stratum,    ~treatment, ~duration, ~fail_rate,                    ~dropout_rate,

    # OS: TrtA vs Control (same HR across all strata)
    "OS",    "S1_Bpos",  "TrtA",     Inf,  0.72 * log(2)/9,   -log(1 - 0.10)/12,
    "OS",    "S1_Bpos",  "Control",  Inf,  1.00 * log(2)/9,   -log(1 - 0.10)/12,
    "OS",    "S1_Bneg",  "TrtA",     Inf,  0.72 * log(2)/9,   -log(1 - 0.10)/12,
    "OS",    "S1_Bneg",  "Control",  Inf,  1.00 * log(2)/9,   -log(1 - 0.10)/12,
    "OS",    "S2_Bpos",  "TrtA",     Inf,  0.72 * log(2)/9,   -log(1 - 0.10)/12,
    "OS",    "S2_Bpos",  "Control",  Inf,  1.00 * log(2)/9,   -log(1 - 0.10)/12,
    "OS",    "S2_Bneg",  "TrtA",     Inf,  0.72 * log(2)/9,   -log(1 - 0.10)/12,
    "OS",    "S2_Bneg",  "Control",  Inf,  1.00 * log(2)/9,   -log(1 - 0.10)/12,

    # OS: TrtAB vs Control
    "OS",    "S1_Bpos",  "TrtAB",    Inf,  0.62 * log(2)/9,   -log(1 - 0.10)/12,
    "OS",    "S1_Bneg",  "TrtAB",    Inf,  0.62 * log(2)/9,   -log(1 - 0.10)/12,
    "OS",    "S2_Bpos",  "TrtAB",    Inf,  0.62 * log(2)/9,   -log(1 - 0.10)/12,
    "OS",    "S2_Bneg",  "TrtAB",    Inf,  0.62 * log(2)/9,   -log(1 - 0.10)/12,

    # PFS: TrtA vs Control
    "PFS",   "S1_Bpos",  "TrtA",     Inf,  0.57 * log(2)/4,   -log(1 - 0.10)/12,
    "PFS",   "S1_Bpos",  "Control",  Inf,  1.00 * log(2)/4,   -log(1 - 0.10)/12,
    "PFS",   "S1_Bneg",  "TrtA",     Inf,  0.57 * log(2)/4,   -log(1 - 0.10)/12,
    "PFS",   "S1_Bneg",  "Control",  Inf,  1.00 * log(2)/4,   -log(1 - 0.10)/12,
    "PFS",   "S2_Bpos",  "TrtA",     Inf,  0.57 * log(2)/4,   -log(1 - 0.10)/12,
    "PFS",   "S2_Bpos",  "Control",  Inf,  1.00 * log(2)/4,   -log(1 - 0.10)/12,
    "PFS",   "S2_Bneg",  "TrtA",     Inf,  0.57 * log(2)/4,   -log(1 - 0.10)/12,
    "PFS",   "S2_Bneg",  "Control",  Inf,  1.00 * log(2)/4,   -log(1 - 0.10)/12,

    # PFS: TrtAB vs Control
    "PFS",   "S1_Bpos",  "TrtAB",    Inf,  0.40 * log(2)/4,   -log(1 - 0.10)/12,
    "PFS",   "S1_Bneg",  "TrtAB",    Inf,  0.40 * log(2)/4,   -log(1 - 0.10)/12,
    "PFS",   "S2_Bpos",  "TrtAB",    Inf,  0.40 * log(2)/4,   -log(1 - 0.10)/12,
    "PFS",   "S2_Bneg",  "TrtAB",    Inf,  0.40 * log(2)/4,   -log(1 - 0.10)/12,

    # EFS: TrtAB vs Control
    "EFS",   "S1_Bpos",  "TrtAB",    Inf,  0.35 * log(2)/2.8, -log(1 - 0.10)/12,
    "EFS",   "S1_Bneg",  "TrtAB",    Inf,  0.35 * log(2)/2.8, -log(1 - 0.10)/12,
    "EFS",   "S2_Bpos",  "TrtAB",    Inf,  0.35 * log(2)/2.8, -log(1 - 0.10)/12,
    "EFS",   "S2_Bneg",  "TrtAB",    Inf,  0.35 * log(2)/2.8, -log(1 - 0.10)/12,
    "EFS",   "S1_Bpos",  "Control",  Inf,  1.00 * log(2)/2.8, -log(1 - 0.10)/12,
    "EFS",   "S1_Bneg",  "Control",  Inf,  1.00 * log(2)/2.8, -log(1 - 0.10)/12,
    "EFS",   "S2_Bpos",  "Control",  Inf,  1.00 * log(2)/2.8, -log(1 - 0.10)/12,
    "EFS",   "S2_Bneg",  "Control",  Inf,  1.00 * log(2)/2.8, -log(1 - 0.10)/12,

    # TSP: TrtAB vs Control
    "TSP",   "S1_Bpos",  "TrtAB",    Inf,  0.55 * log(2)/5.8, -log(1 - 0.10)/12,
    "TSP",   "S1_Bneg",  "TrtAB",    Inf,  0.55 * log(2)/5.8, -log(1 - 0.10)/12,
    "TSP",   "S2_Bpos",  "TrtAB",    Inf,  0.55 * log(2)/5.8, -log(1 - 0.10)/12,
    "TSP",   "S2_Bneg",  "TrtAB",    Inf,  0.55 * log(2)/5.8, -log(1 - 0.10)/12,
    "TSP",   "S1_Bpos",  "Control",  Inf,  1.00 * log(2)/5.8, -log(1 - 0.10)/12,
    "TSP",   "S1_Bneg",  "Control",  Inf,  1.00 * log(2)/5.8, -log(1 - 0.10)/12,
    "TSP",   "S2_Bpos",  "Control",  Inf,  1.00 * log(2)/5.8, -log(1 - 0.10)/12,
    "TSP",   "S2_Bneg",  "Control",  Inf,  1.00 * log(2)/5.8, -log(1 - 0.10)/12,

    # TTE: TrtAB vs Control
    "TTE",   "S1_Bpos",  "TrtAB",    Inf,  0.47 * log(2)/6.8, -log(1 - 0.10)/12,
    "TTE",   "S1_Bneg",  "TrtAB",    Inf,  0.47 * log(2)/6.8, -log(1 - 0.10)/12,
    "TTE",   "S2_Bpos",  "TrtAB",    Inf,  0.47 * log(2)/6.8, -log(1 - 0.10)/12,
    "TTE",   "S2_Bneg",  "TrtAB",    Inf,  0.47 * log(2)/6.8, -log(1 - 0.10)/12,
    "TTE",   "S1_Bpos",  "Control",  Inf,  1.00 * log(2)/6.8, -log(1 - 0.10)/12,
    "TTE",   "S1_Bneg",  "Control",  Inf,  1.00 * log(2)/6.8, -log(1 - 0.10)/12,
    "TTE",   "S2_Bpos",  "Control",  Inf,  1.00 * log(2)/6.8, -log(1 - 0.10)/12,
    "TTE",   "S2_Bneg",  "Control",  Inf,  1.00 * log(2)/6.8, -log(1 - 0.10)/12
  ),

  graph = list(
    g = rbind(
      c(0,   1,    0,   0,      0,    0,   0, 0, 0, 0, 0, 0),
      c(0,   0,    0,   0,      0,    0,   0, 0, 0, 0, 0, 0),
      c(0,   0,    0, 0.1,    0.2,  0.4, 0.3, 0, 0, 0, 0, 0),
      c(0,   0,    0,   0,    0.5,    0, 0.5, 0, 0, 0, 0, 0),
      c(0,   0,    0, 0.5,      0,  0.5,   0, 0, 0, 0, 0, 0),
      c(0,   0,    0,   0,    0.5,    0, 0.5, 0, 0, 0, 0, 0),
      c(0,   0,    0, 0.5,      0,  0.5,   0, 0, 0, 0, 0, 0),
      c(0,   0,    0,   0,      0,    0,   0, 0, 1, 0, 0, 0),
      c(0,   0,    0,   0,      0,    0,   0, 0, 0, 0, 0, 0),
      c(0,   0,    0,   0,      0,    0,   0, 0, 0, 0, 1, 0),
      c(0,   0,    0,   0,      0,    0,   0, 0, 0, 0, 0, 0),
      c(0,   0,    0,   0,      0,    0,   0, 0, 0, 0, 0, 0)
    ),
    w = c(0.2, 0, 0.2, 0, 0, 0, 0, 0.2, 0, 0.2, 0, 0.2),
    plot_params = list(
      nameHypotheses = paste0("H", 1:12),
      wchar = "w",
      x =  c(0,  1,  0,    1, 1, 1, 1, 0,  1, 0, 1, 2),
      y =  c(0,  0,  -1,  -1, -3, -5, -7, -8, -8, -9, -9, -10),
      halfWid = 0.40, halfHgt = 0.3, trhw = 0.05, size = 4, boxtextsize = 3
    )
  )
)
