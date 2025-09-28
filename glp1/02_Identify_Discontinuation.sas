
days_supply_cnt
dspnsd_qty

/*============================================================*
 | 1) Identify discontinuation
 |   - remain only paid claims (N=827,108)
 *============================================================*/

data rx18_24_glp1_long_paid; set input.rx18_24_glp1_long_v01; if encnt_outcm_cd ="PD"; run; /* 15792746 -> 10219243 obs */
proc sort data=rx18_24_glp1_long_paid; by patient_id svc_dt; run;

proc print data=rx18_24_glp1_long_paid (obs=10); var days_supply_cnt dspnsd_qty; run;

/*==========================*
 |  Definition 1; GAP >=60 (with consideration of 30-days stockpiling)
 *==========================*/
data rx18_24_glp1_long_paid_v1;
    set rx18_24_glp1_long_paid;
    format prev_svc_dt disc1_date mmddyy10.;
    by patient_id;

    prev_svc_dt = lag(svc_dt);
    if first.patient_id then do;
        prev_svc_dt = .;
        stockpiling = days_supply_cnt;
    end;
    else do;
        gap = svc_dt - prev_svc_dt;
        stockpiling = days_supply_cnt - gap;
    end;

    if stockpiling > 30 then stockpiling_adj = 30; else stockpiling_adj = stockpiling;
    if gap >= (60 + stockpiling_adj) then discontinuation1 = 1; else discontinuation1 = 0;
    if discontinuation1 = 1 then disc1_date = svc_dt; else disc1_date = .;

run;

proc print data=rx18_24_glp1_long_paid_v1 (obs=10); var patient_id svc_dt gap days_supply_cnt stockpiling stockpiling_adj discontinuation1 disc1_date; run;
proc print data=rx18_24_glp1_long_paid_v1 (obs=10); var patient_id svc_dt gap days_supply_cnt stockpiling stockpiling_adj discontinuation1 disc1_date; where discontinuation1=1; run;


/* patient level clean dataset */
data disc_patient_v1; set rx18_24_glp1_long_paid_v1; keep patient_id discontinuation1 disc1_date; run;

proc sql;
    create table disc_patient_v1 as
    select patient_id,
           max(discontinuation1) as discontinuation1,
           min(disc1_date) as disc1_date   /* earliest discontinuation date, if any */
    from disc_patient_v1
    group by patient_id;
quit;
proc sort data=disc_patient_v1 nodupkey; by patient_id; run;
data disc_patient_v1; set disc_patient_v1; if missing(disc1_date) then disc1_date = '31DEC9999'd; format disc1_date mmddyy10.; run;

proc freq data=disc_patient_v1; table discontinuation1; run;
proc freq data=disc_patient_v2; table discontinuation2; run;
proc print data=disc_patient_v1(obs=10); run;



/*==========================*
 |  Definition 2; Right censored
 *==========================*/
* definition 2;
data rx18_24_glp1_long_paid_v2;
    set rx18_24_glp1_long_paid;
    by patient_id;

    retain first_date last_date claim_count ;
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

data rx18_24_glp1_long_paid_v2;
    set rx18_24_glp1_long_paid_v2;
    format disc2_date mmddyy10.;
   
    if discontinuation2 = ((study_end_date - last_date) > 88) then discontinuation2 = 1; else discontinuation2 = 0;
    if discontinuation2 = 1 then disc2_date = svc_dt; else disc2_date = .;
    
run;

proc print data=rx18_24_glp1_long_paid_v2 (obs=10); var patient_id svc_dt days_supply_cnt discontinuation2 disc2_date; where discontinuation2=1; run;


/* patient level clean dataset */
data disc_patient_v2; set rx18_24_glp1_long_paid_v2; keep patient_id discontinuation2 disc2_date; run;
proc sort data=disc_patient_v2 nodupkey; by patient_id; run;
data disc_patient_v2; set disc_patient_v2; if missing(disc2_date) then disc2_date = '31DEC9999'd; format disc2_date mmddyy10.; run;
proc print data=disc_patient_v2 (obs=10); run;

proc freq data=disc_patient_v2; table discontinuation2; run;


/*
data rx18_24_glp1_long_paid_v2;
    set rx18_24_glp1_long_paid;
    format prev_svc_dt disc2_date mmddyy10.;
    by patient_id;

    prev_svc_dt = lag(svc_dt);
    if first.patient_id then do;
        prev_svc_dt = .;
        stockpiling = days_supply_cnt;
    end;
    else do;
        gap = svc_dt - prev_svc_dt;
        stockpiling = days_supply_cnt - gap;
    end;

    if stockpiling > 30 then stockpiling_adj = 30; else stockpiling_adj = stockpiling;
    if gap >= (60 + stockpiling_adj) then discontinuation2 = 1; else discontinuation2 = 0;
    if discontinuation2 = 1 then disc2_date = svc_dt; else disc2_date = .;

run;

proc print data=rx18_24_glp1_long_paid_v2 (obs=10); var patient_id svc_dt gap days_supply_cnt stockpiling stockpiling_adj discontinuation2 disc2_date; run;
proc print data=rx18_24_glp1_long_paid_v2 (obs=10); var patient_id svc_dt gap days_supply_cnt stockpiling stockpiling_adj discontinuation2 disc2_date; where discontinuation2=1; run;

*/


/*==========================*
 |  merge with patient files
 *==========================*/

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



