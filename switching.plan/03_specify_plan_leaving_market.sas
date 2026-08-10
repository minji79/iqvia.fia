
proc contents data=input.RxFact_2018_2024_ili; run;
proc contents data=biosim.RxFact2025_clean; run;


/* ====================================================================
  1. make dataset
   ==================================================================== */
   
proc sort data=biosim.RxFact2025_clean; by plan_id year patient_id; run;
data plan_level_2;
  set biosim.RxFact2025_clean;
  by plan_id year patient_id;
  retain n_patients n_total_claims n_claimsPD n_claimsRV n_claimsRJ;
  
  if first.year then do;
	  n_patients = 0;
    n_total_claims = 0;
    n_claimsPD = 0;
    n_claimsRV = 0;
    n_claimsRJ = 0;
    
  end;

  if first.patient_id then n_patients + 1;
  n_total_claims + 1;

  if encnt_outcm_cd = 'PD' then n_claimsPD + 1;
    else if encnt_outcm_cd = 'RV' then n_claimsRV + 1;
    else if encnt_outcm_cd = 'RJ' then n_claimsRJ + 1;

  if last.year then output;
  keep plan_id plan_name plan_type year model_type payer_id payer_name n_patients n_total_claims n_claimsPD n_claimsRV n_claimsRJ; 
run; /* 10064 */

proc print data=plan_level_2 (obs=10); run;


proc sort data=input.RxFact_2018_2024_ili; by plan_id year patient_id; run;
data plan_level_1;
  set input.RxFact_2018_2024_ili;
  by plan_id year patient_id;
  retain n_patients n_total_claims n_claimsPD n_claimsRV n_claimsRJ;
  
  if first.year then do;
	  n_patients = 0;
    n_total_claims = 0;
    n_claimsPD = 0;
    n_claimsRV = 0;
    n_claimsRJ = 0;
    
  end;

  if first.patient_id then n_patients + 1;
  n_total_claims + 1;

  if encnt_outcm_cd = 'PD' then n_claimsPD + 1;
    else if encnt_outcm_cd = 'RV' then n_claimsRV + 1;
    else if encnt_outcm_cd = 'RJ' then n_claimsRJ + 1;

  if last.year then output;
  keep plan_id plan_name plan_type year model_type payer_id payer_name n_patients n_total_claims n_claimsPD n_claimsRV n_claimsRJ; 
run;
data input.plan_level_exit; set plan_level_1 plan_level_2; run;
proc print data= input.plan_level_exit(obs=10); run;



/* ====================================================================
   2. identify exit year
   ==================================================================== */
   
proc sort data=input.plan_level_exit out=plan_level_last_year; by plan_id descending year; run; 
data plan_level_last_year; set plan_level_last_year; by plan_id; if first.plan_id; run;

proc sql;
  create table input.plan_level_exit as
  select distinct a.*, b.year as last_year_fia
  from input.plan_level_exit as a
  left join plan_level_last_year as b
	on a.plan_id = b.plan_id;
quit; 
proc print data= input.plan_level_exit(obs=40); run;


data input.plan_level_exit; set input.plan_level_exit; if year = last_year_fia and last_year_fia < 2025 then exit_next_yr = 1; else exit_next_yr = 0;
proc freq data=input.plan_level_exit; table exit_next_yr; run;
