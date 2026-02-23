

proc print data=plan.eric_claim (obs=100); run;


/*============================================================*
 | 1. plan level aggregation - by molecule
 *============================================================*/

proc print data=plan.eric_plan_summary (obs=10); run;

/* regardless paid status */
proc sort data=plan.eric_claim out=eric_s; by plan_id patient_id; run;
data plan.eric_plan_summary;
  set eric_s;
  by plan_id patient_id;

  length study_drug_u glp1_u $50;
  study_drug_u = upcase(strip(study_drug));
  glp1_u       = upcase(strip(glp1));

  if first.plan_id then do;
    claim_count = 0;
    patient_count = 0;
    ADALIMUMAB_count = 0;
    DULAGLUTIDE_count = 0;
    EXENATIDE_count = 0;
    LIXISENATIDE_count = 0;
    LIRAGLUTIDE_count = 0;
    LIRA_o_count = 0;
    SEMAGLUTIDE_count = 0;
    SEMA_o_count = 0;
    TIRZEPATIDE_count = 0;
    TIRZ_o_count = 0;
  end;

  claim_count + 1;

  /* unique patients per plan */
  if first.patient_id then patient_count + 1;

  /* claim-based counts */
  if study_drug_u = "ADALIMUMAB" then ADALIMUMAB_count + 1;
  if glp1_u = "DULAGLUTIDE" then DULAGLUTIDE_count + 1;
  if glp1_u = "EXENATIDE" then EXENATIDE_count + 1;
  if glp1_u = "LIXISENATIDE" then LIXISENATIDE_count + 1;
  if glp1_u = "LIRAGLUTIDE" then LIRAGLUTIDE_count + 1;
  if glp1_u = "SEMAGLUTIDE" then SEMAGLUTIDE_count + 1;
  if glp1_u = "TIRZEPATIDE" then TIRZEPATIDE_count + 1;

  if glp1_u = "LIRAGLUTIDE (WEIGHT MANAGEMENT)" then LIRA_o_count + 1;
  if glp1_u = "SEMAGLUTIDE (WEIGHT MANAGEMENT)" then SEMA_o_count + 1;
  if glp1_u = "TIRZEPATIDE (WEIGHT MANAGEMENT)" then TIRZ_o_count + 1;

  if last.plan_id then do;
    output;
  end;

  keep plan_id claim_count patient_count
       ADALIMUMAB_count DULAGLUTIDE_count EXENATIDE_count LIXISENATIDE_count
       LIRAGLUTIDE_count SEMAGLUTIDE_count TIRZEPATIDE_count
       LIRA_o_count SEMA_o_count TIRZ_o_count;
run;
proc sql;
  create table plan.eric_plan_summary as
  select distinct a.*, b.plan_name
  from plan.eric_plan_summary as a
  left join plan.eric_plan as b
  on a.plan_id = b.plan_id;
quit;

data plan.eric_plan_summary; set plan.eric_plan_summary; pct_ADALIMUMAB = ADALIMUMAB_count / claim_count *100; run;

/* paid status of adalimumab */
data adalimumab_claim; set plan.eric_claim; if study_drug = "ADALIMUMAB"; run;
proc sort data=adalimumab_claim; by plan_id; run;

proc sql;
  create table plan.eric_plan_adalimumab as
  select
      plan_id,
      sum(case when encnt_outcm_cd = "PD" then 1 else 0 end) as adalimumab_PD,
      sum(case when encnt_outcm_cd = "RJ" then 1 else 0 end) as adalimumab_RJ,
      sum(case when encnt_outcm_cd = "RV" then 1 else 0 end) as adalimumab_RV,
      sum(case 
            when missing(strip(encnt_outcm_cd)) then 1
            when upcase(strip(encnt_outcm_cd)) in ("NULL",".","NA","N/A") then 1
            else 0
          end) as adalimumab_NULL,
      count(*) as n_claims
  from adalimumab_claim
  group by plan_id
  order by plan_id;
quit;
proc print data=plan.eric_plan_adalimumab(obs=10); where adalimumab_NULL >0;  run;

/* merge with the original table */
proc sql;
  create table plan.eric_plan_summary as
  select distinct a.*, b.adalimumab_PD, b.adalimumab_RJ, b.adalimumab_RV, b.adalimumab_NULL
  from plan.eric_plan_summary as a
  left join plan.eric_plan_adalimumab as b
  on a.plan_id = b.plan_id;
quit;
data plan.eric_plan_summary; set plan.eric_plan_summary; 
  pct_adalimumab_PD = adalimumab_PD / ADALIMUMAB_count*100;
  pct_adalimumab_RJ = adalimumab_RJ / ADALIMUMAB_count*100;
  pct_adalimumab_RV = adalimumab_RV / ADALIMUMAB_count*100;
  pct_adalimumab_NULL = adalimumab_NULL / ADALIMUMAB_count*100;
run;

data plan.eric_plan_summary; set plan.eric_plan_summary; if ADALIMUMAB_count > 0 then ADALIMUMAB_plan =1; else ADALIMUMAB_plan=0; run;
proc freq data=plan.eric_plan_summary; table ADALIMUMAB_plan; run;


proc sort data=plan.eric_plan_summary; by descending ADALIMUMAB_count; run;
proc print data=plan.eric_plan_summary (obs=10); 
var plan_id plan_name patient_count claim_count ADALIMUMAB_count adalimumab_PD pct_ADALIMUMAB pct_adalimumab_PD pct_adalimumab_RJ pct_adalimumab_RV; 
run;

proc sort data=plan.eric_plan_summary; by descending pct_ADALIMUMAB; run;
proc print data=plan.eric_plan_summary (obs=10); 
var plan_id plan_name patient_count claim_count ADALIMUMAB_count adalimumab_PD pct_ADALIMUMAB pct_adalimumab_PD pct_adalimumab_RJ pct_adalimumab_RV; 
run;

proc sort data=plan.eric_plan_summary; by descending pct_adalimumab_PD; run;
proc print data=plan.eric_plan_summary (obs=10); 
var plan_id plan_name patient_count claim_count ADALIMUMAB_count adalimumab_PD pct_ADALIMUMAB pct_adalimumab_PD pct_adalimumab_RJ pct_adalimumab_RV; 
run;


/*============================================================*
 | 2. plan-year level
 *============================================================*/

/* yearly users */
%macro yearly(year=);
data data_&year; set plan.eric_claim; where year = &year; run;
proc sort data=data_&year; by plan_id patient_id; run;
 
data data_&year;
  set data_&year;
  by plan_id patient_id;

  length study_drug_u $50;
  study_drug_u = upcase(strip(study_drug));

  if first.patient_id then do;
    claim_count = 0;
    ADALIMUMAB_count = 0;
    ADALIMUMAB_PD_count = 0;
    ADALIMUMAB_RJ_count = 0;
    ADALIMUMAB_RV_count = 0;

  end;

  claim_count + 1;
  
  if study_drug_u = "ADALIMUMAB" then ADALIMUMAB_count + 1; 
  if study_drug_u = "ADALIMUMAB" and encnt_outcm_cd = "PD" then ADALIMUMAB_PD_count + 1;
  if study_drug_u = "ADALIMUMAB" and encnt_outcm_cd = "RJ" then ADALIMUMAB_RJ_count + 1;
  if study_drug_u = "ADALIMUMAB" and encnt_outcm_cd = "RV" then ADALIMUMAB_RV_count + 1;
  
  if last.patient_id then do;
    last_date = svc_dt;    /* latest because sorted */
    output;
  end;

  format last_date mmddyy10.;
  keep plan_id year patient_id claim_count ADALIMUMAB_count ADALIMUMAB_PD_count ADALIMUMAB_RJ_count ADALIMUMAB_RV_count last_date;
  
run;

data data_&year; set data_&year; if ADALIMUMAB_count >0 then ADALIMUMAB_user=1; else ADALIMUMAB_user=0; run;

%mend yearly;
%yearly(year=2025);
%yearly(year=2024);  /* 106781 plan_indiv */
%yearly(year=2023);  /* 114640 indiv */
%yearly(year=2022);  /* 121090 indiv */
%yearly(year=2021);
%yearly(year=2020);
%yearly(year=2019);
%yearly(year=2018);
%yearly(year=2017);

data plan.plan_patient_adalimumab; set data_2025 data_2024 data_2023 data_2022 data_2021 data_2020 data_2019 data_2018 data_2017; run;
proc print data=plan.plan_patient_adalimumab (obs=10); run;
proc freq data=plan.plan_patient_adalimumab; table year*ADALIMUMAB_user; run;
data plan.eric_plan_summary; set plan.eric_plan_summary; if ADALIMUMAB_count > 0 then ADALIMUMAB_plan =1; else ADALIMUMAB_plan=0; run;
proc freq data=plan.eric_plan_summary; table ADALIMUMAB_plan; run;

/* user number */
proc sql;
  create table yearly_plan_patien_adalimumab as
  select
      plan_id,
      count(distinct patient_id) as n_patients,
      sum(case when ADALIMUMAB_user = 1 then 1 else 0 end) as n_adalimumab_users
  from plan.plan_patient_adalimumab
  group by plan_id
  order by plan_id;
quit;
data yearly_plan_patien_adalimumab; set yearly_plan_patien_adalimumab; if n_adalimumab_users > 0 then ADALIMUMAB_plan=1; else ADALIMUMAB_plan=0; run;
proc print data= yearly_plan_patien_adalimumab (obs=10); run;

/* merge with */
proc sql;
  create table plan.eric_plan_summary as
  select a.*, b.n_adalimumab_users 
  from plan.eric_plan_summary as a
  left join yearly_plan_patien_adalimumab as b
  on a.plan_id = b.plan_id;

quit;

/* Table 2 */
proc sort data=plan.eric_plan_summary; by descending n_adalimumab_users; run;
proc print data=plan.eric_plan_summary; 
var plan_id plan_name patient_count n_adalimumab_users claim_count ADALIMUMAB_count adalimumab_PD pct_adalimumab_PD pct_adalimumab_RJ pct_adalimumab_RV; 
run;


/*============================================================*
 | 3. Table 1 for plans with ADALIMUMAB use
 *============================================================*/
proc contents data=plan.eric_plan_summary; run;


* patient number;
proc means data=plan.eric_plan_summary n nmiss median q1 q3 min max; var patient_count; run;
proc means data=plan.eric_plan_summary n nmiss median q1 q3 min max;
    class ADALIMUMAB_plan;
    var patient_count;
run;

* users per plan;
proc sql;
  create table yearly_plan_patient_adalimumab as
  select
      plan_id,
      count(distinct patient_id) as n_patients,
      sum(case when ADALIMUMAB_user = 1 then 1 else 0 end) as n_adalimumab_users
  from plan.plan_patient_adalimumab
  group by plan_id
  order by plan_id;
quit;
data yearly_plan_patient_adalimumab; set yearly_plan_patient_adalimumab; if n_adalimumab_users > 0 then ADALIMUMAB_plan=1; else ADALIMUMAB_plan=0; run;

proc means data=yearly_plan_patient_adalimumab n nmiss median q1 q3 min max; var n_adalimumab_users; run;
proc means data=yearly_plan_patient_adalimumab n nmiss median q1 q3 min max;
    class ADALIMUMAB_plan;
    var n_adalimumab_users;
run;

* users per plan - year distribution;
proc sql;
  create table yearly_plan_patien_adalimumab as
  select
      year,
      plan_id,
      count(distinct patient_id) as n_patients,
      sum(case when ADALIMUMAB_user = 1 then 1 else 0 end) as n_adalimumab_users
  from plan.plan_patient_adalimumab
  group by year, plan_id
  order by year, plan_id;
quit;
data yearly_plan_patien_adalimumab; set yearly_plan_patien_adalimumab; if n_adalimumab_users > 0 then ADALIMUMAB_plan=1; else ADALIMUMAB_plan=0; run;
data sample; set yearly_plan_patien_adalimumab; if ADALIMUMAB_plan=1; run;

proc means data=sample n nmiss median q1 q3 min max;
    class year;
    var n_adalimumab_users;
run;



* claim_count; 
proc means data=plan.eric_plan_summary n nmiss median q1 q3 min max; var claim_count; run;
proc means data=plan.eric_plan_summary n nmiss median q1 q3 min max;
    class ADALIMUMAB_plan;
    var claim_count;
run;

* ADALIMUMAB_count;
proc means data=plan.eric_plan_summary n nmiss median q1 q3 min max;
    class ADALIMUMAB_plan;
    var ADALIMUMAB_count;
run;

* pct_ADALIMUMAB;
proc means data=plan.eric_plan_summary n nmiss median q1 q3 min max;
    class ADALIMUMAB_plan;
    var pct_ADALIMUMAB;
run;

* adalimumab_PD; 
proc means data=plan.eric_plan_summary n nmiss median q1 q3 min max;
    class ADALIMUMAB_plan;
    var adalimumab_PD;
run;

* pct_adalimumab_PD; 
proc means data=plan.eric_plan_summary n nmiss median q1 q3 min max; var pct_adalimumab_PD; run;
proc means data=plan.eric_plan_summary n nmiss median q1 q3 min max;
    class ADALIMUMAB_plan;
    var pct_adalimumab_PD;
run;

* patient number;
proc means data=plan.eric_plan_summary n nmiss median q1 q3 min max; var year; run;
proc means data=plan.eric_plan_summary n nmiss median q1 q3 min max;
    class ADALIMUMAB_plan;
    var year;
run;


