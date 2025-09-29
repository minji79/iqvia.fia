/*============================================================*
 |      TABLE 1 - first paid claim characteristics
 *============================================================*/


/*============================================================*
 | 1) form first_claim (N= 832,454)
 *============================================================*/
data first_paid_claim; set input.rx18_24_glp1_long_v01; if encnt_outcm_cd = "PD"; run;
proc sort data=first_paid_claim; by patient_id svc_dt; run;
data first_paid_claim; set first_paid_claim; by patient_id svc_dt; if first.patient_id; run;

proc freq data=first_paid_claim; table plan_type; run;
proc freq data=first_paid_claim; table indication*plan_type /norow nopercent; run;


/*****************************
*  retail channel
*****************************/
proc freq data=first_paid_claim; table chnl_cd; run;
proc freq data=first_paid_claim; table chnl_cd*plan_type /norow nopercent; run;

/*****************************
*  GLP1 types, indication
*****************************/
proc freq data=first_paid_claim; table molecule; run;
proc freq data=first_paid_claim; table molecule*plan_type /norow nopercent; run;

proc freq data=input.patients_v0; table region; run;
proc freq data=input.patients_v0; table region*first_plan_type /norow nopercent; run;

/*****************************
*  OOP at index
*****************************/
proc means data=oop n nmiss median q1 q3 min max; var final_opc_amt; run;
proc means data=oop n nmiss median q1 q3 min max;
    class plan_type;
    var final_opc_amt;
run;

*only remain valid rows for calculating OOP;
data oop;
    set first_paid_claim;
    if indication = "diabetes" and not missing(final_opc_amt);
run;

proc means data=oop n nmiss median q1 q3 min max; var final_opc_amt; run;
proc means data=oop n nmiss median q1 q3 min max;
    class plan_type;
    var final_opc_amt;
run;







/*============================================================*
 | 1) first attempt (their first try to fill) -> claim characteristics | first_claim (N= 817,897)
 *============================================================*/
* trial 1 | first_claim - remain only one of the first claim. if patients have multiple claims, only included paid one;
data first_claim;
    set input.rx18_24_glp1_long_v01;        
    if encnt_outcm_cd = "PD" then paid_priority = 1;  
    else paid_priority = 0;
run;

/* 2) Sort by patient → earliest svc_dt → prefer paid on that date */
proc sort data=first_claim; by patient_id svc_dt descending paid_priority; run;

/* 3) Keep the first record per patient (earliest date; paid preferred if tie) */
data input.first_claim;
    set first_claim;
    by patient_id svc_dt;
    if first.patient_id then output;
    drop paid_priority;
run; /* 817,897 obs */



/*****************************
*  retail channel
*****************************/
proc freq data=input.first_claim; table chnl_cd; run;
proc freq data=input.first_claim; table chnl_cd*plan_type /norow nopercent; run;

/*****************************
*  GLP1 types, indication
*****************************/
proc freq data=first_claim; table molecule; run;
proc freq data=first_claim; table molecule*plan_type /norow nopercent; run;

/*****************************
*  OOP at index
*****************************/
*only remain valid rows for calculating OOP;
data oop;
    set input.first_claim;
    if final_opc_amt ne 0 and not missing(final_opc_amt) and encnt_outcm_cd = "RV" ;
run;
proc means data=oop n nmiss median q1 q3 min max; var final_opc_amt; run;
proc means data=oop n nmiss median q1 q3 min max;
    class plan_type;
    var final_opc_amt;
run;

/*****************************
*  reason of rejections
*****************************/
proc freq data=input.rx18_24_glp1_long_v01; table encnt_outcm_cd; run; /* all claim number */
proc freq data=input.rx18_24_glp1_long_v01; table encnt_outcm_cd*plan_type  /norow nopercent; run;

proc freq data=input.first_claim; table rjct_grp; run;
proc freq data=input.first_claim; table rjct_grp*plan_type  /norow nopercent; run;

proc freq data=input.first_claim; table encnt_outcm_cd; run;
proc freq data=input.first_claim; table encnt_outcm_cd*plan_type  /norow nopercent; run;



* among rejection;
data rejection; set input.first_claim; if rjct_grp ne 0; run;
proc freq data=rejection; table rjct_grp; run;
proc freq data=rejection; table rjct_grp*group  /norow nopercent;; run;

proc freq data=input.first_claim; table plan_type; run;
proc freq data=input.first_claim; table molecule_name; run;
proc freq data=input.first_claim; table molecule_name*plan_type; run;




/*============================================================*
 | 6) What happen on the first date of initiation? | first_claim_all
 *============================================================*/
data first_claim_all; set input.rx18_24_glp1_long_v00; if first.patient_id and first.svc_dt; run; 

* how many claims people have at the first date of dispense?;



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

proc print data=rx18_24_glp1_long_v02 (obs=20); run;

*test;
proc means data=rx18_24_glp1_long_v02 n nmiss median q1 q3 min max; class group; var gap; run;

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

 
