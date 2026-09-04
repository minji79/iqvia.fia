

proc contents data=biosim.RxFact2025_clean; run;

data RxFact2025_clean; set biosim.RxFact2025_clean; if usc_5 not in (27100, 27200, 27300); if encnt_outcm_cd = 'PD'; run; /* excluding vaccines & remaining only paid claims */

proc sort data=RxFact2025_clean; by plan_id year patient_id; run;
data input.plan_level_25;
    set RxFact2025_clean;
    by plan_id year patient_id;
    
    retain n_patients n_total_claims n_claimsPD n_claimsRV n_claimsRJ has_pd;

    /* Reset annual counters at the start of each plan-year */
    if first.year then do;
        n_patients     = 0;
        n_total_claims = 0;
        n_claimsPD     = 0;
        n_claimsRV     = 0;
        n_claimsRJ     = 0;
    end;

    /* Reset patient-level flag for each new patient */
    if first.patient_id then has_pd = 0;

    /* Flag if this patient has at least one paid claim */
    if encnt_outcm_cd = 'PD' then has_pd = 1;

    /* Increment patient counter once per patient if they had a paid claim */
    if last.patient_id and has_pd = 1 then n_patients + 1;

    /* Increment claim-level counters */
    n_total_claims + 1;

    if encnt_outcm_cd = 'PD' then n_claimsPD + 1;
    else if encnt_outcm_cd = 'RV' then n_claimsRV + 1;
    else if encnt_outcm_cd = 'RJ' then n_claimsRJ + 1;

    /* Keep only the final plan-year summary row */
    if last.year;

    keep plan_id plan_name plan_type year model_type payer_id payer_name 
         n_patients n_total_claims n_claimsPD n_claimsRV n_claimsRJ; 
run;
proc print data= input.plan_level_25 (obs=15); where not missing(plan_id); run;

data RxFact_2018_2024; set input.RxFact_2018_2024_ili; if usc_5 not in (27100, 27200, 27300); if encnt_outcm_cd = 'PD'; run; /* excluding vaccines & remaining only paid claims */
proc sort data=RxFact_2018_2024; by plan_id year patient_id; run;
data input.plan_level_1724;
    set RxFact_2018_2024;
    by plan_id year patient_id;
    
    retain n_patients n_total_claims n_claimsPD n_claimsRV n_claimsRJ has_pd;

    /* Reset annual counters at the start of each plan-year */
    if first.year then do;
        n_patients     = 0;
        n_total_claims = 0;
        n_claimsPD     = 0;
        n_claimsRV     = 0;
        n_claimsRJ     = 0;
    end;

    /* Reset patient-level flag for each new patient */
    if first.patient_id then has_pd = 0;

    /* Flag if this patient has at least one paid claim */
    if encnt_outcm_cd = 'PD' then has_pd = 1;

    /* Increment patient counter once per patient if they had a paid claim */
    if last.patient_id and has_pd = 1 then n_patients + 1;

    /* Increment claim-level counters */
    n_total_claims + 1;

    if encnt_outcm_cd = 'PD' then n_claimsPD + 1;
    else if encnt_outcm_cd = 'RV' then n_claimsRV + 1;
    else if encnt_outcm_cd = 'RJ' then n_claimsRJ + 1;

    /* Keep only the final plan-year summary row */
    if last.year;

    keep plan_id plan_name plan_type year model_type payer_id payer_name 
         n_patients n_total_claims n_claimsPD n_claimsRV n_claimsRJ; 
run;


data input.plan_level_exit_updated; set input.plan_level_1724 input.plan_level_25; run;

proc delete data=input.plan_level_25; run;

proc print data= input.plan_level_exit_updated(obs=15); where not missing(plan_id); run;


proc print data=input.medicare_yearly; run;
