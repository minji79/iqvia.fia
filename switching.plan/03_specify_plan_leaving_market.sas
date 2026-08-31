
proc contents data=input.RxFact_2018_2024_ili; run;
proc contents data=biosim.RxFact2025_clean; run;


/* ====================================================================
  1-1. make dataset
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
proc print data= input.plan_level_exit(obs=15); where not missing(plan_id); run;


/* ====================================================================
  1-2. make dataset - identify top 5 dominant payer information
   ==================================================================== */
* make plan_id - year - patient_id dataset;
proc sort data=biosim.RxFact2025_clean 
          out=df_25(keep=plan_id year patient_id) 
          nodupkey;
    by plan_id year patient_id;
run;
proc sort data=input.RxFact_2018_2024_ili
          out=df_1724(keep=plan_id year patient_id) 
          nodupkey;
    by plan_id year patient_id;
run;
data input.plan_yr_ind; set df_1724 df_25; run;
proc print data= input.plan_yr_ind (obs=15);where not missing(plan_id); run;

* merge with donimant payer files;
data input.plan_yr_ind; set plan_yr_ind; drop dominant_plan_id dominant_plan_name total_paid_claims; run;
proc sql;
  create table input.plan_yr_ind as
  select distinct a.*, b.dominant_payer, b.plan_id as dominant_plan_id, b.plan_name as dominant_plan_name, b.total_paid_claims
  from input.plan_yr_ind as a
  left join biosim.dominant_pyr_1725 as b
	on a.patient_id = b.patient_id and a.year = b.year;
quit; 
proc print data= input.plan_yr_ind (obs=15); where not missing(plan_id); run;

proc freq data=input.plan_yr_ind; tables dominant_plan_id / missing; run;
proc sql;
    select 
        count(*) as total_rows,
        sum(case when missing(dominant_payer) then 1 else 0 end) as n_missing,
        calculated n_missing / count(*) as pct_missing format=percent8.2
    from input.plan_yr_ind;
quit;

/* top 3 dominant_payer by plan_id year level */
proc sort data=input.plan_yr_ind; by plan_id year; run;

data plan_yr_dmpyr;
  set input.plan_yr_ind;
  by plan_id year;
  retain n_patients n_Commercial n_Exchange n_Medicaid_FFS n_Medicaid_MCO n_Medicaid_unsp n_Medicare_TM n_Medicare_ADV n_Medicare_unsp n_PPO_HMO n_State_Fed n_missing;
  
  if first.year then do;
	  n_patients = 0;
	  n_Commercial =0;
	  n_Exchange =0;
	  n_Medicaid_FFS =0;
	  n_Medicaid_MCO =0;
	  n_Medicaid_unsp =0;
	  n_Medicare_TM =0;
	  n_Medicare_ADV =0;
	  n_Medicare_unsp =0;
	  n_PPO_HMO =0;
	  n_State_Fed =0;
	  n_missing =0;
   
  end;
  
  n_patients + 1;

  if dominant_payer = 'Commercial' then n_Commercial + 1;
    else if dominant_payer = 'Exchange' then n_Exchange + 1;
    else if dominant_payer = 'Medicaid: FFS' then n_Medicaid_FFS + 1;
	else if dominant_payer = 'Medicaid: MCO' then n_Medicaid_MCO + 1;
	else if dominant_payer = 'Medicaid: Unspec' then n_Medicaid_unsp + 1;
	else if dominant_payer = 'Medicaid: FFS' then n_Medicaid_FFS + 1;
	else if dominant_payer = 'Medicare D: ADV' then n_Medicare_ADV + 1;
	else if dominant_payer = 'Medicare D: TM' then n_Medicare_TM + 1;
	else if dominant_payer = 'Medicare D: Unspec' then n_Medicare_unsp + 1;
	else if dominant_payer = 'PPO/HMO' then n_PPO_HMO + 1;
	else if dominant_payer = 'State/Fed Employee' then n_State_Fed + 1;
	else n_missing +1;

  if last.year then output;
  keep plan_id year n_patients n_Commercial n_Exchange n_Medicaid_FFS n_Medicaid_MCO n_Medicaid_unsp n_Medicare_TM n_Medicare_ADV n_Medicare_unsp n_PPO_HMO n_State_Fed n_missing;
run; /* 10064 */
proc print data= plan_yr_dmpyr (obs=15); where not missing(plan_id); run;

/* 1. Transpose from wide to long */
proc transpose data=plan_yr_dmpyr 
               out=long_dmpyr(rename=(_NAME_=payer_category COL1=patient_count));
    by plan_id year n_patients;
    var n_Commercial n_Exchange n_Medicaid_FFS n_Medicaid_MCO n_Medicaid_unsp 
        n_Medicare_TM n_Medicare_ADV n_Medicare_unsp n_PPO_HMO n_State_Fed;
run;

/* 2. Sort descending within plan_id - year */
proc sort data=long_dmpyr;
    by plan_id year descending patient_count;
run;

/* 3. Filter for Top 5 */
data top5_dmpyr;
    set long_dmpyr;
    by plan_id year descending patient_count;

    retain rank;
    if first.year then rank = 0;
    rank + 1;

    if rank <= 5;
run;

/* 4. Reshape category names and counts back to wide format */
proc transpose data=top5_dmpyr out=top5_wide(drop=_NAME_) prefix=top_cat_;
    by plan_id year n_patients;
    var payer_category;
run;

proc transpose data=top5_dmpyr out=top5_counts_wide(drop=_NAME_) prefix=top_count_;
    by plan_id year n_patients;
    var patient_count;
run;

/* 5. Merge into final dataset */
data plan_yr_top5;
    merge top5_wide top5_counts_wide;
    by plan_id year;
run;
proc print data= plan_yr_top5 (obs=15); where not missing(plan_id); run;
data input.plan_yr_top5; set plan_yr_top5; run;

/* merge with input.plan_level_exit */
proc sql;
  create table input.plan_level_exit as
  select distinct a.*, b.top_cat_1, b.top_cat_2, b.top_cat_3, b.top_cat_4, b.top_cat_5
  from input.plan_level_exit as a
  left join input.plan_yr_top5 as b
	on a.plan_id = b.plan_id and a.year = b.year;
quit; 


/* ====================================================================
   2-1. identify exit year - criteria 1
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


/* ====================================================================
   2-2. identify exit year - criteria 2
   ==================================================================== */
* velocity of decrease in paid claims;

/* 1. Ensure data is sorted by plan_id and year */
proc sort data=input.plan_level_exit; by plan_id year; run;

/* 2. Calculate year-over-year patient proportion */
data plan_level_yoy;
    set input.plan_level_exit;
    by plan_id year;

    /* Get n_patients from the immediately preceding row */
    prev_n_patients = lag(n_patients);
	prev_n_paid = lag(n_claimsPD);

    /* For the first observed year of a plan, set lag to missing */
    if first.plan_id then do;
		prev_n_patients = .;
		prev_n_paid = .;
	end;
	
    /* Calculate ratio: Year(n) / Year(n-1) */
	if not missing(prev_n_patients) then do;
    	if prev_n_patients > 0 then 
        	patient_yoy_ratio = n_patients / prev_n_patients;
    	else if prev_n_patients = 0 then 
        	patient_yoy_ratio = 1;
		end;
	else patient_yoy_ratio = .;

	if not missing(prev_n_paid) then do;
    	if prev_n_paid > 0 then 
        	paid_yoy_ratio = n_claimsPD / prev_n_paid;
    	else if prev_n_paid = 0 then 
        	paid_yoy_ratio = 1;
		end;
	else paid_yoy_ratio = .;
		
    /* Optional: Format as percentage or decimal */
    format patient_yoy_ratio 8.4;
	format paid_yoy_ratio 8.4;	
run;

proc print data= plan_level_yoy (obs=15); where not missing(plan_id); run;

* indicate more than 90% of decrease in patients numbers ;
proc print data= plan_level_yoy (obs=15); where not missing(paid_yoy_ratio) & paid_yoy_ratio < 0.1; run;
proc print data= plan_level_yoy; var plan_id payer_name plan_name plan_type year n_patients n_total_claims n_claimsPD paid_yoy_ratio; where plan_id in (31, 41, 56); run;

data input.plan_level_exit_clean; 
    set plan_level_yoy; 

    /* Flag exit_this_year = 1 if paid claim volume dropped by >90% (ratio < 0.1), within 2 years of the plan's last observed year */
    if not missing(paid_yoy_ratio) 
       and paid_yoy_ratio < 0.1
       and (last_year_fia - year) <= 2 then exit_this_year = 1;
    else exit_this_year = 0;
run;

/* flag only the first year's one */
proc sort data=input.plan_level_exit_clean; by plan_id year; run;

/* 2. Flag only the first occurrence of exit_this_year = 1 */
data input.plan_level_exit_clean;
    set input.plan_level_exit_clean;
    by plan_id year;

    retain has_exited;

    /* Reset tracker at the start of each new plan */
    if first.plan_id then has_exited = 0;

    /* Check if this is the first row where exit_this_year == 1 */
    if exit_this_year = 1 and has_exited = 0 then do;
        first_exit_this_year = 1;
        has_exited = 1; /* Mark that an exit row has been flagged for this plan */
    end;
    else do;
        first_exit_this_year = 0;
    end;

    drop has_exited;
run;
proc print data= input.plan_level_exit_clean; 
	var plan_id payer_name plan_name plan_type year n_patients n_total_claims n_claimsPD top_cat_1 top_cat_2 top_cat_3 top_cat_4 top_cat_5 paid_yoy_ratio exit_this_year first_exit_this_year; 
	where plan_id in (31, 41, 56); run;


/* ====================================================================
   3. NOT exclude the PBMs or missing in modeltype
   ==================================================================== */
/*
data input.plan_level_exit_clean;
    set input.plan_level_exit_clean;
    /* Delete rows where model_type contains 'PBM' */
    if find(model_type, 'PBM', 'i') > 0 | missing(model_type) then delete;
run;
proc freq data=input.plan_level_exit_clean; table model_type; run;
*/

/* ====================================================================
   4. TOP 10 largest plan_id that exited market
   ==================================================================== */

/* make size indicator: avg n_patients across years & accumulated n_patients -> and wide dataset */
proc sort data=input.plan_level_exit_clean; by plan_id year; run;
data input.plan_level_exit_wide;
    set input.plan_level_exit_clean;
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
proc freq data=input.plan_level_exit_wide; table plan_type*first_exit_this_year /nocol nopercent; run;

/* top 10 largest plan_id */
data exit_plan; set input.plan_level_exit_wide; if first_exit_this_year=1 and not missing(plan_id); run;
proc sort data=exit_plan; by descending avg_n_patients; run;
proc print data=exit_plan(obs=20); var payer_id plan_id model_type payer_name plan_name plan_type year n_patients n_total_claims n_claimsPD n_claimsRV
	n_claimsRJ prev_n_patients prev_n_paid paid_yoy_ratio top_cat_1 top_cat_2 top_cat_3 top_cat_4 top_cat_5 first_exit_this_year avg_n_patients; run;

/* ====================================================================
   4. Let's look into Medicare plans closely 
   ==================================================================== */

* how many MA vs TM each year?;
data sample; set input.plan_level_exit_clean; if plan_type in ("Medicare TM","Medicare ADV"); run;
proc sort data=sample; by year plan_type; run;

/* Aggregate metrics at Year x Plan_Type level */
data summary; 
    set sample; 
    by year plan_type; 
    retain n_total_plans n_total_patients n_exit_plans n_exit_patients;

    if first.plan_type then do;
        n_total_plans    = 0;
        n_total_patients = 0;
        n_exit_plans     = 0;
        n_exit_patients  = 0;
    end;
    
    n_total_plans    + 1;
    n_total_patients = n_total_patients + n_patients;
    
    if first_exit_this_year = 1 then do;
        n_exit_plans    + 1;
        n_exit_patients = n_exit_patients + n_patients;
    end;

    if last.plan_type then output;
    keep year plan_type n_total_plans n_total_patients n_exit_plans n_exit_patients;
run;

proc sort data=summary; by plan_type year; run;
data summary; set summary; pct_exit_plan = n_exit_plans / n_total_plans*100; run;
data summary; set summary; pct_exit_patients = n_exit_patients / n_total_patients*100; run;
proc print data=summary; run;

data input.medicare_yearly; set summary; run; /* save the one */


/* example of individuals: those enrolled in exiting TM in 2023 */
proc print data=input.plan_level_exit_clean; where plan_type = "Medicare TM" and year=2023 and first_exit_this_year = 1; run;

/* picked the largest plan among exiting plans in 2023, 
	which is payer_id = 13459585, plan_id = 14698 
	ELIXIR RX INSURANCE COMPANY - ELIXIR RX MED PDP GENERAL (OH)
*/

/* pick one individuals who enrolled this plan in 2023 
	patient_id = 134202480 | 27366396 | 69827258 | 134202480
*/
proc print data=input.RxFact_2018_2024_ili (obs=20); where year=2023 and payer_id = 13459585 and plan_id = 14698; run;
data input.sample; set input.RxFact_2018_2024_ili; if patient_id = 134202480; run;
proc sort data=input.sample; by svc_dt; run; /* 286 obs */
proc print data=input.sample (obs=50); where year in (2022, 2023,2024); var patient_id svc_dt model_type payer_id payer_name plan_type plan_id plan_name encnt_outcm_cd molecule_name usc_3_description; run;




