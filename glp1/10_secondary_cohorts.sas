
proc contents data=input.final_claims; run;
proc contents data=input.secondary_cohort_wide; run;
proc contents data=input.patients_v0; run;
proc contents data=input.rx18_24_glp1_long_v00; run;
proc contents data=input.rx18_24_glp1_long_v01; run;


/*============================================================*
|  1. final claim's OOP 
*============================================================*/
/* final claim's OOP */
data input.final_claims; set input.final_claims; oop_30day = final_opc_amt / days_supply_cnt * 30; run;

data final_claims_paid; set input.final_claims; if encnt_outcm_cd ="PD"; run; 
proc univariate data=final_claims_paid noprint;
    var oop_30day;
    output out=quantiles pctlpre=P_ pctlpts=25 50 75;
run;
*proc print data=quantiles (obs=10); run;

data input.final_claims; set input.final_claims;
 if oop_30day <= 0 and encnt_outcm_cd ="PD" then oop_30day_q = 1; 
 else if 0 < oop_30day <= 13.3875 and encnt_outcm_cd ="PD" then oop_30day_q = 2; 
 else if 13.3875 < oop_30day <= 26.7857 and encnt_outcm_cd ="PD" then oop_30day_q = 3; 
 else if 26.7857 < oop_30day and encnt_outcm_cd ="PD" then oop_30day_q = 4; 
 else oop_30day_q = 0; 
run;
*proc freq data=input.final_claims; table oop_30day_q; run;

/* final claim's OOP */
data input.final_claims; set input.final_claims; 
    length final_claim_disposition $50.;
    if encnt_outcm_cd ="PD" then final_claim_disposition = "Approved - paid";
    else if encnt_outcm_cd ="RV" then final_claim_disposition = "Approved - reversed";
    else if RJ_reason = "RJ_NtCv" then final_claim_disposition = "RJ_NtCv";
    else if RJ_reason in ("RJ_PrAu","RJ_Step","RJ_QtyLimit") then final_claim_disposition = "RJ_UM";
    else if RJ_reason in ("RJ_Coverage_Not_Active","RJ_Others_NotForm") then final_claim_disposition = "RJ_NotFormulary";
    *else if RJ_reason = "RJ by Secondary Payer" then final_claim_disposition = "RJ by Secondary Payer";
    else final_claim_disposition = "NA";
run;

proc freq data=input.final_claims; table final_claim_disposition; run;

/* lost to follow-up */
data input.final_claims; set input.final_claims; lost_follow_date = svc_dt + days_supply_cnt; format lost_follow_date MMDDYY10.; run;
proc print data=input.final_claims (obs=10); var lost_follow_date svc_dt days_supply_cnt; run;


/*============================================================*
|  2. Form a wide dataset of a secondary cohort for the COX analysis (N=768,646)
*============================================================*/

proc sql; 
  create table input.secondary_cohort_wide as
  select distinct a.*,
      b.svc_dt as final_claim_svc_dt, 
      b.lost_follow_date,
      b.oop_30day as final_claim_oop_30days, 
      b.oop_30day_q as final_claim_oop_30days_quantile, 
      b.days_supply_cnt as final_claim_days_supply_cnt,
      b.final_claim_disposition, 
      b.molecule_name as final_claim_molecule_name,
      b.payer_type as final_claim_payer_type,
      b.payer_type_indicator as final_claim_payer_type_indicator,
      b.plan_id as final_claim_plan_id,
      b.chnl_cd as final_claim_chnl_cd,
      b.indication as final_claim_indication,
      b.age_at_claim as final_claim_age_at_claim,
      b.dominant_payer as final_claim_dominant_payer,
      b.patient_gender,
      b.region
      
  from input.patients_v1 as a 
  left join input.final_claims as b
  on a.patient_id = b.patient_id;
quit;


* age_categories; 
data input.secondary_cohort_wide; set input.secondary_cohort_wide;
    length age_cat $20.;
    if 18 <= final_claim_age_at_claim and final_claim_age_at_claim < 35 then age_cat ="18-35"; 
    else if 35 <= final_claim_age_at_claim and final_claim_age_at_claim < 50 then age_cat ="35-50"; 
    else if 50 <= final_claim_age_at_claim and final_claim_age_at_claim < 65 then age_cat ="50-65"; 
    else if 65 <= final_claim_age_at_claim then age_cat ="65+"; 
    else age_cat ="NA"; 
run; 

* pool payer_type; 
data input.secondary_cohort_wide; set input.secondary_cohort_wide;
    length payer_type_adj $100.; 
    if final_claim_payer_type in ("Cash", "Coupon","Discount Card","PBM","PPO/HMO","Part B","Unspec","missing") then payer_type_adj = "Others"; 
    else if final_claim_payer_type in ("Medicaid: FFS","Medicaid: MCO","Medicaid: Unspec") then payer_type_adj = "Medicaid"; 
    else if final_claim_payer_type in ("Medicare D: ADV","Medicare D: TM","Medicare D: Unspec") then payer_type_adj = "Medicare"; 
    else payer_type_adj = final_claim_payer_type; 
run;

* pool payer_type; 
data input.secondary_cohort_wide; set input.secondary_cohort_wide;
    length dominant_payer_adj $100.; 
    if final_claim_dominant_payer in ("Medicaid: FFS","Medicaid: MCO","Medicaid: Unspec") then dominant_payer_adj = "Medicaid"; 
    else if final_claim_dominant_payer in ("Medicare D: ADV","Medicare D: TM","Medicare D: Unspec") then dominant_payer_adj = "Medicare"; 
    else dominant_payer_adj = final_claim_dominant_payer; 
run;

* pool final_claim_molecule_name;
data input.secondary_cohort_wide; set input.secondary_cohort_wide;
    length molecule_name_adj $100.; 
    if final_claim_molecule_name in ("DULAGLUTIDE","EXENATIDE","LIRAGLUTIDE","LIRAGLUTIDE (WEIGHT MANAGEMENT)") then molecule_name_adj = "Other GLP1s"; 
    else molecule_name_adj = final_claim_molecule_name; 
run;

* payment type;
data input.secondary_cohort_wide; set input.secondary_cohort_wide;
    if cash_ever = 0 and coupon_ever =0 and discount_card_ever = 0 then cashcoupon_use = 0; 
    else cashcoupon_use = 1; 
run;

*year;
data input.secondary_cohort_wide; set input.secondary_cohort_wide; final_claim_year = year(final_claim_svc_dt); run;
data input.secondary_cohort_wide; set input.secondary_cohort_wide; first_claim_year = year(first_date); run;

proc contents data=input.secondary_cohort_wide; run;

/* check the final users */
proc sql; 
    create table secondary_cohort_wide as
    select distinct a.*, b.dominant_payer
    from input.secondary_cohort_wide as a
    left join input.first_attempt as b
    on a.patient_id = b.patient_id;
quit;

proc freq data=secondary_cohort_wide; table diabetes_history*dominant_payer /norow nopercent; run;

/*============================================================*
|  3. Overall cohort: N of events (disc_at_1y) / N of patients
*============================================================*/
* Overall;
proc freq data=input.secondary_cohort_wide; table disc_at_1y; run;

* Age at the last claim;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*age_cat /norow nopercent; run;

* gender;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*patient_gender /norow nopercent; run;

* region;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*region /norow nopercent; run;

* payer type at the final claim;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*dominant_payer_adj/norow nopercent; run;

* diabetes history;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*diabetes_history/norow nopercent; run;

* final_claim_oop_30days_quantile;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*final_claim_oop_30days_quantile/norow nopercent; run;

* final_claim_disposition;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*final_claim_disposition/norow nopercent; run;

* payment;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*cashcoupon_use /norow nopercent; run;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*cash_ever /norow nopercent; run;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*coupon_ever /norow nopercent; run;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*discount_card_ever /norow nopercent; run;

* chennel; 
proc freq data=input.secondary_cohort_wide; table disc_at_1y*final_claim_chnl_cd /norow nopercent; run;

* last glp1 molecule_name;
proc freq data=input.secondary_cohort_wide; table disc_at_1y*molecule_name_adj /norow nopercent; run;

*year; 
proc freq data=input.secondary_cohort_wide; table disc_at_1y*first_claim_year /norow nopercent; run;


/*============================================================*
|  4. cohorts with / without diabetes: N of events (disc_at_1y) / N of patients
*============================================================*/
data sample; set input.secondary_cohort_wide; if diabetes_history =1; run;

* Overall;
proc freq data=sample; table disc_at_1y; run;

* Age at the last claim;
proc freq data=sample; table disc_at_1y*age_cat /norow nopercent; run;

* gender;
proc freq data=sample; table disc_at_1y*patient_gender /norow nopercent; run;

* region;
proc freq data=sample; table disc_at_1y*region /norow nopercent; run;

* payer type at the final claim;
proc freq data=sample; table disc_at_1y*dominant_payer_adj/norow nopercent; run;

* final_claim_oop_30days_quantile;
proc freq data=sample; table disc_at_1y*final_claim_oop_30days_quantile/norow nopercent; run;

* final_claim_disposition;
proc freq data=sample; table disc_at_1y*final_claim_disposition/norow nopercent; run;

* payment;
proc freq data=sample; table disc_at_1y*cashcoupon_use /norow nopercent; run;
proc freq data=sample; table disc_at_1y*cash_ever /norow nopercent; run;
proc freq data=sample; table disc_at_1y*coupon_ever /norow nopercent; run;
proc freq data=sample; table disc_at_1y*discount_card_ever /norow nopercent; run;

* chennel; 
proc freq data=sample; table disc_at_1y*final_claim_chnl_cd /norow nopercent; run;

* last glp1 molecule_name;
proc freq data=sample; table disc_at_1y*molecule_name_adj /norow nopercent; run;

*year; 
proc freq data=sample; table disc_at_1y*first_claim_year /norow nopercent; run;


/*============================================================*
|  5. last_date = first_date; run; /* 58608 individuals */
*============================================================*/

data idlist; set input.secondary_cohort_wide; if last_date = first_date; run; /* 58608 individuals */
data idlist; set input.secondary_cohort_wide; if lost_follow_date = first_date; run; /* 4 individuals */ 


proc sql;
  create table sample as 
  select a.*, b.first_date, b.final_claim_svc_dt
  from input.rx18_24_glp1_long_v01 as a
  inner join idlist as b
  on a.patient_id = b.patient_id;  
quit; /* 1062810 obs */
proc print data=sample (obs=50); var patient_id svc_dt encnt_outcm_cd first_date final_claim_svc_dt payer_type; run;

proc sql;
  create table sample2 as 
  select a.*, b.first_date, b.final_claim_svc_dt
  from input.rx18_24_glp1_long_v00 as a
  inner join idlist as b
  on a.patient_id = b.patient_id;  
quit; /* 1062810 obs */
proc sort data=sample2; by patient_id svc_dt; run;
proc print data=sample2 (obs=50); var patient_id svc_dt encnt_outcm_cd first_date final_claim_svc_dt payer_type; run;


/*============================================================*
 |      supplement TABLE 1 - for secondary cohort (N=984398)
 *============================================================*/
proc contents data=input.secondary_cohort_wide; run;

/*****************************
*  distribution by plan_type
*****************************/
proc freq data=input.secondary_cohort_wide; table dominant_payer_adj; run;

/*****************************
*  age at claim
*****************************/
data subpopulation; set input.first_attempt; if secondary_cohort=1; run; /* 622204 individuals */
proc means data=subpopulation n nmiss median q1 q3 min max; var age_at_claim; run;
proc means data=subpopulation n nmiss median q1 q3 min max;
    class dominant_payer_adj;
    var age_at_claim;
run;

/*****************************
*  gender
*****************************/
proc freq data=input.secondary_cohort_wide; table patient_gender; run;
proc freq data=input.secondary_cohort_wide; table patient_gender*dominant_payer_adj /norow nopercent; run;

/*****************************
*  region
*****************************/
proc freq data=input.secondary_cohort_wide; table region; run;
proc freq data=input.secondary_cohort_wide; table region*dominant_payer_adj /norow nopercent; run;

/*****************************
*  history of diabetes
*****************************/
proc freq data=input.secondary_cohort_wide; table diabetes_history; run;
proc freq data=input.secondary_cohort_wide; table diabetes_history*dominant_payer_adj /norow nopercent; run;

/*****************************
*  duration of medication
*****************************/
data input.secondary_cohort_wide; set input.secondary_cohort_wide; duration_in_month = (lost_follow_date - first_date)/30; run;

proc means data=input.secondary_cohort_wide n nmiss median q1 q3 min max; var duration_in_month; run;
proc means data=input.secondary_cohort_wide n nmiss median q1 q3 min max;
    class dominant_payer_adj;
    var duration_in_month;
run;

/*****************************
*  total number of paid claims
*****************************/
proc means data=input.secondary_cohort_wide n nmiss median q1 q3 min max; var paid_count; run;
proc means data=input.secondary_cohort_wide n nmiss median q1 q3 min max;
    class dominant_payer_adj;
    var paid_count;
run;

/*****************************
*  % of paid claims
*****************************/
proc means data=input.secondary_cohort_wide n nmiss median q1 q3 min max; var pct_fill; run;
proc means data=input.secondary_cohort_wide n nmiss median q1 q3 min max;
    class dominant_payer_adj;
    var pct_fill;
run;

/*****************************
*  cash use ever
*****************************/
proc freq data=input.secondary_cohort_wide; table cash_ever; run;
proc freq data=input.secondary_cohort_wide; table cash_ever*dominant_payer_adj /norow nopercent; run;

/*****************************
*  coupon use ever
*****************************/
proc freq data=input.secondary_cohort_wide; table coupon_ever; run;
proc freq data=input.secondary_cohort_wide; table coupon_ever*dominant_payer_adj /norow nopercent; run;

/*****************************
*  discount card use ever
*****************************/
proc freq data=input.secondary_cohort_wide; table discount_card_ever; run;
proc freq data=input.secondary_cohort_wide; table discount_card_ever*dominant_payer_adj /norow nopercent; run;

/*****************************
*  GLP1 types, indication of GLP1
*****************************/
proc freq data=input.secondary_cohort_wide; table first_glp1; run;
proc freq data=input.secondary_cohort_wide; table first_glp1*dominant_payer_adj /norow nopercent; run;

/*****************************
*  days_supply_cnt
*****************************/
proc means data=input.first_attempt n nmiss median q1 q3 min max; var days_supply_cnt; run;
proc means data=input.first_attempt n nmiss median q1 q3 min max;
    class dominant_payer_adj;
    var days_supply_cnt;
run;

/*****************************
*  initiation year
*****************************/
data input.secondary_cohort_wide; set input.secondary_cohort_wide; year_initiation = year(first_date); run;

proc freq data=input.secondary_cohort_wide; table year_initiation; run;
proc freq data=input.secondary_cohort_wide; table year_initiation*dominant_payer_adj /norow nopercent; run;

