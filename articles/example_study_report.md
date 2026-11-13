# Example Study Report - Group Sequential Design with Multiple Testing

## Introduction

With a 28-month accrual period, the total sample size planned for the
study is 600.

## Enrollment

- Piece-wise Constant Enrollment Rates
- Cumulative Enrollment

![](example_study_report_files/figure-html/enrollment_er_figure-1.png)

![](example_study_report_files/figure-html/enrollment_er_cum_figure-1.png)

## Multiplicity Adjustment

The multiplicity strategy follows the graphical approach for group
sequential designs of Maurer and Bretz (2013) which provides strong
control of type 1 error. The procedure takes into account both sources
of multiplicity: multiple hypothesis tests (e.g., across primary and
secondary endpoints) and multiple analyses planned for the study (i.e.,
interim and final analyses).

There are two key components that define this approach:

- Testing algorithm for multiple hypotheses specified by the graphical
  representation
- Repeated testing of some hypotheses using the alpha-spending function
  methodology

The multiplicity strategy will be applied to the 3 hypotheses across CR,
OS, EFS endpoints. The following table summarizes the hypotheses
specifying alpha-spending functions (for hypotheses to be tested group
sequentially) together with the effect sizes and planned maximum
statistical information (sample size or number of events).

**Table 1. Summary of Primary and Key Secondary Hypotheses**

|  |  |  |  |  |  |  |
|----|----|----|---:|----|---:|---:|
| Label | Endpoint | Type | Initial weight | GSD spending fn | Effect size\* | Maximum events / sample size |
| H1 | CR | Primary | 0.4 | N/A | Delta = 15% | 500 |
| H2 | OS | Primary | 0.6 | HSD(-1), with a nominal spend of 0.001 at IA1 | HR = NA | 334 |
| H3 | EFS | Secondary | 0 | HSD(-1), with a nominal spend of 0.001 at IA1 | AHR = 0.68 | 413 |
| \*For a hypothesis corresponding to a time-to-event variable subject to non-proportional hazards, the listed effect size is the average hazard ratio at the final analysis of this hypothesis. |  |  |  |  |  |  |

Trial Design Summary {#tab:table1 .table .huxtable
quarto-disable-processing="true"
style="width: 100%; margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;"}

The overall type I family-wise error rate for 3 hypotheses, over all
(interim and final) analyses, is controlled to 2.5% (one-sided).

## Distribution Assumptions

- Binary Endpoints
- Time-to-Event Endpoints

#### Rates

![](example_study_report_files/figure-html/bin_figure-1.png)

#### Absolute Risk Differences

![](example_study_report_files/figure-html/bin_rd_figure-1.png)

#### Drop-out Rates

![](example_study_report_files/figure-html/tte_dropout_figure-1.png)

#### Cumulative Drop-out Probabilities

![](example_study_report_files/figure-html/tte_dropout_probability_figure-1.png)

#### Hazard Rate

![](example_study_report_files/figure-html/tte_hazard_figure-1.png)

#### Cumulative Hazard

![](example_study_report_files/figure-html/tte_cumhaz_figure-1.png)

#### Survival Curves

![](example_study_report_files/figure-html/tte_figure-1.png)

#### Median Survival

![](example_study_report_files/figure-html/tte_median_figure-1.png)

#### Survival Quantiles

![](example_study_report_files/figure-html/tte_quantiles_figure-1.png)

#### Enrollment Weighted Survival Curves

![](example_study_report_files/figure-html/tte_weighted_figure-1.png)

#### Piece-wise Hazard Ratios

![](example_study_report_files/figure-html/tte_hr_figure-1.png)

#### Average Hazard Ratios

![](example_study_report_files/figure-html/tte_ahr_figure-1.png)

Figure 1 shows the graph where the hypotheses of interest are
represented by the elliptical nodes. Each node has the hypothesis weight
assigned to it (denoted by $`w`$). A particular value of $`w`$ sets the
local significance level associated with that hypothesis (which is equal
to 0.025 × $`w`$). The graphical approach allows local significance
levels to be recycled (along arrows on the graph) when a given
hypothesis is successful (i.e., the corresponding null hypothesis is
rejected) at interim or final analyses.

**Figure 1. Graph Depicting Multiple Hypothesis Testing Strategy**

![](example_study_report_files/figure-html/MTgraph-1.png)

## Interim Analyses

- IA by Hypothesis
- IA by Calendar Time
- Information Flow
- Timeline of Planned Analyses

**Table 2. Summary of Interim Analyses (by hypotheses)**

|  |  |  |  |  |
|----|----|---:|---:|---:|
| Analysis | Criteria for conduct | Events / sample size | Expected analysis time, mo | Information fraction, % |
| H1: CR |  |  |  |  |
| 1 | 500 CR outcomes | 500 | 28.0 | 100.00% |
| H2: OS |  |  |  |  |
| 1 | 500 CR outcomes | 187 | 28.0 | 55.98% |
| 2 | 234 OS events | 234 | 32.8 | 70.06% |
| 3 | 284 OS events | 284 | 39.4 | 85.03% |
| 4 | 334 OS events | 334 | 48.7 | 100.00% |
| H3: EFS |  |  |  |  |
| 1 | 500 CR outcomes | 248 | 28.0 | 60.12% |
| 2 | 234 OS events | 306 | 32.8 | 74.04% |
| 3 | 284 OS events | 362 | 39.4 | 87.70% |
| 4 | 334 OS events | 413 | 48.7 | 100.00% |

Summary of interim analyses by hypothesis {#tab:iaDetailsTableA .table
.huxtable quarto-disable-processing="true"
style="width: 100%; margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;"}

**Table 3. Summary of Interim Analyses (by calendar analysis)**

|  |  |  |  |
|----|---:|---:|---:|
| Hypothesis | Analysis | Events / sample size | Information fraction, % |
| 500 CR outcomes (Expected analysis time: 28.0 mo) |  |  |  |
| H1: CR | 1 | 500 | 100.00% |
| H2: OS | 1 | 187 | 55.98% |
| H3: EFS | 1 | 248 | 60.12% |
| 234 OS events (Expected analysis time: 32.8 mo) |  |  |  |
| H2: OS | 2 | 234 | 70.06% |
| H3: EFS | 2 | 306 | 74.04% |
| 284 OS events (Expected analysis time: 39.4 mo) |  |  |  |
| H2: OS | 3 | 284 | 85.03% |
| H3: EFS | 3 | 362 | 87.70% |
| 334 OS events (Expected analysis time: 48.7 mo) |  |  |  |
| H2: OS | 4 | 334 | 100.00% |
| H3: EFS | 4 | 413 | 100.00% |

Summary of interim analyses by criteria for conduct
{#tab:iaDetailsTableB .table .huxtable quarto-disable-processing="true"
style="width: 100%; margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;"}

**Figure 2. Information Factor Over Time by Hypothesis**

![](example_study_report_files/figure-html/informationPlot-1.png)

**Figure 3. Anticipated study timeline**

![](example_study_report_files/figure-html/timelineType1Plot-1.png)

**Figure 3b. Anticipated time of each analysis, with associated
trigger**

![](example_study_report_files/figure-html/timelineType2Plot-1.png)

## Hypothesis Testing

- Scenarios
- Boundary Specifications
- Operating Characteristics by Analysis
- Operating Characteristics Overall
- Spending Functions

**Table 4. Weight Allocation Scenarios**

|                   |        |                    |
|------------------:|-------:|--------------------|
| Local alpha level | Weight | Testing scenario   |
|            H1: CR |        |                    |
|           0.01000 |    0.4 | Initial allocation |
|           0.02500 |      1 | Successful H2, H3  |
|            H2: OS |        |                    |
|           0.01500 |    0.6 | Initial allocation |
|           0.02500 |      1 | Successful H1      |
|           H3: EFS |        |                    |
|           0.01500 |    0.6 | Successful H2      |
|           0.02500 |      1 | Successful H1, H2  |

Summary of alpha allocation by hypothesis {#tab:graphTable .table
.huxtable quarto-disable-processing="true"
style="width: 100%; margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;"}

**Table 5. Boundary Specifications**

Table 5 details the hypothesis testing at the interim and final
analyses. For hypotheses tested group sequentially, the table provides
the nominal p-value boundary derived from the alpha-spending function
and the information fractions. The timing of analyses is expressed in
terms of statistical information fractions. The table also reports local
power at each analysis time.

|  |  |  |  |  |  |
|----|---:|---:|---:|---:|---:|
| Analysis | Local alpha level | Nominal p-value | Exit hurdle | Local power | Information fraction, % |
| H1: CR |  |  |  |  |  |
| 1 | 0.01000 | 0.01000 | 0.104 | 85.551% | 100.00% |
| 1 | 0.02500 | 0.02500 | 0.088 | 92.379% | 100.00% |
| H2: OS |  |  |  |  |  |
| 1 | 0.01500 | 0.00100 | — | 11.035% | 55.98% |
| 2 | 0.01500 | 0.00865 | — | 43.408% | 70.06% |
| 3 | 0.01500 | 0.00590 | — | 58.080% | 85.03% |
| 4 | 0.01500 | 0.00704 | — | 72.674% | 100.00% |
| 1 | 0.02500 | 0.00100 | — | 11.035% | 55.98% |
| 2 | 0.02500 | 0.01465 | — | 51.262% | 70.06% |
| 3 | 0.02500 | 0.01039 | — | 65.960% | 85.03% |
| 4 | 0.02500 | 0.01248 | — | 79.355% | 100.00% |
| H3: EFS |  |  |  |  |  |
| 1 | 0.01500 | 0.00100 | 0.676 | 47.933% | 60.12% |
| 2 | 0.01500 | 0.00950 | 0.765 | 84.800% | 74.04% |
| 3 | 0.01500 | 0.00753 | 0.775 | 90.837% | 87.70% |
| 4 | 0.01500 | 0.00832 | 0.790 | 94.775% | 100.00% |
| 1 | 0.02500 | 0.00100 | 0.676 | 47.933% | 60.12% |
| 2 | 0.02500 | 0.01593 | 0.782 | 88.990% | 74.04% |
| 3 | 0.02500 | 0.01314 | 0.792 | 93.805% | 87.70% |
| 4 | 0.02500 | 0.01468 | 0.807 | 96.704% | 100.00% |
| Exit hurdle for CPW-weighted log-rank hypotheses is the hazard ratio required after the lag period (6 months) to cross the Z boundary, based on post-lag events only. |  |  |  |  |  |

Operating characteristics {#tab:grSeqTable .table .huxtable
quarto-disable-processing="true"
style="width: 100%; margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;"}

**Table 6a. Operating Characteristics at Each Analysis**

|  |  |  |  |
|---:|----|----|---:|
| Analysis | Metric | Hypothesis subset | Probability, % |
| 1 | Power | H1 | 86.600% |
|  |  | H2 | 10.100% |
|  |  | H3 | 4.500% |
|  | Probability of success for at least one Hi | H1, H2 | 87.500% |
|  |  | H1, H2, H3 | 87.500% |
|  | Probability of success for all Hi | H1, H2, H3 | 4.100% |
| 2 | Power | H1 | 88.700% |
|  |  | H2 | 53.100% |
|  |  | H3 | 47.200% |
|  | Probability of success for at least one Hi | H1, H2 | 92.900% |
|  |  | H1, H2, H3 | 92.900% |
|  | Probability of success for all Hi | H1, H2, H3 | 44.300% |
| 3 | Power | H1 | 89.800% |
|  |  | H2 | 66.300% |
|  |  | H3 | 62.300% |
|  | Probability of success for at least one Hi | H1, H2 | 94.800% |
|  |  | H1, H2, H3 | 94.800% |
|  | Probability of success for all Hi | H1, H2, H3 | 58.000% |
| 4 | Power | H1 | 91.100% |
|  |  | H2 | 79.900% |
|  |  | H3 | 76.800% |
|  | Probability of success for at least one Hi | H1, H2 | 96.900% |
|  |  | H1, H2, H3 | 96.900% |
|  | Probability of success for all Hi | H1, H2, H3 | 71.500% |

Operating characteristics by analysis {#tab:operatingCharByAnalysis
.table .huxtable quarto-disable-processing="true"
style="width: 100%; margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;"}

**Table 6b. Operating Characteristics Across Analyses**

|                                             |                   |       |
|---------------------------------------------|-------------------|------:|
| Metric                                      | Hypothesis subset | Value |
| Expected Success Analysis                   | H1                |  1.09 |
|                                             | H2                |  2.38 |
|                                             | H3                |  2.52 |
| Expected Success Analysis (at least one Hi) | H1, H2            |  1.16 |
|                                             | H1, H2, H3        |  1.16 |
| Expected Success Analysis (for all Hi)      | H1, H2, H3        |  2.51 |
| Expected Success Time                       | H1                |  28.5 |
|                                             | H2                |  36.0 |
|                                             | H3                |  36.8 |
| Expected Success Time (at least one Hi)     | H1, H2            |  28.9 |
|                                             | H1, H2, H3        |  28.9 |
| Expected Success Time (for all Hi)          | H1, H2, H3        |  36.8 |

Operating characteristics across analyses
{#tab:operatingCharAcrossAnalyses .table .huxtable
quarto-disable-processing="true"
style="width: 100%; margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;"}

**Figure 4. Alpha-spending functions**

![](example_study_report_files/figure-html/alphaSpendingPlot-1.png)

## Configuration Details

### Graph Structure

**Table 7. Transition Matrix**

|     |     |     |
|----:|----:|----:|
|   0 |   1 |   0 |
|   0 |   0 |   1 |
|   1 |   0 |   0 |

**Initial Weights:** 0.4, 0.6, 0

### Enrollment Assumptions

**Table 8. Enrollment Rate Assumptions**

| stratum | treatments |  rate | duration | ratio |
|:--------|:-----------|------:|---------:|:------|
| Type_A  | PBO, TRT   | 17.14 |       28 | 1, 1  |
| Type_B  | PBO, TRT   |  4.29 |       28 | 1, 1  |

### Binary Endpoint Assumptions

**Table 9. Binary Endpoint Parameters**

| endpoint | stratum | treatment | rate | maturity_time |
|:---------|:--------|:----------|-----:|--------------:|
| CR       | Type_A  | PBO       | 0.50 |         4.667 |
| CR       | Type_B  | PBO       | 0.40 |         4.667 |
| CR       | Type_A  | TRT       | 0.65 |         4.667 |
| CR       | Type_B  | TRT       | 0.55 |         4.667 |

### Time-to-Event Endpoint Assumptions

**Table 10. Time-to-Event Distribution Parameters**

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

## References

Maurer W, Bretz F. Multiple testing in group sequential trials using
graphical approaches. *Statistics in Biopharmaceutical Research.*
2013;5(4):311-320.

------------------------------------------------------------------------

*Report generated on 2026-11-13 01:29:09.690426*
