
/*============================================================*
 |      TABLE 1 - first attempt (their first try to fill) 
 *============================================================*/

data first_attempt;
    set input.rx18_24_glp1_long_v00;        
    if encnt_outcm_cd = "PD" then paid_priority = 2;  
    else if encnt_outcm_cd = "RV" then paid_priority = 1;  
    else paid_priority = 0;
run;
proc sort data=first_attempt; by patient_id svc_dt descending paid_priority;  run;
/* proc print data=first_attempt (obs=30); var patient_id svc_dt encnt_outcm_cd paid_priority; run;*/

/* 3) Keep the first record per patient (earliest date; paid preferred if tie) */
data input.first_attempt;
    set first_attempt;
    by patient_id svc_dt;
    if first.patient_id then output;
    drop paid_priority;
run; /* 984,398 obs */


/* 4) count people who got approved glp1 after the first rejection in the same date  */
proc sort data=first_attempt; by patient_id svc_dt;  run;
data first_attempt_firstdate;
    set first_attempt;
    by patient_id svc_dt;

    /* Identify the first date per patient */
    if first.patient_id then first_date = svc_dt;
    retain first_date;

    /* Keep only rows where svc_dt = first_date */
    if svc_dt = first_date;
run;  /* 1,024,260 obs */


proc sql;
    create table first_attempt_firstdate_v1 as
    select a.patient_id,
           count(*) as count_claims
    from first_attempt_firstdate as a
    where a.patient_id in (
        select patient_id
        from input.first_attempt
        where encnt_outcm_cd = "RJ"
    )
    group by a.patient_id;
quit;  /* 220,341 obs */

proc print data=first_attempt_firstdate (obs=10); run;
data first_attempt_firstdate_v2; set first_attempt_firstdate_v1; if count_claims > 1; run; /* 8036 among 220,341 */


/*****************************
*  distribution by plan_type
*****************************/
proc freq data=input.first_attempt; table dominant_payer; run;

proc freq data=input.first_attempt; table encnt_outcm_cd; run;
proc freq data=input.first_attempt; table encnt_outcm_cd*dominant_payer /norow nopercent; run;

/*****************************
*  indication of GLP1
*****************************/
proc freq data=input.first_attempt; table indication; run;
proc freq data=input.first_attempt; table indication*dominant_payer /norow nopercent; run;

/*****************************
*  retail channel
*****************************/
proc freq data=input.first_attempt; table chnl_cd; run;
proc freq data=input.first_attempt; table chnl_cd*dominant_payer /norow nopercent; run;

/*****************************
*  gender
*****************************/
proc freq data=input.first_attempt; table patient_gender; run;
proc freq data=input.first_attempt; table patient_gender*dominant_payer /norow nopercent; run;


/*****************************
*  age at claim
*****************************/
proc means data=input.first_attempt n nmiss median q1 q3 min max; var age_at_claim; run;
proc means data=input.first_attempt n nmiss median q1 q3 min max;
    class dominant_payer;
    var age_at_claim;
run;

/*****************************
*  coupon use
*****************************/
proc freq data=input.first_attempt; table plan_type; run;
proc freq data=input.first_attempt; table plan_type*dominant_payer /norow nopercent; run;


/*****************************
*  GLP1 types, indication of GLP1
*****************************/
proc freq data=input.first_attempt; table molecule; run;
proc freq data=input.first_attempt; table molecule*dominant_payer /norow nopercent; run;

proc freq data=input.first_attempt; table region; run;
proc freq data=input.first_attempt; table region*dominant_payer /norow nopercent; run;

/*****************************
*  history of diabetes
*****************************/
proc freq data=input.first_attempt; table diabetes_history; run;
proc freq data=input.first_attempt; table diabetes_history*dominant_payer /norow nopercent; run;


/*****************************
*  OOP at index
*****************************/
* calculate oop for 30days; 
data input.first_attempt; set input.first_attempt; oop_30days = final_opc_amt / days_supply_cnt *30; run;

data oop;
    set input.first_attempt;
    if encnt_outcm_cd in ("RV","PD") and not missing(oop_30days);
run;

*only remain valid rows for calculating OOP;

data oop;
    set input.first_attempt;
    if encnt_outcm_cd = "PD" and not missing(oop_30days);
run;

proc means data=oop n nmiss median q1 q3 mean std min max; var oop_30days; run;
proc means data=oop n nmiss median q1 q3 min max;
    class dominant_payer;
    var oop_30days;
run;

/*****************************
*  days_supply_cnt
*****************************/
proc means data=input.first_attempt n nmiss median q1 q3 min max; var days_supply_cnt; run;
proc means data=input.first_attempt n nmiss median q1 q3 min max;
    class dominant_payer;
    var days_supply_cnt;
run;


/*****************************
*  reason of rejections among rejection
*****************************/
proc freq data=input.first_attempt; table RJ_reason; run;

data rejection; set input.first_attempt; if rjct_grp ne 0; run;
proc freq data=rejection; table RJ_reason; run;
proc freq data=rejection; table RJ_reason*dominant_payer  /norow nopercent; run;




/*============================================================*
 | Median days from first rejection to first approved fill (IQR)
 *============================================================*/
data rx18_24_glp1_long_v00;
    set input.rx18_24_glp1_long_v00;
    if encnt_outcm_cd in ("PD", "RV") then approved = 1;
    else approved = 0;
run;

proc sort data=rx18_24_glp1_long_v00; by patient_id svc_dt; run;
data rx18_24_glp1_long_v02;
    set rx18_24_glp1_long_v00;
    by patient_id svc_dt;

    retain first0_date first1_date gap first_approved;
    format first0_date first1_date yymmdd10.;

    if first.patient_id then do;
        first0_date  = .;
        first1_date  = .;
        gap          = 0;
        first_approved   = approved;   /* record the very first fill value */
    end;

    /* Only process patients whose first fill=0 */
    if first_approved = 0 then do;
        if approved=0 and missing(first0_date) then first0_date = svc_dt;  /* capture first date with approved=0 */        
        if approved=1 and missing(first1_date) then first1_date = svc_dt;  /* capture first date with approved=1 */
        if last.patient_id then do;
            if not missing(first0_date) and not missing(first1_date) then
                gap = first1_date - first0_date;
            else gap = .;
            output;
        end;

    end;
run; /* 225003 obs */

proc print data=rx18_24_glp1_long_v02 (obs=20); var patient_id svc_dt first0_date first1_date first_approved gap; run;
proc print data=rx18_24_glp1_long_v00; where patient_id = 5014876	; run;


*test;
proc means data=rx18_24_glp1_long_v02 n nmiss median q1 q3 min max; var gap; run; /* 112592 missing -> # of individuals who never paid claim after their first rejection */
proc means data=rx18_24_glp1_long_v02 n nmiss median q1 q3 min max; class dominant_payer; var gap; run;

* how many people fill at the date of first rejection? (N = 9196);
proc sql;
  select count(distinct patient_id) as count_pt
  from rx18_24_glp1_long_v02
  where gap = 0;
quit;


/*============================================================*
 |     Figure 2(1) - rejection % & rejection reason by donimant payer type
 *============================================================*/
proc freq data=input.rx18_24_glp1_long_v00; table encnt_outcm_cd; run;
proc freq data=input.rx18_24_glp1_long_v00; table encnt_outcm_cd*dominant_payer /norow nopercent; run;

proc freq data=input.rx18_24_glp1_long_v00; table RJ_reason; run;

data rejection; set input.rx18_24_glp1_long_v00; if rjct_grp ne 0; run;
proc freq data=rejection; table RJ_reason; run;
proc freq data=rejection; table RJ_reason*dominant_payer  /norow nopercent; run;

/*============================================================*
 |     Figure 2(2) - rejection % & rejection reason by diabetes_history
 *============================================================*/

proc freq data=input.rx18_24_glp1_long_v00; table encnt_outcm_cd*diabetes_history /norow nopercent; run;

data rejection; set input.rx18_24_glp1_long_v00; if rjct_grp ne 0; run;
proc freq data=rejection; table RJ_reason; run;
proc freq data=rejection; table RJ_reason*diabetes_history  /norow nopercent; run;




 
/*============================================================*
 | the amount of overall rejection & reasons by plan type
 *============================================================*/
* overall:
proc sql; 
  create table overall as
  select distinct
         count(*) as all,
         sum(case when encnt_outcm_cd = "PD" then 1 else 0 end) as count_PD, 
         sum(case when encnt_outcm_cd = "RV" then 1 else 0 end) as count_RV, 
         sum(case when encnt_outcm_cd = "RJ" then 1 else 0 end) as count_RJ_all, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 2 then 1 else 0 end) as count_RJ_PA, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 1 then 1 else 0 end) as count_RJ_step, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 4 then 1 else 0 end) as count_RJ_QLim,
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 3 then 1 else 0 end) as count_RJ_NtCv, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 5 then 1 else 0 end) as count_RJ_other
    
  from input.rx18_24_glp1_long_v00;
quit;
data overall; set overall; 
      pct_count_PD = count_PD / all;
      pct_count_RV = count_RV / all;
      pct_count_RJ = count_RJ_all / all;
      pct_count_RJ_PA = count_RJ_PA / all;
      pct_count_RJ_step = count_RJ_step / all;
      pct_count_RJ_QLim = count_RJ_QLim / all;
      pct_count_RJ_NtCv = count_RJ_NtCv / all;
      pct_count_RJ_other = count_RJ_other / all;
run;
proc print data=overall (obs=50); run;

* by plan_type;
proc sort data=rx18_24_glp1_long_v00 out=input.rx18_24_glp1_long_v00; by plan_type encnt_outcm_cd; run;
proc sql; 
  create table overall_plan_type as
  select distinct
         plan_type,
         count(*) as all,
         sum(case when encnt_outcm_cd = "PD" then 1 else 0 end) as count_PD, 
         sum(case when encnt_outcm_cd = "RV" then 1 else 0 end) as count_RV, 
         sum(case when encnt_outcm_cd = "RJ" then 1 else 0 end) as count_RJ_all, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 2 then 1 else 0 end) as count_RJ_PA, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 1 then 1 else 0 end) as count_RJ_step, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 4 then 1 else 0 end) as count_RJ_QLim,
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 3 then 1 else 0 end) as count_RJ_NtCv, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 5 then 1 else 0 end) as count_RJ_other
    
  from rx18_24_glp1_long_v00
  group by plan_type;
quit;

data overall_plan_type; set overall_plan_type; 
      pct_count_PD = count_PD / all;
      pct_count_RV = count_RV / all;
      pct_count_RJ = count_RJ_all / all;
      pct_count_RJ_PA = count_RJ_PA / all;
      pct_count_RJ_step = count_RJ_step / all;
      pct_count_RJ_QLim = count_RJ_QLim / all;
      pct_count_RJ_NtCv = count_RJ_NtCv / all;
      pct_count_RJ_other = count_RJ_other / all;
run;
proc print data=overall_plan_type (obs=50); run;


* by indication;
proc sort data=rx18_24_glp1_long_v00 out=input.rx18_24_glp1_long_v00; by indication encnt_outcm_cd; run;
proc sql; 
  create table overall_indication as
  select distinct
         indication,
         count(*) as all,
         sum(case when encnt_outcm_cd = "PD" then 1 else 0 end) as count_PD, 
         sum(case when encnt_outcm_cd = "RV" then 1 else 0 end) as count_RV, 
         sum(case when encnt_outcm_cd = "RJ" then 1 else 0 end) as count_RJ_all, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 2 then 1 else 0 end) as count_RJ_PA, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 1 then 1 else 0 end) as count_RJ_step, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 4 then 1 else 0 end) as count_RJ_QLim,
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 3 then 1 else 0 end) as count_RJ_NtCv, 
         sum(case when encnt_outcm_cd = "RJ" and rjct_grp = 5 then 1 else 0 end) as count_RJ_other
    
  from rx18_24_glp1_long_v00
  group by indication;
quit;

data overall_indication; set overall_indication; 
      pct_count_PD = count_PD / all;
      pct_count_RV = count_RV / all;
      pct_count_RJ = count_RJ_all / all;
      pct_count_RJ_PA = count_RJ_PA / all;
      pct_count_RJ_step = count_RJ_step / all;
      pct_count_RJ_QLim = count_RJ_QLim / all;
      pct_count_RJ_NtCv = count_RJ_NtCv / all;
      pct_count_RJ_other = count_RJ_other / all;
run;
proc print data=overall_indication (obs=50); run;


 
