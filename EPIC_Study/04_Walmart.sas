
proc print data=input.joe_plan_mapping (obs=20); run;
proc contents data=input.joe_plan_mapping ; run;

/* merge with 25 data */
proc sql;
 create table input.joe_plan_mapping_25 as
 select distinct a.*, b.
 from input.joe_plan_mapping as a
 left join biosim.insurance_patient_year25 as b
 on a.patient_id = b,patient_id;
quit;

proc print data=biosim.insurance_patient_year25_new (obs=20); run;

libname xptfile xport "/dcs07/hpm/data/iqvia_fia/biosim/insurance_patient_year25.sas7bdat";

proc contents data=xptfile._all_ nods;
run;

proc contents data=biosim.insurance_patient_year1724; run;

mv /dcs07/hpm/data/iqvia_fia/biosim/insurance_patient_year1724.xpt \
   /dcs07/hpm/data/iqvia_fia/biosim/insurance_patient_year1724.sas7bdat 

filename f "/dcs07/hpm/data/iqvia_fia/biosim/insurance_patient_year25.sas7bdat";

data _null_;
  infile f recfm=n lrecl=256 obs=1;
  input;
  put "FIRST80_HEX=" _infile_ $hex160.;
run;


filename f "/dcs07/hpm/data/iqvia_fia/biosim/insurance_patient_year25.sas7bdat";
data _null_;
  infile f recfm=n lrecl=256;
  input x $char256.;
  put "FIRST256_HEX=" x $hex512.;
run;


/*============================================================*
 | 1. id for WALMART employees
 *============================================================*/

data plan.id_walmart; set plan.eric_claim; if index(upcase(plan_name), "WALMART") > 0; run;
proc sql;
    create table plan.id_walmart as
    select distinct patient_id
    from plan.id_walmart;
quit;

/*============================================================*
 | 2. all claims for the WALMART employees
 *============================================================*/

proc contents data=biosim.RxFact2025; run;  /* 36 var */
proc contents data=input.RxFact_2018_2024_ili; run; /* 35 var */


/* 2017 ~ 2024 */
proc sql; 
  create table walmart_claim_1824 as
  select distinct a.*
  from input.RxFact_2018_2024_ili as a 
  inner join plan.id_walmart as b
  on a.patient_id = b.patient_id;
quit;

/* 2025 */
proc sql; 
  create table walmart_claim_25 as
  select distinct a.*
  from biosim.RxFact2025 as a 
  inner join plan.id_walmart as b
  on a.patient_id = b.patient_id;
quit;

data plan.walmart_claim; set walmart_claim_1824 walmart_claim_25; run; 
proc print data=plan.walmart_claim (obs=10); where year=2025; run;

/* number of claims by year */
proc freq data=plan.walmart_claim; table year; run;

proc contents data=plan.walmart_claim; run; /* 35396095 claims */


proc sql; 
    select count(distinct patient_id) as count_patient_all
    from plan.walmart_claim;
quit;

/* number of patients by year */
proc sql;
  create table patient_count_by_year as
  select 
      year,
      count(distinct patient_id) as count_patient_all
  from plan.walmart_claim
  group by year(svc_dt)
  order by year;
quit;
proc sort data=patient_count_by_year nodupkey; by _ALL_; run;
proc print data= patient_count_by_year (obs=10); run;


/*============================================================*
 | 3. patient-year-plan level data
 *============================================================*/
 
/* joe's summary file
insurance_patient_year25
/dcs07/hpm/data/iqvia_fia/parquet/data/insurance_patient_year25.parquet
insurance_patient_year.parquet
 */

data plan.walmart_claim; set plan.walmart_claim; if index(upcase(molecule_name), "ADALIMUMAB") > 0 then study_drug = "ADALIMUMAB";  run;


/* yearly patient-plan users */
%macro yearly(year=);

data data_&year;
  set plan.walmart_claim;
  where year = &year;
run;

proc sort data=data_&year;
  by patient_id plan_id svc_dt;
run;

data data_&year;
  set data_&year;
  by patient_id plan_id;

  length study_drug_u glp1_u $50;
  study_drug_u = upcase(strip(study_drug));
  glp1_u       = upcase(strip(glp1));   /* only if glp1 exists */

  if first.plan_id then do;
    n_claim = 0;
    n_claimPD = 0;
    n_claimRJ = 0;
    n_claimRV = 0;

    ADALIMUMAB_count = 0;
    ADALIMUMAB_PD_count = 0;
    ADALIMUMAB_RJ_count = 0;
    ADALIMUMAB_RV_count = 0;

    last_date = .;
  end;

  /* claim counts */
  n_claim + 1;
  if encnt_outcm_cd = "PD" then n_claimPD + 1;
  else if encnt_outcm_cd = "RJ" then n_claimRJ + 1;
  else if encnt_outcm_cd = "RV" then n_claimRV + 1;


  if study_drug_u = "ADALIMUMAB" then ADALIMUMAB_count + 1;
    if study_drug_u = "ADALIMUMAB" and encnt_outcm_cd = "PD" then ADALIMUMAB_PD_count + 1;
    if study_drug_u = "ADALIMUMAB" and encnt_outcm_cd = "RJ" then ADALIMUMAB_RJ_count + 1;
    if study_drug_u = "ADALIMUMAB" and encnt_outcm_cd = "RV" then ADALIMUMAB_RV_count + 1;
 

  /* output once per patient-plan */
  if last.plan_id then output;

  format last_date mmddyy10.;

  keep year patient_id plan_id
       plan_name adjudicating_pbm_plan_name model_type
       n_claim n_claimPD n_claimRJ n_claimRV
       ADALIMUMAB_count ADALIMUMAB_PD_count ADALIMUMAB_RJ_count ADALIMUMAB_RV_count;
run;

data data_&year;
  set data_&year;
  ADALIMUMAB_user = (ADALIMUMAB_count > 0);
run;

%mend yearly;

%yearly(year=2025);
%yearly(year=2024);
%yearly(year=2023);
%yearly(year=2022);
%yearly(year=2021);
%yearly(year=2020);
%yearly(year=2019);
%yearly(year=2018);
%yearly(year=2017);

proc print data=data_2025 (obs=20); where ADALIMUMAB_count >0; run;
data plan.walmart_patient;
  set data_2025 data_2024 data_2023 data_2022 data_2021 data_2020 data_2019 data_2018 data_2017;
run;

/* index data and last date */
proc sort data=plan.walmart_claim; by patient_id svc_dt; run;
data index_date; set plan.walmart_claim; by patient_id; if first.patient_id; run;

proc sort data=plan.walmart_claim; by patient_id descending svc_dt; run;
data last_date; set plan.walmart_claim; by patient_id; if first.patient_id; run;

/* merge with patient's wide dataset */
proc sql;
 create table plan.walmart_patient as
 select distinct a.*, b.svc_dt as index_date
 from plan.walmart_patient as a
 left join index_date as b 
 on a.patient_id = b.patient_id;
quit;
proc sql;
 create table plan.walmart_patient as
 select distinct a.*, b.svc_dt as last_date
 from plan.walmart_patient as a
 left join last_date as b 
 on a.patient_id = b.patient_id;
quit;

data plan.walmart_patient; set plan.walmart_patient; duration_month = (last_date - index_date) /30; run;
proc means data=plan.walmart_patient n nmiss mean std median q1 q3; var duration_month; run;

data plan.walmart_patient; set plan.walmart_patient; 

proc means data=plan.walmart_patient n nmiss mean std median q1 q3; var n_claim; run;

* remove the missingness in plan_id; 
data plan.walmart_patient; set plan.walmart_patient; if not missing(plan_id); run;
data plan.walmart_patient; set plan.walmart_patient; if not missing(n_claim); run;

/* identify adalimumab inside of walmart vs outside of walmart */
data plan.walmart_patient; set plan.walmart_patient; if index(upcase(plan_name), "WALMART") > 0 then walmart =1; else walmart=0; run;

data plan.walmart_patient; set plan.walmart_patient; 
  length plan_type $20;
  plan_type='';
  
  if upcase(model_type)='CASH'                          then plan_type='Cash';
  else if upcase(model_type) in ('DISC CRD','DISC MED','SR CRD')
                                                        then plan_type='Discount Card';
  else if upcase(model_type)='VOUCHER'                  then plan_type='Coupon/Voucher';
  else if upcase(model_type)='FFS MED'                  then plan_type='Medicaid FFS';
  else if index(upcase(model_type),'HIX')>0             then plan_type='Exchange';
  else if upcase(model_type) in ('MED PDPG','MED PDP','DE MMP','EMP PDP','EMP RPDP')
                                                        then plan_type='Medicare TM';
  else if upcase(model_type) in ('MED ADVG','MED ADV','MED SNP','MED SNPG')
                                                        then plan_type='Medicare ADV';
  else if upcase(model_type) in ('MGD MEDI','MEDICAID') then plan_type='Medicaid MCO';
  else if upcase(model_type) in
       ('CDHP','COMBO','HMO','HMO - HR','INDIVIDUAL','PPO','POS','TRAD IND','WRAP',
        'EMPLOYER','STATE EMP','FED EMP','PBM','PBM BOB','NON-HMO','NETWORK',
        'GROUP','IPA','STAFF','EPO')                    then plan_type='Commercial';
  else plan_type='Other';
run;
proc freq data=plan.walmart_patient; table plan_type; run;
proc print data=plan.walmart_patient (obs=10); run;

/*============================================================*
 | 4. Adalimumab use in Walmart employee
 *============================================================*/

data adalimumab_patient; set plan.walmart_patient; if ADALIMUMAB_count >0; run;
proc freq data=adalimumab_patient; table ADALIMUMAB_user*year; run;
proc freq data=adalimumab_patient; table ADALIMUMAB_user*walmart; run;


proc sql; 
    select count(distinct patient_id) as count_patient_all
    from adalimumab_patient;
quit;

data walmart; set adalimumab_patient; if walmart=0; run;
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from walmart;
quit;


data sample; set plan.walmart_patient; if ADALIMUMAB_count >0 and walmart =1; run;
proc freq data=sample; table plan_type; run;
proc freq data=sample; table ADALIMUMAB_user*year; run;

/* plot */
data yearly_patient_counts;
  length year 8 n_walmart_enrollees 8 n_adalimumab_users_anyplan 8;
  infile datalines dsd truncover;
  input year n_walmart_enrollees n_adalimumab_users_anyplan;
datalines;
2025,80450,713
2024,87362,919
2023,88721,1047
2022,89060,725
2021,90822,615
2020,87138,630
2019,85483,447
2018,84036,311
2017,79645,260
;
run;

/* View the table */
proc print data=yearly_patient_counts noobs;
  var year n_walmart_enrollees n_adalimumab_users_anyplan;
  label
    n_walmart_enrollees         = "Walmart plan Enrollees, N"
    n_adalimumab_users_anyplan  = "Adalimumab users (from any plan), N";
run;

proc transpose data=yearly_patient_counts
    out=year_summary (drop=_NAME_);
  id year;   /* years become columns */
  var n_walmart_enrollees 
      n_adalimumab_users_anyplan;
run;
proc print data=year_summary; run;

proc sgplot data=yearly_patient_counts;

  /* Walmart plan enrollees */
  vbar year / response=n_walmart_enrollees
      groupdisplay=cluster barwidth=0.55
      fillattrs=(color=cx1F77B4) transparency=0.1
      legendlabel="Walmart plan Enrollees (N)";

  /* Adalimumab users (any plan) */
  vbar year / response=n_adalimumab_users_anyplan
      groupdisplay=cluster barwidth=0.55
      fillattrs=(color=cxFF7F0E) transparency=0.1
      legendlabel="Adalimumab Users (Any plan) (N)";

  xaxis label="Year" integer;
  yaxis label="Number of Patients" grid;

  keylegend / position=topright across=1 title="Patient Counts";

  title "Walmart Plan Enrollees & Adalimumab Users by Year";
run;

/*============================================================*
 | 5. biosim.ADALIMUMAB_NDCs (usc_3_description, molecule_name, drug_labeler_corp_name, category)
 *============================================================*/

proc print data=biosim.ADALIMUMAB_NDCs; run;
data plan.walmart_ADALIMUMAB_claim; set plan.walmart_claim; if study_drug = "ADALIMUMAB";  run; /* 59829 claims */
data plan.walmart_ADALIMUMAB_claim; set plan.walmart_ADALIMUMAB_claim; if index(upcase(plan_name), "WALMART") > 0 then walmart =1; else walmart=0; run;

proc sql;
 create table plan.walmart_ADALIMUMAB_claim as 
 select distinct a.*, b.*
 from plan.walmart_ADALIMUMAB_claim as a
 left join biosim.ADALIMUMAB_NDCs as b
 on a.product_ndc = b.product_ndc;
quit;

data plan.walmart_ADALIMUMAB_claim; set plan.walmart_ADALIMUMAB_claim; if category in ("biosimilar_RYVK","biosimilar_ADBM","biosimilar_ADAZ") then category = "biosimilar"; else category = category; run;

proc freq data=plan.walmart_ADALIMUMAB_claim; table category; run;
proc freq data=plan.walmart_ADALIMUMAB_claim; table category*walmart; run;

/* only for paid claims */
data sample; set plan.walmart_ADALIMUMAB_claim; if encnt_outcm_cd = "PD"; run;
proc freq data=sample; table category; run;
proc freq data=sample; table category*walmart; run;
                                                        
/*============================================================*
 | 6. find the dominent plan withint Walmart users 
 *============================================================*/

proc print data=plan.walmart_patient (obs=10); run;



/* 2025 */
data claim25; set plan.walmart_claim; if year=2025; run;
proc sort data= claim25; by patient_id plan_id; run;

data patient_claim25;
  set claim25;
  by patient_id plan_id;
  
  if first.plan_id then n_claim = 0;
  n_claim + 1;
  if last.plan_id then output;
  
  keep patient_id plan_id n_claim;
run;
proc print data=plan.walmart_patient (obs=10); run;

/* merge with the original table */
data walmart_patient_25; set plan.walmart_patient; if year=2025; run;
proc sql; 
  create table walmart_patient_25 as
  select distinct a.*, b.n_claim as year_total_n_claim
  from walmart_patient_25 as a
  left join patient_claim25 as b
  on a.patient_id = b.patient_id and a.plan_id = b.plan_id;
quit;

data donimant_claim_25; set walmart_patient_25; length dominant_plan $100.; if n_claim / year_total_n_claim > 0.5 then do; dominant_plan = plan_name; dominant_plan_id = plan_id; end; run;
proc print data=donimant_claim_25 (obs=10); run;
proc freq data=donimant_claim_25; table dominant_plan; run;

/* 2017-2024 */
proc contents data=input.joe_plan_mapping ; run;

/* merge with the original table */
data walmart_patient_1724; set plan.walmart_patient; if year < 2025; run;
proc sql; 
  create table donimant_claim_1724 as
  select distinct a.*, b.plan_name as dominant_plan, b.plan_id as dominant_plan_id
  from walmart_patient_1724 as a
  left join input.joe_plan_mapping as b
  on a.patient_id = b.patient_id and a.plan_id = b.plan_id and a.year=b.year;
quit;
proc print data=donimant_claim_1724 (obs=10); run;
proc freq data=donimant_claim_1724; table dominant_plan; run;


data input.dominant_plan_walmart; set donimant_claim_25 donimant_claim_1724; run;
data input.dominant_plan_walmart; set input.dominant_plan_walmart;
  length dominant_plan_type $20;
  dominant_plan_type='';

  if dominant_plan = "WALMART"                         then dominant_plan_type='WALMART';
  else if upcase(model_type)='CASH'                          then dominant_plan_type='Cash';
  else if upcase(model_type) in ('DISC CRD','DISC MED','SR CRD')
                                                        then dominant_plan_type='Discount Card';
  else if upcase(model_type)='VOUCHER'                  then dominant_plan_type='Coupon/Voucher';
  else if index(upcase(model_type),'HIX')>0             then dominant_plan_type='Exchange';
  else if upcase(model_type) in ('MED PDPG','MED PDP','DE MMP','EMP PDP','EMP RPDP','MED ADVG','MED ADV','MED SNP','MED SNPG')
                                                        then dominant_plan_type='Medicare';
  else if upcase(model_type) in ('FFS MED', 'MGD MEDI','MEDICAID') then dominant_plan_type='Medicaid';
  else if upcase(model_type) in
       ('CDHP','COMBO','HMO','HMO - HR','INDIVIDUAL','PPO','POS','TRAD IND','WRAP',
        'EMPLOYER','STATE EMP','FED EMP','PBM','PBM BOB','NON-HMO','NETWORK',
        'GROUP','IPA','STAFF','EPO')                    then dominant_plan_type='Commercial';
  else dominant_plan_type='Other';
run;
data input.dominant_plan_walmart; set input.dominant_plan_walmart; if not missing(dominant_plan); run; /* 776996 obs */

proc sort data=input.dominant_plan_walmart; by patient_id year plan_id;  run;
proc print data=input.dominant_plan_walmart (obs=10); var patient_id year plan_id dominant_plan dominant_plan_id; run;

proc freq data=input.dominant_plan_walmart; table dominant_plan_type; run;
proc freq data=input.dominant_plan_walmart; table dominant_plan_type*year; run;

/* area plot */
proc freq data=input.dominant_plan_walmart noprint;
  tables dominant_plan_type*year / out=freq_out outpct;
run;
data freq_out; set freq_out; if year <2025; run;
proc print data=freq_out; run;

data area_pct;
  set freq_out;
  keep year dominant_plan_type PCT_COL;
run;

proc sort data=area_pct; by year dominant_plan_type; run;
proc print data=area_pct; run;

proc sgplot data=area_pct;

    vbar year /
        response=PCT_COL
        group=dominant_plan_type
        groupdisplay=stack
        stat=sum
        datalabel;

    xaxis label="Year" integer;
    yaxis label="Percent of Enrollees"
          values=(0 to 100 by 20)
          grid;

    keylegend / position=right title="Dominant Plan Type";

    title "Dominant Plan Type Distribution by Year";
run;


/*============================================================*
 | 4. Merge with the dominant files
 *============================================================*/




 
/*============================================================*
 | 4. Merge with the dominant files
 *============================================================*/
 
proc import
  datafile="/dcs07/hpm/data/iqvia_fia/biosim/insurance_patient_year25.csv"
  out=biosim.insurance_patient_year25_new
  dbms=csv
  replace;
  guessingrows=max;
run;

proc import
  datafile="/dcs07/hpm/data/iqvia_fia/biosim/insurance_patient_year1724.csv"
  out=biosim.insurance_patient_year1724_new
  dbms=csv
  replace;
  guessingrows=max;
run;
proc print data=biosim.insurance_patient_year1724 (obs=10); run;


