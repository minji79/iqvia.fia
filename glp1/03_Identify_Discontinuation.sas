
days_supply_cnt
dspnsd_qty

/*============================================================*
 | 1) Identify discontinuation
 |   - remain only paid claims (N=827,108)
 *============================================================*/

data rx18_24_glp1_long_paid; set input.rx18_24_glp1_long_v01; if encnt_outcm_cd ="PD"; run; /* 8760132 obs */
proc sort data=rx18_24_glp1_long_paid; by patient_id svc_dt; run;

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

    if stockpiling > 30 then stockpiling_adj = 30; else if stockpiling < 0 then stockpiling_adj = 0; else stockpiling_adj = stockpiling;
    if gap >= (60 + stockpiling_adj) then discontinuation1 = 1; else discontinuation1 = 0;
    if discontinuation1 = 1 then disc1_date = svc_dt + stockpiling_adj; else disc1_date = .;

run;

proc print data=rx18_24_glp1_long_paid_v1 (obs=10); var patient_id svc_dt gap days_supply_cnt stockpiling stockpiling_adj discontinuation1 disc1_date; run;
proc print data=rx18_24_glp1_long_paid_v1 (obs=10); var patient_id svc_dt gap days_supply_cnt stockpiling stockpiling_adj discontinuation1 disc1_date; where discontinuation1=1 and "01JUL2024"d < disc1_date; run;



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

proc freq data=disc_patient_v1; table discontinuation1; run; /* 52% */


/*==========================*
 |  Definition 2; Right censored
 *==========================*/

data disc_patient_v1; set disc_patient_v1; 
  if disc1_date < "01OCT2024"d and discontinuation1 =1 then do;
   disc1_date = disc1_date; 
   discontinuation1 = discontinuation1;
  end;
  else do;
   disc_date = .;
   discontinuation1 = 0;
  end;
 run;
 
proc freq data=disc_patient_v1; table discontinuation1; run; /* 49% */


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
   
    if (study_end_date - last_date) > 90 then discontinuation2 = 1; else discontinuation2 = 0;
    if discontinuation2 = 1 then disc2_date = svc_dt; else disc2_date = .;
    
run;
proc print data=rx18_24_glp1_long_paid_v2 (obs=10); var patient_id svc_dt days_supply_cnt discontinuation2 disc2_date; run;
proc print data=rx18_24_glp1_long_paid_v2 (obs=10); var patient_id svc_dt days_supply_cnt discontinuation2 disc2_date; where discontinuation2=1; run;


/* patient level clean dataset */
data disc_patient_v2; set rx18_24_glp1_long_paid_v2; keep patient_id discontinuation2 disc2_date; run;
proc sort data=disc_patient_v2 nodupkey; by patient_id; run;
data disc_patient_v2; set disc_patient_v2; if missing(disc2_date) then disc2_date = '31DEC9999'd; format disc2_date mmddyy10.; run;

proc freq data=disc_patient_v2; table discontinuation2; run;



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

data patients_v1; set patients_v1; if discontinuation =1 and disc_date <= (first_date + 365) then disc_at_1y =1; else disc_at_1y =0; run; 
data patients_v1; set patients_v1; if discontinuation =1 and disc_date <= (first_date + 730) then disc_at_2y =1; else disc_at_2y =0; run; 
data patients_v1; set patients_v1; if discontinuation =1 and disc_date <= (first_date  + 180) then disc_at_6m =1; else disc_at_6m =0; run; 

proc print data=input.patients_v0 (obs=10); var first_indication first_glp1; run;

proc freq data=patients_v1; table disc_at_1y; run;
proc freq data=patients_v1; table disc_at_1y*first_indication /norow nopercent; run;

proc freq data=patients_v1; table first_indication; run;
data input.patients_v1; set patients_v1; run;

/*==========================*
 |  discontinuation at 1 yr
 *==========================*/
proc freq data=input.patients_v1; table disc_at_1y; run;

* by first_payer;
proc freq data=input.patients_v1; table disc_at_1y*first_plan_type /norow nopercent; run;

* by first_indication;
proc freq data=input.patients_v1; table disc_at_1y*first_indication /norow nopercent; run;

data subgroup; set input.patients_v1; if first_indication ="diabetes"; run;
proc freq data=subgroup; table disc_at_1y*first_plan_type /norow nopercent; run;


/*==========================*
 |  discontinuation at 6 months
 *==========================*/
proc freq data=input.patients_v1; table disc_at_6m; run;
* by first_payer;
proc freq data=input.patients_v1; table disc_at_6m*first_plan_type /norow nopercent; run;


 /*==========================*
 |  discontinuation at 2 yr
 *==========================*/
 proc freq data=input.patients_v1; table disc_at_2y; run;
* by first_payer;
proc freq data=input.patients_v1; table disc_at_2y*first_plan_type /norow nopercent; run;



data patients_v1; set input.patients_v1; format first_date last_date glp1_switch_date plan_switch_date mmddyy10.; run;
data patients_v1; set patients_v1; if discontinuation = 1 then time_to_disc_in_month = (disc_date - first_date)/31; else time_to_disc_in_month =.;run;
proc means data=patients_v1 n nmiss min max mean std median q1 q3; var time_to_disc_in_month; run;

proc print data=patients_v1 (obs=10); run;

proc freq data=input.patients_v1; table discontinuation*first_plan_type /norow nopercent; run;

