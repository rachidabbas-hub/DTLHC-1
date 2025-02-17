# Drop the losers with historical control group

Incorporating historic information in multi-arm clinical trials for pediatric cancers: drop the losers with historical control group

## Simulation study of multi-arm clinical trial: drop-the-loser with time to event outcome using historical control 

Here we report the operating characteristics of the design  
source the "DTLHC_functions.r"
run "DTLHC_simulations.r" to reproduce results.

__Design general parameters__

* 3 arms
* 2 years follow-up
* N_1 patients per arms at stage 1
* N_2 patients per arm at stage 2
* Family-wise error rate =0.1  #it is a phase II clinical trial

__Interim analysis__

* Decision rules: drop the losers 
* bounds: none (keep with the arm giving the maximal LR statistic at interim)

__Final analysis__

* Decision rules: Log-rank test for historical control

__Hazard rates:__  

* hazard.null=-log(0.4)/2
* hazard.exp (small effect): hr=-log(0.50)/2
* hazard.exp (great effect): hr=-log(0.65)/2

__Historical data__

* historic data distribution: Weibull
* parameter: kappa=0.9509

## Simulation results: Power

In a multi-arm setting the concept of power is complex due to multiplicity of hypotheses. The probability to reject all false null hypothese is called the conjunctive power. The probability to reject at least one false null hypothesis is called the disjunctive power. Usually, it is harder to obtain a high conjunctive power. Here the design do not allow to reject more than one null hypothesis, we report disjunctive power.
 
## Simulation results: Type 1 error rate

By design, the family-wise error rate is controlled at the global null hypothesis. Here we report the type 1 error rate per scenario. The scenario 1, considering only experimental arms with null effect (also called the global null hypothesis) reflects the empirical family-wise error rate. 

