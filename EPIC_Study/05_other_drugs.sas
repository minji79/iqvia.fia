
/*============================================================*
 | 1. Patient-year level for insulin glargine (IG)
 | INSULIN GLARGINE (46 ndc), INSULIN GLARGINE-YFGN (11 ndc), INSULIN GLARGINE-AGLR (1 ndc), INSULIN GLARGINE-LIXISENATIDE (1 ndc)
 *============================================================*/

/* 59 ndc list for insulin glargine */
data insulin_glargine; set biosim.product; if index(upcase(molecule_name), "INSULIN GLARGINE") > 0; run;
proc print data=insulin_glargine; run;
proc freq data=insulin_glargine; table molecule_name; run;


data plan.eric_claim; set plan.eric_claim; 
  if upcase(molecule_name) = "INSULIN GLARGINE" and usc_5_description ne "DIABETIC ACCESSORIES" then ig_indicator = "reference_biologics"; 
  else if upcase(molecule_name) = "INSULIN GLARGINE-YFGN" and usc_5_description ne "DIABETIC ACCESSORIES" then ig_indicator = "biosimilar_YFGN"; 
  else if upcase(molecule_name) = "INSULIN GLARGINE-AGLR" and usc_5_description ne "DIABETIC ACCESSORIES" then ig_indicator = "biosimilar_AGLR"; 
else ig_indicator = .; run;

proc print data=plan.eric_claim (obs=10); where index(upcase(molecule_name), "INSULIN GLARGINE") > 0; var molecule_name ig_indicator; run;


/* IG_user */
/* yearly users */
%macro yearly(year=);

data data_&year; set plan.eric_claim; where year = &year; run;

proc sort data=data_&year; by patient_id year; run;

data data_&year;
  set data_&year;
  by patient_id year;

  length study_drug_u $50;
  study_drug_u = upcase(strip(study_drug));
  glp1_u = upcase(strip(glp1));

  if first.patient_id then do;
    claim_count = 0;
    ADALIMUMAB_count = 0;
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
  keep year patient_id claim_count ADALIMUMAB_count ADALIMUMAB_PD_count ADALIMUMAB_RJ_count ADALIMUMAB_RV_count last_date;
  
run;

data data_&year; set data_&year; if ADALIMUMAB_count >0 then ADALIMUMAB_user=1; else ADALIMUMAB_user=0; run;

%mend yearly;
%yearly(year=2023);
%yearly(year=2022);
%yearly(year=2021);
%yearly(year=2020);
%yearly(year=2019);
%yearly(year=2018);
%yearly(year=2017);
%yearly(year=2025); /* 83004 indiv */
%yearly(year=2024); /* 106263 indiv */

data data_17_25; set data_2025 data_2024 data_2023 data_2022 data_2021 data_2020 data_2019 data_2018 data_2017; run;

proc sql;
  create table yearly_patient_counts as
  select
      year,
      count(distinct patient_id) as n_patients,
      sum(ADALIMUMAB_user=1) as n_adalimumab_users
  from data_17_25
  group by year
  order by year;
quit;
proc print data= yearly_patient_counts (obs=10); run;

/* transpose the table */
proc transpose data=yearly_patient_counts
    out=year_summary (drop=_NAME_);
  id year;              /* years become columns */
  var n_patients n_adalimumab_users;
run;
proc print data=year_summary; run;

/* plot */
proc sgplot data=yearly_patient_counts;
  vbar year / response=n_patients
      groupdisplay=cluster barwidth=0.55
      fillattrs=(color=cx1F77B4) transparency=0.1
      legendlabel="Total Patients (N)";

  vbar year / response=n_ADALIMUMAB_users
      groupdisplay=cluster barwidth=0.55
      fillattrs=(color=cxFF7F0E) transparency=0.1
      legendlabel="Adalimumab Users (N)";

  xaxis label="Year" integer;
  yaxis label="Number of Patients" grid;
  keylegend / position=topright across=1 title="Patient Counts";
  title "Total Number of Enrollees & Adalimumab Users in ERIC plans by year";
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

/* user number */
/* 1) plan_id x patient_id level: count adalimumab claims */
proc sql;
  create table patient_level_adalimumab as
  select
      plan_id,
      patient_id,
      sum(case 
            when index(upcase(strip(study_drug)),"ADALIMUMAB") > 0 then 1 
            else 0 
          end) as n_adalimumab_claims
  from plan.eric_claim
  group by plan_id, patient_id
  order by plan_id, patient_id;
quit;

/* quick check: patients with >1 adalimumab claim */
proc print data=patient_level_adalimumab(obs=10);
  where n_adalimumab_claims > 1;
run;

/* 2) plan level summary */
proc sql;
  create table plan_level_adalimumab as
  select
      plan_id,
      count(*) as n_patients,  /* one row per patient_id already */
      sum(case when n_adalimumab_claims > 0 then 1 else 0 end) as n_adalimumab_users,
      (calculated n_adalimumab_users > 0) as ADALIMUMAB_plan
  from patient_level_adalimumab
  group by plan_id
  order by plan_id;
quit;

proc sql;
  create table plan.eric_plan_summary as
  select a.*, b.n_adalimumab_users 
  from plan.eric_plan_summary as a
  left join plan_level_adalimumab as b
  on a.plan_id = b.plan_id;

quit;

/* Table 2 */
proc sort data=plan.eric_plan_summary; by descending n_adalimumab_users; run;
proc print data=plan.eric_plan_summary; 
var plan_id plan_name patient_count n_adalimumab_users claim_count ADALIMUMAB_count adalimumab_PD pct_adalimumab_PD pct_adalimumab_RJ pct_adalimumab_RV; 
run;



