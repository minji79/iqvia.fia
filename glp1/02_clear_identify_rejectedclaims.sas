

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
proc print data=input.plan_enrollment_v1 (obs=10); run;


/*****************************
* 3. identify the last-year enrollment;
*****************************/
proc sort data=input.plan_enrollment out=plan_enrollment; by patient_id plan_id year; run;
data input.plan_enrollment_v1;
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
data input.plan_enrollment; set input.plan_enrollment_v1; drop prev_plan prev_year; run;
proc sort data=input.plan_enrollment; by patient_id year; run;

/*****************************
* 4. enrollment indicator -> merge with the all dataset
*****************************/
* merge with payer_type and payer_type_indicator;
data id; set input.rx18_24_glp1_long_v00; keep plan_id payer_type payer_type_indicator; run;
proc sort data=id nodupkey; by plan_id payer_type; run;

proc sql; 
  create table input.plan_enrollment_v1 as
  select a.*, b.payer_type, b.payer_type_indicator 
  from input.plan_enrollment as a 
  left join id as b
  on a.plan_id = b.plan_id;
quit;

data input.plan_enrollment_v1; set input.plan_enrollment_v1; drop plan_type; run;
data input.plan_enrollment_v1;
    retain patient_id year plan_id plan_name payer_type payer_type_indicator any_drug_PD any_drug_RJ any_drug_RV any_glp1_PD any_glp1_RJ any_glp1_RV enrolled_last_yr	;
    set input.plan_enrollment_v1;
run;
proc sort data=input.plan_enrollment_v1; by patient_id year; run;
proc print data=input.plan_enrollment_v1 (obs=0); where any_drug_PD = 0 and any_glp1_PD ne 0;  run;

* enrollment;
data input.plan_enrollment; set input.plan_enrollment_v1; if any_drug_PD ne 0 or any_glp1_PD ne 0 then enrollment = 1; else enrollment =0; run;
proc print data=input.plan_enrollment (obs=10); run;

* merge with the overall dataset;
proc sql; 
  create table input.rx18_24_glp1_long_v00 as
  select a.*, b.enrollment
  from input.rx18_24_glp1_long_v00 as a 
  left join input.plan_enrollment as b
  on a.patient_id = b.patient_id and a.plan_id = b.plan_id and a.year = b.year;
quit;

proc sql; 
  create table input.rx18_24_glp1_long_v01 as
  select a.*, b.enrollment
  from input.rx18_24_glp1_long_v01 as a 
  left join input.plan_enrollment as b
  on a.patient_id = b.patient_id and a.plan_id = b.plan_id and a.year = b.year;
quit;


/*****************************
* 5. exclude rejection if enrollment = 0 or payer_type_indicator = "secondary_payer";

RJ_reason
  RJ_reason = 'Approved' if rjct_grp=0;
  RJ_reason = 'Plan Switching' if encnt_='RJ' and enrollment = 0;
  RJ_reason = 'RJ by Secondary Payer' if encnt_='RJ' and payer_type_indicator = "secondary_payer";
  RJ_reason = 'RJ_Step' = if (encnt_='RJ' and enrollment = 1 and rjct_grp=1); 
  RJ_PrAu = (encnt_='RJ' and rjct_grp=2); 
  RJ_NtCv = (encnt_='RJ' and rjct_grp=3); 
  RJ_PlLm = (encnt_='RJ' and rjct_grp=4); 
  RJ_NotForm = (encnt_='RJ' and rjct_grp=5); 
*****************************/

data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; 
 length RJ_reason $100.;
 RJ_reason = "";
 if encnt_outcm_cd in ("RV","PD") then RJ_reason = 'Approved';
 else if encnt_outcm_cd = 'RJ' and enrollment = 0 then RJ_reason = 'Plan Switching';
 else if encnt_outcm_cd = 'RJ' and payer_type_indicator = "secondary_payer" then RJ_reason = 'RJ by Secondary Payer';
 else if encnt_outcm_cd = 'RJ' and enrollment = 1 and rjct_grp=1 then RJ_reason = 'RJ_Step';
 else if encnt_outcm_cd = 'RJ' and enrollment = 1 and rjct_grp=2 then RJ_reason = 'RJ_PrAu';
 else if encnt_outcm_cd = 'RJ' and enrollment = 1 and rjct_grp=3 then RJ_reason = 'RJ_NtCv';
 else if encnt_outcm_cd = 'RJ' and enrollment = 1 and rjct_grp=4 then RJ_reason = 'RJ_PlLm';
 else if encnt_outcm_cd = 'RJ' and enrollment = 1 and rjct_grp=5 then RJ_reason = 'RJ_NotForm';
 else RJ_reason = 'NA';
run;
proc freq data=input.rx18_24_glp1_long_v00; table RJ_reason ; run;
proc print data= rx18_24_glp1_long_v00; where RJ_reason = 'NA' and not missing(encnt_outcm_cd); run; /* 6 rows with invalid information */


data rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; 
 length RJ_reason $100.;
 RJ_reason = "";
 if encnt_outcm_cd in ("RV","PD") then RJ_reason = 'Approved';
 else if encnt_outcm_cd = 'RJ' and enrollment = 0 then RJ_reason = 'Plan Switching';
 else if encnt_outcm_cd = 'RJ' and payer_type_indicator = "secondary_payer" then RJ_reason = 'RJ by Secondary Payer';
 else if encnt_outcm_cd = 'RJ' and enrollment = 1 then RJ_reason = 'RJ by Formularly Reasons';
 else RJ_reason = 'NA';
run;

* within the payer_type_indicator = "dominant_payer";
data sample; set rx18_24_glp1_long_v00; if payer_type_indicator = "dominant_payer"; run;
proc freq data=sample; table RJ_reason* payer_type /norow nopercent; run;

proc freq data=input.rx18_24_glp1_long_v00; table encnt_outcm_cd; run;
proc freq data=input.rx18_24_glp1_long_v00; table rjct_grp; run;







