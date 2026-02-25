/************************************************************************************
| Project name : Biosimilar 
| Program name : 01_Cohort_dertivation
| Date (update): June 2024
| Task Purpose : 
|      1. 00
| Main dataset : (1) procedure, (2) tx.patient, (3) tx.patient_cohort & tx.genomic (but not merged)
| Final dataset : min.bs_user_all_v07 (with distinct indiv)
************************************************************************************/

/************************************************************************************
	1. NDCs for Adalimumab & claims with Adalimumab use - use pre-identified files
************************************************************************************/
/* 
%macro yearly(data=, refer=);

data &data;
  set &refer;
  if index(upcase(molecule_name),'ADALIMUMAB')>0;
run;

%mend yearly;
%yearly(data=input.adalimumab_24_v00, refer=input.RxFact2024);
%yearly(data=input.adalimumab_22_v00, refer=input.RxFact2022);
%yearly(data=input.adalimumab_20_v00, refer=input.RxFact2020);
%yearly(data=input.adalimumab_18_v00, refer=input.RxFact2018);
*/

* use pre-identified files;
* for ndc codes;
proc import datafile="/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r/data/ADALIMUMAB_NDCs.dta" out=input.ADALIMUMAB_NDCs dbms=dta replace; run;
* for claims;
proc import datafile="/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/stata/data/A_ADALIMUMAB_claims.dta" out=input.A_ADALIMUMAB_claims dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/stata/data/B_ADALIMUMAB_claims.dta" out=input.B_ADALIMUMAB_claims dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/stata/data/A_analytic_file.dta" out=input.A_analytic_file dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/stata/data/B_analytic_file.dta" out=input.B_analytic_file dbms=dta replace; run;

/* I will use input.A_analytic_file for further analysis, which include 682966 obs with 48 variables, and delete other files */

proc contents data=input.ADALIMUMAB_NDCs; run;
proc print data=input.ADALIMUMAB_NDCs (obs=20); run;
proc freq data=input.ADALIMUMAB_NDCs; table molecule_name; run;

/************************************************************************************
	2. Categorize at NDC level
************************************************************************************/
proc print data=biosim.ADALIMUMAB_NDCs; run;

* 0. make indicators;
data biosim.ADALIMUMAB_NDCs; set biosim.ADALIMUMAB_NDCs; drop category; run;
data biosim.ADALIMUMAB_NDCs; set biosim.ADALIMUMAB_NDCs; length category $50; run;

/*
category
 1. reference_biologics
 2. co_branded_biologics
 3. co_branded_biologics_not_cordavis
 4. private_label_biosimilar
 5. biosimilar 
 6. biosimilar_ADAZ
 7. biosimilar_ADBM
 8. biosimilar_RYVK
*/

* 1. molecule_name=ADALIMUMAB | Original OR co-branded;
proc sort data=biosim.ADALIMUMAB_NDCs; by category drug_labeler_corp_name; run;
proc print data=biosim.ADALIMUMAB_NDCs; where molecule_name = "ADALIMUMAB"; title "molecule_name=ADALIMUMAB | Original and co-branded"; run;

data biosim.ADALIMUMAB_NDCs; set biosim.ADALIMUMAB_NDCs; 
	if molecule_name = "ADALIMUMAB" and drug_labeler_corp_name in ("ABBVIE", "ABBVIE US LLC", "ABBOTT") then category = "reference_biologics"; 
	else if molecule_name = "ADALIMUMAB" and drug_labeler_corp_name in ("CORDAVIS LIMITED") then category = "co_branded_biologics"; 
    else if molecule_name = "ADALIMUMAB" and drug_labeler_corp_name in ("PHYSICIANS TOTAL CARE", "A-S MEDICATION SOLUTIONS", "CLINICAL SOLUTIONS WHOLESALE") then category = "co_branded_biologics"; 
run;


* 2. molecule_name=ADALIMUMAB-ADAZ | private_label_biosimilar OR biosimilar ;
proc print data=input.ADALIMUMAB_NDCs; where molecule_name = "ADALIMUMAB-ADAZ"; title "molecule_name=ADALIMUMAB-ADAZ | private_label_biosimilar OR biosimilar"; run;
proc sort data=input.ADALIMUMAB_NDCs; by category; run;

data biosim.ADALIMUMAB_NDCs; set biosim.ADALIMUMAB_NDCs; 
    if molecule_name = "ADALIMUMAB-ADAZ" and drug_labeler_corp_name = "NOVARTIS" then category = "biosimilar_ADAZ";
    else if molecule_name = "ADALIMUMAB-ADAZ" and drug_labeler_corp_name = "CORDAVIS LIMITED" then category = "private_label_biosimilar";
run;

* 3. molecule_name=ADALIMUMAB-ADBM | private_label_biosimilar OR biosimilar ;
proc print data=input.ADALIMUMAB_NDCs; where molecule_name = "ADALIMUMAB-ADBM"; title "molecule_name=ADALIMUMAB-ADBM | private_label_biosimilar OR biosimilar"; run;
proc sort data=input.ADALIMUMAB_NDCs; by category drug_labeler_corp_name; run;

data biosim.ADALIMUMAB_NDCs; set biosim.ADALIMUMAB_NDCs; 
    if molecule_name = "ADALIMUMAB-ADBM" and drug_labeler_corp_name = "BOEHRINGER INGELHEIM" and product_ndc in (597037082, 597037516, 597037523, 597037597, 597040089, 597040580, 597049550) then category = "biosimilar_ADBM";
    else if molecule_name = "ADALIMUMAB-ADBM" and drug_labeler_corp_name = "BOEHRINGER INGELHEIM" and product_ndc not in (597037082, 597037516, 597037523, 597037597, 597040089, 597040580, 597049550) then category = "biosimilar_ADBM";
	else if molecule_name = "ADALIMUMAB-ADBM" and drug_labeler_corp_name = "QUALLENT" then category = "private_label_biosimilar";
run;

* 4. molecule_name=ADALIMUMAB-RYVK | private_label_biosimilar OR biosimilar ;
proc print data=input.ADALIMUMAB_NDCs; where molecule_name = "ADALIMUMAB-RYVK"; title "molecule_name=ADALIMUMAB-RYVK | private_label_biosimilar OR biosimilar"; run;
proc sort data=input.ADALIMUMAB_NDCs; by category drug_labeler_corp_name; run;

data biosim.ADALIMUMAB_NDCs; set biosim.ADALIMUMAB_NDCs; 
    if molecule_name = "ADALIMUMAB-RYVK" and drug_labeler_corp_name = "QUALLENT" then category = "private_label_biosimilar";
    else if molecule_name = "ADALIMUMAB-RYVK" and drug_labeler_corp_name = "TEVA PHARMACEUTICALS USA" then category = "biosimilar_RYVK";
run;

* 5. molecule_name=others | biosimilar ;
proc print data=input.ADALIMUMAB_NDCs; where molecule_name = "ADALIMUMAB-FKJP"; title "molecule_name=ADALIMUMAB-FKJP | biosimilar"; run;

data biosim.ADALIMUMAB_NDCs; set biosim.ADALIMUMAB_NDCs; 
    if molecule_name in ("ADALIMUMAB-AACF", "ADALIMUMAB-AATY", "ADALIMUMAB-AFZB", "ADALIMUMAB-AQVH", "ADALIMUMAB-ATTO", "ADALIMUMAB-BWWD", "ADALIMUMAB-FKJP") then category = "biosimilar";
run;


/************************************************************************************
	3. merge with the NDCs with claims
************************************************************************************/

/* 2017 - 2024 */
proc sql; 
	create table biosim.adalimumab_claim_v0 as
 	select distinct a.*, b.category
    from input.A_analytcd dataic_file as a
	left join biosim.ADALIMUMAB_NDCs as b
 	on a.product_ndc = b.product_ndc; 
quit;
proc contents data=biosim.adalimumab_claim_v0; run;
proc print data=biosim.adalimumab_claim_v0 (obs=10); run;
proc print data=biosim.adalimumab_claim_v0 (obs=20); var month_id week_id; run;

proc contents data=biosim.RxFact2025_clean; run;
data adalimumab_25; set biosim.RxFact2025_clean; if index(upcase(molecule_name), "ADALIMUMAB") > 0; run;
proc sql; 
  create table adalimumab_25 as
  select distinct a.*, b.*
  from adalimumab_25 as a 
  inner join biosim.ADALIMUMAB_NDCs as b
  on a.product_ndc = b.product_ndc; 
quit;

data adalimumab_1724; set biosim.adalimumab_claim_v0; drop ama_do_not_contact_ind ama_pdrp_ind ama_pdrp_ind cob_ind daw_cd 	daw_cd_s days_to_adjudct_cnt dspnsd_qty
 merge1 merge2 patient_group pay_type_description rx_orig_cd rx_typ_cd rx_written_dt sob_desc sob_value switch_date; run;
data adalimumab_25; set adalimumab_25; drop branded_generic; run;
data adalimumab_25; set adalimumab_25;
  month_id = year(svc_dt)*100 + month(svc_dt);
  week_start = intnx('week', svc_dt, 0, 'b');

  week_id = year(week_start)*10000 +
            month(week_start)*100 +
            day(week_start);

  format week_start mmddyy10.;
run;

data biosim.adalimumab_claim_v1; set adalimumab_1724 adalimumab_25; run; 
data biosim.adalimumab_claim_v1; set biosim.adalimumab_claim_v1; year = year(svc_dt); run;

data biosim.adalimumab_claim_v1; set biosim.adalimumab_claim_v1; if category in ("biosimilar_RYVK","biosimilar_ADBM","biosimilar_ADAZ") then category = "biosimilar_RYVK_ADBM_ADAZ"; else category = category; run;


proc sql;
    create table counts as
    select year,
           category,
           count(*) as count
    from biosim.adalimumab_claim_v1
    group by year, category;
quit;
proc print data=counts; run;


/************************************************************************************
	4. Area plot for stacked by category with month_id
************************************************************************************/

/* 1) Aggregate counts by month & category */
proc sql;
    create table counts as
    select month_id,
           category,
           count(*) as count
    from biosim.adalimumab_claim_v1
    group by month_id, category
    order by month_id, calculated count desc;
quit;

/* 2) Convert YYYYMM month_id to SAS date (first day of month) */
data counts_d;
  set counts;
  length month_dt 8;
  /* Works for numeric or character month_id */
  if vtype(month_id)='N' then month_dt = input(put(month_id, 6.), yymmn6.);
  else                       month_dt = input(month_id, yymmn6.);
  format month_dt monyy7.; /* Displays as MONYYYY */
run;

/* 3) Sort for stacking */
proc sort data=counts_d; 
    by month_dt category; 
run;

/* 4) Build cumulative lower/upper bounds for stacking */
data cum;
  set counts_d;
  by month_dt;
  retain lower 0;
  if first.month_dt then lower=0;
  upper = lower + count;
  output;
  lower = upper;
run;

/* 5) Stacked area plot using BAND */
proc sgplot data=cum;
  band x=month_dt lower=lower upper=upper / group=category transparency=0.1;
  xaxis type=time interval=month valuesformat=monyy7.;
  yaxis label="Count";
run;

/************************************************************************************
	6. Area plot for stacked by category with month_id
************************************************************************************/

/* 1) Aggregate counts by month & category */
proc sql;
    create table counts as
    select month_id,
           category,
           count(*) as count
    from biosim.adalimumab_claim_v1
    where category ne 'reference_biologics' /* filter here */
    group by month_id, category
    order by month_id, calculated count desc;
quit;

proc print data=counts; where 202401 < month_id  and month_id  < 202412; run;

/* clean them */
proc sql;
    create table counts as
    select month_id,
           category,
           count(*) as count
    from biosim.adalimumab_claim_v1
    where category ne 'reference_biologics' and month_id > 202212
    group by month_id, category
    order by month_id, calculated count desc;
quit;

/* 2) Convert YYYYMM month_id to SAS date (first day of month) */
data counts_d;
  set counts;
  length month_dt 8;
  if vtype(month_id)='N' then month_dt = input(put(month_id, 6.), yymmn6.);
  else                       month_dt = input(month_id, yymmn6.);
  format month_dt monyy7.;
run;

/* 3) Sort for stacking */
proc sort data=counts_d; 
    by month_dt category; 
run;

/* 4) Build cumulative lower/upper bounds for stacking */
data cum;
  set counts_d;
  by month_dt;
  retain lower 0;
  if first.month_dt then lower=0;
  upper = lower + count;
  output;
  lower = upper;
run;

/* 5) Stacked area plot using BAND */
proc sgplot data=cum;
  band x=month_dt lower=lower upper=upper / group=category transparency=0.1;
  xaxis type=time interval=month valuesformat=monyy7.;
  yaxis label="Count";
run;



/************************************************************************************
	7. Area plot for proportion stacked by category with month_id
************************************************************************************/

/* 1) Aggregate counts by month & category */
proc sql;
    create table counts as
    select month_id,
           category,
           count(*) as count
    from input.adalimumab_claim_v0
    group by month_id, category
    order by month_id, calculated count desc;
quit;

/* 2) Convert YYYYMM month_id to SAS date (first day of month) */
data counts_d;
  set counts;
  length month_dt 8;
  if vtype(month_id)='N' then month_dt = input(put(month_id, 6.), yymmn6.);
  else                       month_dt = input(month_id, yymmn6.);
  format month_dt monyy7.;
run;

/* 3) Calculate percentage of total per month */
proc sql;
    create table counts_pct as
    select month_dt,
           category,
           count,
           (count / sum(count) * 100) as pct format=6.1
    from counts_d
    group by month_dt
    order by month_dt, calculated pct desc;
quit;

/* 4) Sort for stacking */
proc sort data=counts_pct; 
    by month_dt category; 
run;

/* 5) Build cumulative lower/upper bounds for stacking */
data cum;
  set counts_pct;
  by month_dt;
  retain lower 0;
  if first.month_dt then lower=0;
  upper = lower + pct;
  output;
  lower = upper;
run;

/* 6) Stacked area plot (percentage) */
proc sgplot data=cum;
  band x=month_dt lower=lower upper=upper / group=category transparency=0.1;
  xaxis type=time interval=month valuesformat=monyy7.;
  yaxis label="Percentage" values=(0 to 100 by 10);
run;
