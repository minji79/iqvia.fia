
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
   2. identify exit year - criteria 1 
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

/* criteria 1 */
data input.plan_level_exit; set input.plan_level_exit; if year = last_year_fia and last_year_fia < 2025 then exit_next_yr = 1; else exit_next_yr = 0;
proc freq data=input.plan_level_exit; table exit_next_yr; run;

proc print data= input.plan_level_exit(obs=40); where not missing(plan_id) and last_year_fia < 2025; run;

/* criteria 2 */

/* ====================================================================
   3. TOP 10 largest plan_id that exited market
   ==================================================================== */

/* make size indicator: avg n_patients across years & accumulated n_patients -> and wide dataset */
proc sort data=input.plan_level_exit; by plan_id year; run;
data input.plan_level_exit_wide;
    set input.plan_level_exit;
    by plan_id year;

    retain accumulated_n year_count;

    /* Reset running counters at the start of each NEW plan */
    if first.plan_id then do;
        accumulated_n = 0;
        year_count = 0;
    end;

    /* (1) Cumulative patient count up to the current year */
    accumulated_n = accumulated_n + n_patients;

    /* Increment count of observed years for the plan */
    year_count = year_count + 1;

    /* (2) Running average n_patients across observed years */
    avg_n_patients = accumulated_n / year_count;

	if last.plan_id;

run;
proc print data=input.plan_level_exit_wide(obs=40); run; /* 15415 plan_id */

/* exiting plan_id by plan type */
proc freq data=input.plan_level_exit_wide; table plan_type*exit_next_yr /nocol nopercent; run;

/* top 10 largest plan_id */
data exit_plan; set input.plan_level_exit_wide; if exit_next_yr=1 and not missing(plan_id); run;
proc sort data=exit_plan; by descending avg_n_patients; run;
proc print data=exit_plan(obs=20); run;

/* ====================================================================
   4. Analysis
   ==================================================================== */



