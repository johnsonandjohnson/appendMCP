# Configuration Guide for appendMCP

``` r

library(appendMCP)
#> ---------------------------------------------------------------------------------------------------------
#> appendMCP: Tools for defining graphical multiple testing procedures in group-sequentially designed trials
#> ---------------------------------------------------------------------------------------------------------
#>                                                             _   __  __    _____   _____
#>                                                            | | |  \/  |  / ____| |  __ \
#>                   __ _   _ __    _ __     ___   _ __     __| | | \  / | | |      | |__) |
#>                  / _` | | '_ \  | '_ \   / _ \ | '_ \   / _` | | |\/| | | |      |  ___/
#>                 | (_| | | |_) | | |_) | |  __/ | | | | | (_| | | |  | | | |____  | |
#>                  \__,_| | .__/  | .__/   \___| |_| |_|  \__,_| |_|  |_|  \_____| |_|
#>                         | |     | |
#>                         |_|     |_|
#>     
#> ---------------------------------------------------------------------------------------------------------
#> 
#> v0.3.0: For an overview of the package's functionality enter: ?appendMCP
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
library(knitr)
library(purrr)
```

## Introduction

This vignette provides a comprehensive guide to configuring studies in
the `appendMCP` package. We’ll examine each component of the
configuration object using the built-in example study to understand the
structure and meaning of all data elements.

## Configuration Overview

A complete study configuration consists of 9 main components:

``` r

# Load the example configuration
data("example_study_config")
config <- example_study_config

# Display the top-level structure
names(config)
#> [1] "study_name"        "study_description" "alpha"            
#> [4] "analyses"          "hypotheses"        "enroll_rate"      
#> [7] "distribution_tte"  "distribution_bin"  "graph"
```

Let’s examine each component in detail:

## 1. Study Metadata

### Study Name and Description

``` r

cat("Study Name:", config$study_name, "\n")
#> Study Name: Example Study
cat("Description:", config$study_description, "\n")
#> Description: A 3-hypotheses group sequential design
cat("Alpha Level:", config$alpha, "\n")
#> Alpha Level: 0.025
```

**Fields:** - `study_name`: Character string identifying the study -
`study_description`: Brief description of the study design - `alpha`:
Overall Type I error rate (typically 0.025 for one-sided tests)

## 2. Analyses Specification

The `analyses` data frame defines when analyses will be conducted. Due
to list columns, we display it in parts:

``` r

# Part 1: Basic trigger columns
kable(config$analyses[,c("endpoint", "strata", "treatments", "sample_size", "events")],
      caption = "Analyses Specification - Part 1: Trigger Conditions")
```

| endpoint | strata         | treatments | sample_size | events |
|:---------|:---------------|:-----------|------------:|-------:|
| CR       | Type_A, Type_B | TRT, PBO   |         500 |     NA |
| OS       | Type_A, Type_B | TRT, PBO   |          NA |    234 |
| OS       | Type_A, Type_B | TRT, PBO   |          NA |    284 |
| OS       | Type_A, Type_B | TRT, PBO   |          NA |    334 |

Analyses Specification - Part 1: Trigger Conditions {.table}

``` r

# Part 2: Power subset specifications (displayed as text due to nested lists)
cat("\nPart 2: Power Subset Specifications\n")
#> 
#> Part 2: Power Subset Specifications
cat("===================================\n")
#> ===================================
for(i in seq_len(nrow(config$analyses))) {
  cat("\nAnalysis", i, "(endpoint:", config$analyses$endpoint[i], "):\n")
  cat("  power_subsets_any:", paste(names(config$analyses$power_subsets_any[[i]]), collapse = ", "), "\n")
  cat("  power_subsets_all:", paste(names(config$analyses$power_subsets_all[[i]]), collapse = ", "), "\n")
}
#> 
#> Analysis 1 (endpoint: CR ):
#>   power_subsets_any: H1 v H2, H1 v H2 v H3 
#>   power_subsets_all: H1,H2,H3 
#> 
#> Analysis 2 (endpoint: OS ):
#>   power_subsets_any: H1 v H2, H1 v H2 v H3 
#>   power_subsets_all: H1,H2,H3 
#> 
#> Analysis 3 (endpoint: OS ):
#>   power_subsets_any: H1 v H2, H1 v H2 v H3 
#>   power_subsets_all: H1,H2,H3 
#> 
#> Analysis 4 (endpoint: OS ):
#>   power_subsets_any: H1 v H2, H1 v H2 v H3 
#>   power_subsets_all: H1,H2,H3
```

**Row Interpretation:**

- Each row represents one planned analysis and describes the conditions
  for an analysis to occur
- Analysis timing (since the first subject randomized) is determined by
  reaching the specified sample size or event count
- Multiple analyses can be conducted for the same endpoint at different
  information levels

**Column Definitions:**

- **`endpoint`**: The endpoint that triggers the analysis (e.g., “CR”,
  “OS”, “EFS”)
- **`strata`**: List of patient strata (or overall population) that
  constitute the sample size (or number of events) that triggers the
  analysis
- **`treatments`**: List of treatment arms whose patients contribute to
  the sample size (or number of events) that triggers the analysis.
  Note: In multi-armed studies, an analysis can be triggered by
  monitoring a subset of treatment arms
- **`sample_size`**: Target sample size for binary endpoints (NA for
  time-to-event)
- **`events`**: Target number of events for time-to-event endpoints (NA
  for binary)
- **`power_subsets_any`**: Named list of hypothesis subsets for “at
  least one rejection” power calculations. Each element is a vector of
  hypothesis indices (e.g., `list("H1, H2" = c(1, 2))` means power to
  reject at least one of H1 or H2)
- **`power_subsets_all`**: Named list of hypothesis subsets for “all
  rejections” power calculations. Each element is a vector of hypothesis
  indices (e.g., `list("H1, H2, H3" = c(1, 2, 3))` means power to reject
  all of H1, H2, and H3)

``` r

# Show the structure of list columns
cat("Strata for Analysis 1:", paste(config$analyses$strata[[1]], collapse = ", "), "\n")
#> Strata for Analysis 1: Type_A, Type_B
cat("Treatments for Analysis 1:", paste(config$analyses$treatments[[1]], collapse = ", "), "\n")
#> Treatments for Analysis 1: TRT, PBO
cat("\nPower subsets (any) for Analysis 1:\n")
#> 
#> Power subsets (any) for Analysis 1:
print(config$analyses$power_subsets_any[[1]])
#> $`H1 v H2`
#> [1] 1 2
#> 
#> $`H1 v H2 v H3`
#> [1] 1 2 3
cat("\nPower subsets (all) for Analysis 1:\n")
#> 
#> Power subsets (all) for Analysis 1:
print(config$analyses$power_subsets_all[[1]])
#> $`H1,H2,H3`
#> [1] 1 2 3
```

## 3. Hypotheses Definition

The `hypotheses` data frame specifies the statistical hypotheses to be
tested. We display all columns in parts:

``` r

# Part 1: Basic hypothesis definition
kable(config$hypotheses[,c("type", "endpoint", "strata", "control", "test")],
      caption = "Hypotheses - Part 1: Basic Definition")
```

| type      | endpoint | strata         | control | test |
|:----------|:---------|:---------------|:--------|:-----|
| Primary   | CR       | Type_A, Type_B | PBO     | TRT  |
| Primary   | OS       | Type_A, Type_B | PBO     | TRT  |
| Secondary | EFS      | Type_A, Type_B | PBO     | TRT  |

Hypotheses - Part 1: Basic Definition {.table}

``` r

# Part 2: Analysis assignments
analyses_info <- data.frame(
  endpoint = config$hypotheses$endpoint,
  analyses_analysed = sapply(config$hypotheses$analyses_analysed,
                             function(x) paste(x, collapse = ", "))
)
kable(analyses_info, caption = "Hypotheses - Part 2: Analysis Assignments")
```

| endpoint | analyses_analysed |
|:---------|:------------------|
| CR       | 1                 |
| OS       | 1, 2, 3, 4        |
| EFS      | 1, 2, 3, 4        |

Hypotheses - Part 2: Analysis Assignments {.table}

``` r

# Part 3: Spending function details
spending_info <- config$hypotheses %>%
  select(endpoint, sf, sfpar, nominal) %>%
  mutate(
    sfpar = sapply(sfpar, function(x) if(is.null(x)) "NULL" else as.character(x)),
    nominal = sapply(nominal, function(x) if(is.null(x)) "NULL" else paste(x, collapse=", "))
  )
kable(spending_info, caption = "Hypotheses - Part 3: Spending Functions")
```

| endpoint | sf    | sfpar | nominal |
|:---------|:------|:------|:--------|
| CR       | none  | NULL  | NULL    |
| OS       | asHSD | -1    | 0.001   |
| EFS      | asHSD | -1    | 0.001   |

Hypotheses - Part 3: Spending Functions {.table}

``` r

# Part 4: Test method
test_info <- config$hypotheses %>%
  select(endpoint, test_method)
kable(test_info, caption = "Hypotheses - Part 4: Test Methods")
```

| endpoint | test_method          |
|:---------|:---------------------|
| CR       | unpooled_proportions |
| OS       | logrank              |
| EFS      | logrank              |

Hypotheses - Part 4: Test Methods {.table}

**Column Definitions:**

- **`type`**: Hypothesis type (“Primary” or “Secondary”)
- **`endpoint`**: Endpoint being tested
- **`strata`**: List of strata for this hypothesis
- **`control`**: Control treatment arm name
- **`test`**: Test treatment arm name
- **`analyses_analysed`**: List or single value specifying which
  analyses (by row index in the `analyses` data frame) test this
  hypothesis
- **`sf`**: Spending function type (“none”, “asHSD”, “asOF”, “asP”,
  “asKD”, “asUser”) for group sequential design
- **`sfpar`**: Spending function parameter (e.g., gamma for HSD; NULL if
  not applicable)
- **`nominal`**: Nominal alpha spending at interim analyses (optional;
  NULL if not specified)
- **`test_method`**: Statistical test method (“logrank”,
  “stratified_logrank”, “unpooled_proportions”, “pooled_proportions”,
  “cmh”)

**Spending Function Types:** - `"none"`: No group sequential testing
(single analysis) - `"asHSD"`: Hwang-Shih-DeCani spending function -
`"asOF"`: O’Brien-Fleming spending function - `"asP"`: Pocock spending
function - `"asKD"`: Kim-DeMets spending function - `"asUser"`:
User-defined spending

**Test Method Types:** - `"logrank"`: Log-rank test for time-to-event
endpoints (unstratified) - `"stratified_logrank"`: Stratified log-rank
test for time-to-event endpoints - `"unpooled_proportions"`: Two-sample
test for proportions (unpooled variance) - `"pooled_proportions"`:
Two-sample test for proportions (pooled variance) - `"cmh"`:
Cochran-Mantel-Haenszel test for stratified binary data

``` r

# Show which analyses test each hypothesis
for(i in seq_len(nrow(config$hypotheses))) {
  cat("Hypothesis", i, "(", config$hypotheses$endpoint[i], "):")
  cat(" Analyses", paste(config$hypotheses$analyses_analysed[[i]], collapse = ", "), "\n")
}
#> Hypothesis 1 ( CR ): Analyses 1 
#> Hypothesis 2 ( OS ): Analyses 1, 2, 3, 4 
#> Hypothesis 3 ( EFS ): Analyses 1, 2, 3, 4
```

## 4. Enrollment Rates

The `enroll_rate` data frame specifies patient enrollment assumptions:

``` r

kable(config$enroll_rate, caption = "Enrollment Rate Specification")
```

| stratum | treatments |      rate | duration | ratio |
|:--------|:-----------|----------:|---------:|:------|
| Type_A  | PBO, TRT   | 17.142857 |       28 | 1, 1  |
| Type_B  | PBO, TRT   |  4.285714 |       28 | 1, 1  |

Enrollment Rate Specification {.table}

**Column Definitions:**

- **`stratum`**: Patient stratum identifier
- **`treatments`**: List of treatment arms for this stratum
- **`rate`**: Enrollment rate (patients per month) for this stratum
- **`duration`**: Enrollment duration (months) for this stratum
- **`ratio`**: Randomization ratio vector for treatment arms (e.g.,
  c(1, 1) for 1:1 randomization)

**Row Interpretation:** - Each row represents enrollment for one
stratum - Total enrollment = rate × duration for each stratum -
Treatments list shows which arms patients in this stratum can be
randomized to

``` r

# Calculate total enrollment
total_enrollment <- sum(config$enroll_rate$rate * config$enroll_rate$duration)
cat("Total Planned Enrollment:", total_enrollment, "patients\n")
#> Total Planned Enrollment: 600 patients

# Show treatment allocation
for(i in seq_len(nrow(config$enroll_rate))) {
  cat("Stratum", config$enroll_rate$stratum[i], "treatments:")
  cat(paste(config$enroll_rate$treatments[[i]], collapse = ", "), "\n")
}
#> Stratum Type_A treatments:PBO, TRT 
#> Stratum Type_B treatments:PBO, TRT
```

## 5. Time-to-Event Distribution Parameters

The `distribution_tte` data frame specifies parameters for time-to-event
endpoints:

``` r

kable(config$distribution_tte, caption = "Time-to-Event Distribution Parameters", digits = 4)
```

| endpoint | stratum | treatment | duration | fail_rate | dropout_rate |
|:---------|:--------|:----------|---------:|----------:|-------------:|
| EFS      | Type_A  | PBO       |      Inf |    0.0462 |       0.0088 |
| EFS      | Type_B  | PBO       |      Inf |    0.1172 |       0.0088 |
| EFS      | Type_A  | TRT       |      Inf |    0.0314 |       0.0088 |
| EFS      | Type_B  | TRT       |      Inf |    0.0797 |       0.0088 |
| OS       | Type_A  | PBO       |      Inf |    0.0289 |       0.0088 |
| OS       | Type_B  | PBO       |      Inf |    0.0866 |       0.0088 |
| OS       | Type_A  | TRT       |      Inf |    0.0199 |       0.0088 |
| OS       | Type_B  | TRT       |      Inf |    0.0598 |       0.0088 |

Time-to-Event Distribution Parameters {.table}

**Column Definitions:**

- **`endpoint`**: Time-to-event endpoint name
- **`stratum`**: Patient stratum
- **`treatment`**: Treatment arm
- **`duration`**: Duration of constant hazard period (Inf = constant
  throughout)
- **`fail_rate`**: Hazard rate (events per month) for this period
- **`dropout_rate`**: Dropout hazard rate (per month)

**Row Interpretation:** - Each row defines hazard rates for one
stratum-treatment-endpoint combination - Multiple rows per combination
allow for piecewise constant hazards - Dropout is assumed constant
across all periods

``` r

# Calculate hazard ratios
tte_summary <- config$distribution_tte %>%
  filter(endpoint == "OS") %>%
  select(stratum, treatment, fail_rate) %>%
  tidyr::pivot_wider(names_from = treatment, values_from = fail_rate) %>%
  mutate(HR = TRT / PBO)

kable(tte_summary, caption = "Hazard Ratios for OS Endpoint", digits = 3)
```

| stratum |   PBO |  TRT |   HR |
|:--------|------:|-----:|-----:|
| Type_A  | 0.029 | 0.02 | 0.69 |
| Type_B  | 0.087 | 0.06 | 0.69 |

Hazard Ratios for OS Endpoint {.table}

## 6. Binary Endpoint Parameters

The `distribution_bin` data frame specifies binary endpoint parameters:

``` r

kable(config$distribution_bin, caption = "Binary Endpoint Parameters", digits = 3)
```

| endpoint | stratum | treatment | rate | maturity_time |
|:---------|:--------|:----------|-----:|--------------:|
| CR       | Type_A  | PBO       | 0.50 |         4.667 |
| CR       | Type_B  | PBO       | 0.40 |         4.667 |
| CR       | Type_A  | TRT       | 0.65 |         4.667 |
| CR       | Type_B  | TRT       | 0.55 |         4.667 |

Binary Endpoint Parameters {.table}

**Column Definitions:**

- **`endpoint`**: Binary endpoint name
- **`stratum`**: Patient stratum
- **`treatment`**: Treatment arm
- **`rate`**: Response rate (probability of success)
- **`maturity_time`**: Time (months) when endpoint can be evaluated

**Row Interpretation:** - Each row defines response rate for one
stratum-treatment-endpoint combination - Maturity time determines when
patients contribute to the analysis - All patients must be followed for
at least maturity_time months

``` r

# Calculate odds ratios
bin_summary <- config$distribution_bin %>%
  select(stratum, treatment, rate) %>%
  tidyr::pivot_wider(names_from = treatment, values_from = rate) %>%
  mutate(
    OR = (TRT / (1 - TRT)) / (PBO / (1 - PBO)),
    Risk_Diff = TRT - PBO
  )

kable(bin_summary, caption = "Treatment Effects for Binary Endpoints", digits = 3)
```

| stratum | PBO |  TRT |    OR | Risk_Diff |
|:--------|----:|-----:|------:|----------:|
| Type_A  | 0.5 | 0.65 | 1.857 |      0.15 |
| Type_B  | 0.4 | 0.55 | 1.833 |      0.15 |

Treatment Effects for Binary Endpoints {.table}

## 7. Graphical Testing Procedure

The `graph` component defines the multiple testing strategy:

``` r

cat("Transition Matrix:\n")
#> Transition Matrix:
print(config$graph$g)
#>      [,1] [,2] [,3]
#> [1,]    0    1    0
#> [2,]    0    0    1
#> [3,]    1    0    0
cat("\nInitial Weights:\n")
#> 
#> Initial Weights:
print(config$graph$w)
#> [1] 0.4 0.6 0.0
```

**Components:**

- **`g`**: Transition matrix (3×3 for 3 hypotheses)
  - Element `g[i,j]` = fraction of alpha from hypothesis i transferred
    to hypothesis j when i is rejected
  - Diagonal elements should be 0
  - Row sums should be ≤ 1
- **`w`**: Initial weight vector
  - Element `w[i]` = initial alpha allocation to hypothesis i
  - Sum should equal 1.0
  - Determines initial local significance levels

``` r

# Verify graph properties
cat("Row sums of transition matrix:", rowSums(config$graph$g), "\n")
#> Row sums of transition matrix: 1 1 1
cat("Sum of initial weights:", sum(config$graph$w), "\n")
#> Sum of initial weights: 1
cat("Initial local alpha levels:", config$alpha * config$graph$w, "\n")
#> Initial local alpha levels: 0.01 0.015 0
```

## Configuration Validation

The package includes validation to ensure configurations are properly
specified:

``` r

# Validate the configuration
is_valid <- validate_config(config)
cat("Configuration is valid:", is_valid, "\n")
#> Configuration is valid: TRUE
```

## Processing the Configuration

Once configured, the study can be processed to generate all analysis
components:

``` r

# Process the configuration
result <- process_config(config)

# Show what gets generated
cat("Generated components:\n")
#> Generated components:
cat(paste("-", names(result), collapse = "\n"), "\n")
#> - analyses
#> - hypotheses
#> - tables
#> - config
#> - graph_figure
#> - information_figure
#> - alpha_spend_figure
#> - timeline_type1_figure
#> - timeline_type2_figure
#> - bin_figure
#> - bin_rd_figure
#> - tte_figure
#> - tte_ahr_figure
#> - tte_cumhaz_figure
#> - tte_dropout_figure
#> - tte_dropout_probability_figure
#> - tte_hazard_figure
#> - tte_hr_figure
#> - tte_median_figure
#> - tte_quantiles_figure
#> - tte_weighted_figure
#> - er_figure
#> - er_cum_figure
```

## Summary

A complete appendMCP configuration requires:

1.  **Study metadata**: Name, description, alpha level
2.  **Analyses schedule**: When analyses occur (by sample size or
    events), with power subset specifications for simulation-based
    operating characteristics
3.  **Hypotheses**: What gets tested, how (spending functions), and
    which test method to use
4.  **Enrollment**: Patient accrual rates by stratum with randomization
    ratios
5.  **TTE distributions**: Survival parameters by stratum/treatment
6.  **Binary distributions**: Response rates by stratum/treatment
7.  **Graph structure**: Multiple testing procedure definition

Each component must be internally consistent and align with the others.
The [`validate_config()`](../reference/validate_config.md) function
helps ensure proper specification before analysis.

## Best Practices

- **Start simple**: Begin with basic designs and add complexity
  gradually
- **Validate early**: Use
  [`validate_config()`](../reference/validate_config.md) frequently
  during development
- **Document assumptions**: Clearly specify all distributional
  assumptions
- **Check consistency**: Ensure enrollment, analyses, and hypotheses
  align
- **Test scenarios**: Try different parameter values to understand
  sensitivity

For more examples and advanced configurations, see the other package
vignettes and documentation.
