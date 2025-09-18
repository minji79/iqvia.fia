
days_supply_cnt
dspnsd_qty

/*============================================================*
 | 1) Identify discontinuation
 |   - remain only paid claims
 |   - count 
 |   - take "days_supply_cnt" variable from the original dataset
 |   - take "days_supply_cnt" variable from the original dataset
 
 *============================================================*/

data rx18_24_glp1_long_paid; set input.rx18_24_glp1_long_v01; if rjct_grp =0; run; /* 15792746 obs */
proc sort data=rx18_24_glp1_long_paid; by patient_id svc_dt; run;

/*==========================*
 |  Definition 1;
 *==========================*/

* definition 1;
data rx18_24_glp1_long_paid_v1;
    set rx18_24_glp1_long_paid;
    by patient_id;

    retain first_date last_date claim_count;
    format first_date last_date study_end_date mmddyy10.;

    study_end_date = '31DEC2024'd;

    if first.patient_id then do;
        first_date   = svc_dt;
        claim_count  = 0;
    end;

    claim_count + 1;
    last_date = svc_dt;

    if last.patient_id then output;
run;

data rx18_24_glp1_long_paid_v1;
    set rx18_24_glp1_long_paid_v1;
    format disc1_date mmddyy10.;
    discontinuation1 = ((study_end_date - last_date) > 90);
    if discontinuation1 =1 then disc1_date = last_date; else disc1_date =.;
run;
proc print data=rx18_24_glp1_long_paid_v1 (obs=10); run;

/* patient level clean dataset */
data disc_patient_v1; set rx18_24_glp1_long_paid_v1; keep patient_id discontinuation1 disc1_date; run;
proc sort data=disc_patient_v1 nodupkey; by patient_id; run;
/* data disc_patient_v1; set disc_patient_v1; if missing(disc1_date) then disc1_date = '31DEC9999'd; format disc1_date mmddyy10.; run; */
proc print data=disc_patient_v1 (obs=10); run;

proc freq data=disc_patient_v1; table discontinuation1; run;


* definition 2 - gap;
data rx18_24_glp1_long_paid_v2;
    set rx18_24_glp1_long_paid;
    format prev_svc_dt disc2_date mmddyy10.;
    by patient_id;

    prev_svc_dt = lag(svc_dt);
    if first.patient_id then do;
        prev_svc_dt =.;
    end;
    gap = svc_dt - prev_svc_dt;
    
    if gap > 90 then discontinuation2 =1; else discontinuation2 =0;
    if discontinuation2 =1 then disc2_date = svc_dt; else disc2_date =.;

run;

proc means data=rx18_24_glp1_long_paid_v2 n nmiss min max mean std median q1 q3; var gap; run;

/* patient level clean dataset */
data disc_patient_v2; set rx18_24_glp1_long_paid_v2; keep patient_id discontinuation2 disc2_date; run;
proc sql;
    create table disc_patient_v2 as
    select patient_id,
           max(discontinuation2) as discontinuation2,
           min(disc2_date) as disc2_date   /* earliest discontinuation date, if any */
    from disc_patient_v2
    group by patient_id;
quit;
proc sort data=disc_patient_v2 nodupkey; by patient_id; run;
data disc_patient_v2; set disc_patient_v2; if missing(disc2_date) then disc2_date = '31DEC9999'd; format disc2_date mmddyy10.; run;


proc freq data=disc_patient_v2; table discontinuation2; run;
proc print data=disc_patient_v2 (obs=10); run;



* merge with patient files;
proc sql; 
  create table patients_v1 as
  select a.*, b1.discontinuation1, b1.disc1_date, b2.discontinuation2, b2.disc2_date
  from input.patients_v0 as a
  left join disc_patient_v1 as b1 on a.patient_id = b1.patient_id
  left join disc_patient_v2 as b2 on a.patient_id = b2.patient_id;  
quit;

data patients_v1; set patients_v1; if discontinuation1 = 0 and discontinuation2 =0 then discontinuation =0; else discontinuation =1; run;
data patients_v1; set patients_v1; if discontinuation =1 then disc_date = min(disc1_date, disc2_date); else disc_date =.; format disc_date mmddyy10.; run;

proc freq data=patients_v1; table discontinuation; run;
proc freq data=patients_v1; table discontinuation1*discontinuation2; run;

data patients_v1; set patients_v1; format first_date last_date glp1_switch_date plan_switch_date mmddyy10.; run;
data patients_v1; set patients_v1; if discontinuation = 1 then time_to_disc_in_month = (disc_date - first_date)/31; else time_to_disc_in_month =.;run;
proc means data=patients_v1 n nmiss min max mean std median q1 q3; var time_to_disc_in_month; run;

proc print data=patients_v1 (obs=10); run;



