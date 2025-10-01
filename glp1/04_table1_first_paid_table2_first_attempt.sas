/*============================================================*
 |      TABLE 1 - first paid claim characteristics
 *============================================================*/

fiy
/*============================================================*
 | 1) form first_claim (N= 832,454)
 *============================================================*/
data first_paid_claim; set input.rx18_24_glp1_long_v01; if encnt_outcm_cd = "PD"; run;
proc sort data=first_paid_claim; by patient_id svc_dt; run;
data first_paid_claim; set first_paid_claim; by patient_id svc_dt; if first.patient_id; run;

proc freq data=first_paid_claim; table plan_type; run;

proc freq data=first_paid_claim; table indication; run;
proc freq data=first_paid_claim; table indication*plan_type /norow nopercent; run;

/*****************************
*  retail channel
*****************************/
proc freq data=first_paid_claim; table chnl_cd; run;
proc freq data=first_paid_claim; table chnl_cd*plan_type /norow nopercent; run;

/*****************************
*  gender
*****************************/
proc freq data=first_paid_claim; table patient_gender; run;
proc freq data=first_paid_claim; table patient_gender*plan_type /norow nopercent; run;


/*****************************
*  age at claim
*****************************/
proc means data=first_paid_claim n nmiss median q1 q3 min max; var age_at_claim; run;
proc means data=first_paid_claim n nmiss median q1 q3 min max;
    class plan_type;
    var age_at_claim;
run;

/*****************************
*  GLP1 types, indication
*****************************/
proc freq data=first_paid_claim; table molecule; run;
proc freq data=first_paid_claim; table molecule*plan_type /norow nopercent; run;

proc freq data=first_paid_claim; table region; run;
proc freq data=first_paid_claim; table region*plan_type /norow nopercent; run;

/*****************************
*  OOP at index
*****************************/
proc means data=first_paid_claim n nmiss median q1 q3 min max; var final_opc_amt; run;
proc means data=first_paid_claim n nmiss median q1 q3 min max;
    class plan_type;
    var final_opc_amt;
run;

*only remain valid rows for calculating OOP;
data oop;
    set first_paid_claim;
    if indication = "obesity" and not missing(final_opc_amt);
run;

proc means data=oop n nmiss median q1 q3 min max; var final_opc_amt; run;
proc means data=oop n nmiss median q1 q3 min max;
    class plan_type;
    var final_opc_amt;
run;




/*============================================================*
 |      TABLE 2 - first attempt (their first try to fill) 
 *============================================================*/

data first_attempt;
    set input.rx18_24_glp1_long_v01;        
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
run; /* 768630 obs */


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
run;


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
quit;

proc print data=first_attempt_firstdate_v1 (obs=10); run;
data first_attempt_firstdate_v2; set first_attempt_firstdate_v1; if count_claims > 1; run; /* 86246 among 174523 */


/*****************************
*  distribution by plan_type
*****************************/
proc freq data=input.first_attempt; table first_plan_type; run;

proc freq data=input.first_attempt; table encnt_outcm_cd; run;
proc freq data=input.first_attempt; table encnt_outcm_cd*plan_type /norow nopercent; run;


/*****************************
*  OOP at index
*****************************/
*only remain valid rows for calculating OOP;
data oop;
    set input.first_attempt;
    if not missing(final_opc_amt) and encnt_outcm_cd = "RV" ;
run;
proc means data=oop n nmiss median q1 q3 min max; var final_opc_amt; run;
proc means data=oop n nmiss median q1 q3 min max;
    class plan_type;
    var final_opc_amt;
run;

/*****************************
*  reason of rejections among rejection
*****************************/
data rejection; set input.first_attempt; if rjct_grp ne 0; run;
proc freq data=rejection; table rjct_grp; run;
proc freq data=rejection; table rjct_grp*plan_type  /norow nopercent; run;




/*============================================================*
 | Median days from first rejection to first approved fill (IQR)
 *============================================================*/
data rx18_24_glp1_long_v01;
    set input.rx18_24_glp1_long_v01;
    if encnt_outcm_cd = "PD" then fill = 1;
    else fill = 0;
run;

proc sort data=rx18_24_glp1_long_v01; by patient_id svc_dt; run;
data rx18_24_glp1_long_v02;
    set rx18_24_glp1_long_v01;
    by patient_id svc_dt;

    retain first0_date first1_date gap first_fill;
    format first0_date first1_date yymmdd10.;

    if first.patient_id then do;
        first0_date  = .;
        first1_date  = .;
        gap          = .;
        first_fill   = fill;   /* record the very first fill value */
    end;

    /* Only process patients whose first fill=0 */
    if first_fill = 0 then do;
        if fill=0 and missing(first0_date) then first0_date = svc_dt;  /* capture first date with fill=0 */        
        if fill=1 and missing(first1_date) then first1_date = svc_dt;  /* capture first date with fill=1 */
        if last.patient_id then do;
            if not missing(first0_date) and not missing(first1_date) then
                gap = first1_date - first0_date;
            else gap = .;
            output;
        end;

    end;
run; /* 331129 obs */

proc print data=rx18_24_glp1_long_v02 (obs=20); var patient_id svc_dt first0_date first1_date first_fill gap; run;

*test;
proc means data=rx18_24_glp1_long_v02 n nmiss median q1 q3 min max; var gap; run;
proc means data=rx18_24_glp1_long_v02 n nmiss median q1 q3 min max; class plan_type; var gap; run;

* if gap > 30, we con; 







/*============================================================*
 | 7) long data clean - one svc_dt can have only one row - paid priority
 *============================================================*/
 
data first_claim;
    set input.rx18_24_glp1_long_v01;        
    if rjct_grp = 0 then paid_priority = 1;   /* 1 if rjct_grp=0, else 0 */
    else paid_priority = 0;
run;

/* 2) Sort by patient → earliest svc_dt → prefer paid on that date */
proc sort data=first_claim; by patient_id svc_dt descending paid_priority; run;

/* 3) Keep the first record per patient (earliest date; paid preferred if tie) */
data first_claim;
    set first_claim;
    by patient_id svc_dt;
    if first.svc_dt then output;
    drop paid_priority;
run; /* 1,061,808 obs */

 
