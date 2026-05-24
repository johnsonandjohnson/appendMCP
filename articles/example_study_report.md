# Example Study Report - Group Sequential Design with Multiple Testing

## Introduction

With a 28-month accrual period, the total sample size planned for the
study is 600.

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

    #>   ─────────────────────────────────────────────────────
    #>     Label   Endpoint   Type        Initial   GSD       
    #>                                     weight   spending  
    #>                                              fn        
    #>   ─────────────────────────────────────────────────────
    #>     H1      CR         Primary         0.4   N/A       
    #>     H2      OS         Primary         0.6   HSD(-1),  
    #>                                              with a    
    #>                                              nominal   
    #>                                              spend of  
    #>                                              0.001 at  
    #>                                              IA1       
    #>     H3      EFS        Secondar        0     HSD(-1),  
    #>                        y                     with a    
    #>                                              nominal   
    #>                                              spend of  
    #>                                              0.001 at  
    #>                                              IA1       
    #>   ─────────────────────────────────────────────────────
    #> 
    #> Column names: Label, Endpoint, Type, Initial weight, GSD
    #> spending fn, Effect size, Maximum events / sample size
    #> 
    #> 5/7 columns shown.

The overall type I family-wise error rate for 3 hypotheses, over all
(interim and final) analyses, is controlled to 2.5% (one-sided).

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

    #>  ────────────────────────────────────────────────────────
    #>    Hypothes   Analysis   Criteria   Expected   Events /  
    #>    is                    for        analysis     sample  
    #>                          conduct        time       size  
    #>  ────────────────────────────────────────────────────────
    #>    H1: CR            1   500 CR         28          500  
    #>                          outcomes                        
    #>    H2: OS            1   500 CR         28          187  
    #>                          outcomes                        
    #>    H2: OS            2   234 OS         32.8        234  
    #>                          events                          
    #>    H2: OS            3   284 OS         39.4        284  
    #>                          events                          
    #>    H2: OS            4   334 OS         48.7        334  
    #>                          events                          
    #>    H3: EFS           1   500 CR         28          248  
    #>                          outcomes                        
    #>    H3: EFS           2   234 OS         32.8        306  
    #>                          events                          
    #>    H3: EFS           3   284 OS         39.4        362  
    #>                          events                          
    #>    H3: EFS           4   334 OS         48.7        413  
    #>                          events                          
    #>  ────────────────────────────────────────────────────────
    #> 
    #> Column names: Hypothesis, Analysis, Criteria for conduct,
    #> Expected analysis time, Events / sample size, Information
    #> fraction
    #> 
    #> 5/6 columns shown.

**Table 3. Summary of Interim Analyses (by calendar analysis)**

    #>  ────────────────────────────────────────────────────────
    #>    Hypothes   Analysis   Criteria   Expected   Events /  
    #>    is                    for        analysis     sample  
    #>                          conduct        time       size  
    #>  ────────────────────────────────────────────────────────
    #>    H1: CR            1   500 CR         28          500  
    #>                          outcomes                        
    #>    H2: OS            1   500 CR         28          187  
    #>                          outcomes                        
    #>    H3: EFS           1   500 CR         28          248  
    #>                          outcomes                        
    #>    H2: OS            2   234 OS         32.8        234  
    #>                          events                          
    #>    H3: EFS           2   234 OS         32.8        306  
    #>                          events                          
    #>    H2: OS            3   284 OS         39.4        284  
    #>                          events                          
    #>    H3: EFS           3   284 OS         39.4        362  
    #>                          events                          
    #>    H2: OS            4   334 OS         48.7        334  
    #>                          events                          
    #>    H3: EFS           4   334 OS         48.7        413  
    #>                          events                          
    #>  ────────────────────────────────────────────────────────
    #> 
    #> Column names: Hypothesis, Analysis, Criteria for conduct,
    #> Expected analysis time, Events / sample size, Information
    #> fraction
    #> 
    #> 5/6 columns shown.

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

    #>    ───────────────────────────────────────────────────
    #>      Hypothesis   Local alpha   Weight   Testing      
    #>                         level            scenario     
    #>    ───────────────────────────────────────────────────
    #>      H1: CR             0.01       0.4   Initial      
    #>                                          allocation   
    #>      H1: CR             0.025      1     Successful   
    #>                                          H2, H3       
    #>      H2: OS             0.015      0.6   Initial      
    #>                                          allocation   
    #>      H2: OS             0.025      1     Successful   
    #>                                          H1           
    #>      H3: EFS            0.015      0.6   Successful   
    #>                                          H2           
    #>      H3: EFS            0.025      1     Successful   
    #>                                          H1, H2       
    #>    ───────────────────────────────────────────────────
    #> 
    #> Column names: Hypothesis, Local alpha level, Weight,
    #> Testing scenario

**Table 5. Boundary Specifications**

Table 5 details the hypothesis testing at the interim and final
analyses. For hypotheses tested group sequentially, the table provides
the nominal p-value boundary derived from the alpha-spending function
and the information fractions. The timing of analyses is expressed in
terms of statistical information fractions. The table also reports local
power at each analysis time.

    #>  ────────────────────────────────────────────────────────
    #>    Hypothes   Analysis      Local   Informat    Nominal  
    #>    is                       alpha        ion    p-value  
    #>                             level   fraction             
    #>  ────────────────────────────────────────────────────────
    #>    H1: CR            1      0.01        1       0.01     
    #>    H1: CR            1      0.025       1       0.025    
    #>    H2: OS            1      0.015       0.56    0.001    
    #>    H2: OS            2      0.015       0.7     0.00876  
    #>    H2: OS            3      0.015       0.85    0.00717  
    #>    H2: OS            4      0.015       1       0.00848  
    #>    H2: OS            1      0.025       0.56    0.001    
    #>    H2: OS            2      0.025       0.7     0.0147   
    #>    H2: OS            3      0.025       0.85    0.0125   
    #>    H2: OS            4      0.025       1       0.0149   
    #>    H3: EFS           1      0.015       0.6     0.001    
    #>    H3: EFS           2      0.015       0.74    0.0095   
    #>    H3: EFS           3      0.015       0.88    0.00753  
    #>    H3: EFS           4      0.015       1       0.00832  
    #>    H3: EFS           1      0.025       0.6     0.001    
    #>    H3: EFS           2      0.025       0.74    0.0159   
    #>    H3: EFS           3      0.025       0.88    0.0131   
    #>    H3: EFS           4      0.025       1       0.0147   
    #>  ────────────────────────────────────────────────────────
    #> 
    #> Column names: Hypothesis, Analysis, Local alpha level,
    #> Information fraction, Nominal p-value, Exit hurdle, Local
    #> power
    #> 
    #> 5/7 columns shown.

**Table 6a. Operating Characteristics at Each Analysis**

    #>      ────────────────────────────────────────────────
    #>        Analysis   Metric        Hypothesis    Value  
    #>                                 subset               
    #>      ────────────────────────────────────────────────
    #>               1   Power         H1            0.875  
    #>               1   Power         H2            0.29   
    #>               1   Power         H3            0.143  
    #>               1   Probability   H1, H2        0.907  
    #>                   of success                         
    #>                   for at                             
    #>                   least one                          
    #>                   Hi                                 
    #>               1   Probability   H1, H2, H3    0.907  
    #>                   of success                         
    #>                   for at                             
    #>                   least one                          
    #>                   Hi                                 
    #>               1   Probability   H1, H2, H3    0.133  
    #>                   of success                         
    #>                   for all Hi                         
    #>               2   Power         H1            0.899  
    #>               2   Power         H2            0.742  
    #>               2   Power         H3            0.663  
    #>               2   Probability   H1, H2        0.956  
    #>                   of success                         
    #>                   for at                             
    #>                   least one                          
    #>                   Hi                                 
    #>               2   Probability   H1, H2, H3    0.956  
    #>                   of success                         
    #>                   for at                             
    #>                   least one                          
    #>                   Hi                                 
    #>               2   Probability   H1, H2, H3    0.622  
    #>                   of success                         
    #>                   for all Hi                         
    #>               3   Power         H1            0.907  
    #>               3   Power         H2            0.842  
    #>               3   Power         H3            0.788  
    #>               3   Probability   H1, H2        0.969  
    #>                   of success                         
    #>                   for at                             
    #>                   least one                          
    #>                   Hi                                 
    #>               3   Probability   H1, H2, H3    0.969  
    #>                   of success                         
    #>                   for at                             
    #>                   least one                          
    #>                   Hi                                 
    #>               3   Probability   H1, H2, H3    0.736  
    #>                   of success                         
    #>                   for all Hi                         
    #>               4   Power         H1            0.919  
    #>               4   Power         H2            0.91   
    #>               4   Power         H3            0.874  
    #>               4   Probability   H1, H2        0.986  
    #>                   of success                         
    #>                   for at                             
    #>                   least one                          
    #>                   Hi                                 
    #>               4   Probability   H1, H2, H3    0.986  
    #>                   of success                         
    #>                   for at                             
    #>                   least one                          
    #>                   Hi                                 
    #>               4   Probability   H1, H2, H3    0.812  
    #>                   of success                         
    #>                   for all Hi                         
    #>      ────────────────────────────────────────────────
    #> 
    #> Column names: Analysis, Metric, Hypothesis subset, Value

**Table 6b. Operating Characteristics Across Analyses**

    #>      ───────────────────────────────────────────────
    #>        Metric             Hypothesis         Value  
    #>                           subset                    
    #>      ───────────────────────────────────────────────
    #>        Expected Success   H1                  1.08  
    #>        Analysis                                     
    #>        Expected Success   H2                  1.94  
    #>        Analysis                                     
    #>        Expected Success   H3                  2.18  
    #>        Analysis                                     
    #>        Expected Success   H1, H2              1.13  
    #>        Analysis (at                                 
    #>        least one Hi)                                
    #>        Expected Success   H1, H2, H3          1.13  
    #>        Analysis (at                                 
    #>        least one Hi)                                
    #>        Expected Success   H1, H2, H3          2.16  
    #>        Analysis (for                                
    #>        all Hi)                                      
    #>        Expected Success   H1                 28.5   
    #>        Time                                         
    #>        Expected Success   H2                 33.2   
    #>        Time                                         
    #>        Expected Success   H3                 34.5   
    #>        Time                                         
    #>        Expected Success   H1, H2             28.8   
    #>        Time (at least                               
    #>        one Hi)                                      
    #>        Expected Success   H1, H2, H3         28.8   
    #>        Time (at least                               
    #>        one Hi)                                      
    #>        Expected Success   H1, H2, H3         34.4   
    #>        Time (for all                                
    #>        Hi)                                          
    #>      ───────────────────────────────────────────────
    #> 
    #> Column names: Metric, Hypothesis subset, Value

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

*Report generated on 2026-05-24 00:07:24.199649*
