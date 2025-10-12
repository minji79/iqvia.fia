

/*============================================================*
 | 1) Need to include only the final decision on each prescription (incl. initial fill, and following refills) -> exclude them in the cohort derivation step
 *============================================================*/

/*============================================================*
 | 2) Need to exclude rejected claims due to plan switching
 *============================================================*/
proc contents data=input.rx18_24_glp1_long_v00; run;
proc print data=patient_plan (obs=10); run; 

/*****************************
* 1. make id table for our cohort: patient_id year plan_id table; 
*****************************/
data input.patient_plan; set input.rx18_24_glp1_long_v00; keep patient_id year plan_name plan_id plan_type; run;
proc sort data=input.patient_plan nodupkey; by patient_id year plan_id; run;

/*****************************
* 2. merge with the claims table to count the PD, RJ, RV claims;
*****************************/
data input.RxFact_2018_2024_ili; set input.RxFact_2018_2024_ili; year = year(svc_dt); run;

* 2-1. count disposition on any drug;
proc sql; 
  create table input.plan_enrollment_v1 as
  select a.*,         
         sum(case when b.encnt_outcm_cd = "PD" then 1 else 0 end) as any_drug_PD, 
         sum(case when b.encnt_outcm_cd = "RJ" then 1 else 0 end) as any_drug_RJ, 
         sum(case when b.encnt_outcm_cd = "RV" then 1 else 0 end) as any_drug_RV
         
  from input.plan_enrollment as a 
  left join input.RxFact_2018_2024_ili as b
  on a.patient_id = b.patient_id and a.year = b.year and a.plan_id = b.plan_id
  group by a.patient_id, a.year, a.plan_id;
quit;

* 2-2. count disposition on glp1;
proc sql; 
  create table input.plan_enrollment as
  select a.*,
         sum(case when b.encnt_outcm_cd = "PD" then 1 else 0 end) as any_glp1_PD, 
         sum(case when b.encnt_outcm_cd = "RJ" then 1 else 0 end) as any_glp1_RJ, 
         sum(case when b.encnt_outcm_cd = "RV" then 1 else 0 end) as any_glp1_RV
         
  from input.plan_enrollment_v1 as a 
  left join input.rx18_24_glp1_long_v00 as b
  on a.patient_id = b.patient_id and a.year = b.year and a.plan_id = b.plan_id
  group by a.patient_id, a.year, a.plan_id;
quit;
proc sort data=input.plan_enrollment nodupkey; by patient_id year plan_id; run;
proc print data=input.plan_enrollment (obs=10); run;


/*****************************
* 3. identify the last-year enrollment;
*****************************/
proc sort data=input.plan_enrollment out=plan_enrollment; by patient_id plan_id year; run;

data plan_enrollment;
    set plan_enrollment;
    by patient_id plan_id year;
    retain prev_plan prev_year;
    enrolled_last_yr = 0;

    if first.patient_id then do;
        prev_plan = plan_id;
        prev_year = year;
    end;
    else do;
        if year = prev_year + 1 and plan_id = prev_plan then enrolled_last_yr = 1;
        prev_plan = plan_id;
        prev_year = year;
    end;
run;
proc print data=input.joe_plan_mapping (obs=10); run;


/*****************************
* 4. 
*****************************/













