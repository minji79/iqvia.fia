
/*============================================================*
 | 1. remove individuals who only had RJ/RV coupon/cash/discount card claims without any insurance-related claims (N=926,970)
 *============================================================*/

/* index_rx_dt (index_svc_dt) : claim for index date (the first attempt to get drugs) */
/* include only PAID coupon/cash/discount card claims */
data rx17_25_glp1_long; set input.rx17_25_glp1_long; if coupon =0 and cash =0 and discount_card =0; run;
data coupon_paid; set input.rx17_25_glp1_long; if coupon=1 and encnt_outcm_cd = "PD"; run;
data cash_paid; set input.rx17_25_glp1_long; if cash=1 and encnt_outcm_cd = "PD"; run;
data discount_card_paid; set input.rx17_25_glp1_long; if discount_card=1 and encnt_outcm_cd = "PD"; run;

data input.id_index; set rx17_25_glp1_long coupon_paid cash_paid discount_card_paid; run; /* 19476378 obs */

data input.id_index;
    set input.id_index;     
    if encnt_outcm_cd = "PD" then paid_priority = 0;  
    else if encnt_outcm_cd = "RV" then paid_priority = 1;  
    else paid_priority = 2;
run;
proc sort data=input.id_index; by patient_id rx_written_dt svc_dt final_claim_ind descending paid_priority; run;
proc print data=input.id_index (obs=20); var patient_id rx_written_dt svc_dt fill_nbr encnt_outcm_cd final_claim_ind coupon cash discount_card; run;

data id_index;
    set input.id_index;
    by patient_id rx_written_dt svc_dt;
    if first.patient_id then output;
    drop paid_priority;
run;  /* 938371 -> 926,970 individuals */

/* who is those 11401 individuals? */
proc sql;
    create table sample as
    select a.*
    from input.rx17_25_glp1_long as a
    left join id_index as b
    on a.patient_id = b.patient_id
    where b.patient_id is missing; /* Keeps only those NOT found in id_index coupon/cash/discount card claims */
quit;

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from sample;
quit; /* should be 11401 individuals with 18350 claims -> okay */

proc freq data=sample; table encnt_outcm_cd; run; /* they only have RJ/RV */
proc print data=sample (obs=20); where cash=0 and coupon=0 and discount_card=0; run; /* none */
proc print data=sample (obs=20); var patient_id rx_written_dt svc_dt fill_nbr encnt_outcm_cd final_claim_ind coupon cash discount_card; run;

/* set 926,970 individuals */
data input.id_index; set id_index; run;
proc print data=input.id_index (obs=20); var patient_id rx_written_dt svc_dt dominant_payer plan_name fill_nbr encnt_outcm_cd final_claim_ind; run;


/*============================================================*
 | 2. indicator for "index_decision" & remain longdata for those study population
 *============================================================*/

data input.id_index; set input.id_index; drop index_svc_dt index_rx_dt index_decision; run;

* indicator for "index_decision" ; 
data input.id_index; set input.id_index (rename=(svc_dt=index_svc_dt)); run;
data input.id_index; set input.id_index (rename=(rx_written_dt=index_rx_dt)); run;
data input.id_index; set input.id_index (rename=(encnt_outcm_cd=index_decision)); run;

proc freq data=input.id_index; table index_decision; run;
proc freq data=input.id_index; table cash*index_decision /nocol nopercent; run;
proc freq data=input.id_index; table coupon*index_decision /nocol nopercent; run;
proc freq data=input.id_index; table discount_card*index_decision /nocol nopercent; run;


/* set long data */
proc sql;
    create table input.rx17_25_glp1_long as
    select a.*
    from input.rx17_25_glp1_long as a
    inner join input.id_index as b
    on a.patient_id = b.patient_id;
quit; /* 19830335 obs */

* distinct number of patients (N=926,970);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx17_25_glp1_long;
quit;


/*============================================================*
 | 3. identify the first paid claim | grouping based on the filled claim after initial rejection/ reverse
 *============================================================*/
 
* merge with the entire cohort data; 
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long; drop index_svc_dt index_rx_dt index_decision; run;

proc sql;
    create table input.rx17_25_glp1_long as
    select a.*, b.index_rx_dt, b.index_svc_dt, b.index_decision
    from input.rx17_25_glp1_long as a
    left join input.id_index as b
    on a.patient_id = b.patient_id;
quit;

* remain cohort who failed to fill at the index date; 
data input.first_filled_after_RJRV; set input.rx17_25_glp1_long; if index_decision in ("RJ","RV"); run;   
data input.first_filled_after_RJRV; set input.first_filled_after_RJRV; if encnt_outcm_cd = "PD"; run;
data input.first_filled_after_RJRV; set input.first_filled_after_RJRV; oop_30days = final_opc_amt / days_supply_cnt *30; run;
proc sort data=input.first_filled_after_RJRV; by patient_id svc_dt; run;
proc print data= input.first_filled_after_RJRV (obs=20); var patient_id index_rx_dt index_svc_dt index_decision svc_dt encnt_outcm_cd dominant_payer plan_name molecule_name; run;

data input.first_filled_after_RJRV; set input.first_filled_after_RJRV; by patient_id; if first.patient_id; run;
proc print data= input.first_filled_after_RJRV (obs=10); var patient_id plan_id plan_name plan_type payer_id payer_name; run;

proc sql;
    create table input.id_index as
    select a.*, b.svc_dt as first_filled_date, b.molecule_name as first_filled_molecule, b.dominant_payer as first_filled_dominant_payer, 
           b.plan_type as first_filled_plan_type, b.plan_name as first_filled_plan_name, b.plan_id as first_filled_plan_id, 
           b.cash as first_filled_cash, b.coupon as first_filled_coupon, b.discount_card as first_filled_discount_card, b.oop_30days as first_filled_oop_30days
    from input.id_index as a
    left join input.first_filled_after_RJRV as b
    on a.patient_id = b.patient_id;
quit;

data input.id_index; set input.id_index;
 if index_decision = "PD" then first_filled_date = index_svc_dt; 
 else first_filled_date=first_filled_date; 
run;
proc means data=input.id_index n nmiss; var first_filled_date; run;


/* cohort definition */
data input.id_index; set input.id_index; length cohort $100.; 
  
  if not missing(first_filled_date) then time_to_fill = first_filled_date - index_rx_dt; 
    else time_to_fill = .;
    
  if index_decision = "PD" then cohort = "filled at the index attempt"; 
  else if index_decision in ("RJ", "RV") and not missing(first_filled_date) and gap < 90 then cohort = "filled after RJ/RV in 90days";
  
  else if index_decision in ("RJ", "RV") and missing(first_filled_date) then cohort = "never filled";
  else if not missing(gap) and gap >= 90 then cohort = "filled after 90 days"; 
  else cohort = "other/unclassified";
run;

data input.id_index; set input.id_index; length cohort2 $100.; 
  if cohort in ("filled after 90 days","never filled") then cohort2 = "never filled or filled after 90 days";
  else cohort2 = cohort; 
run;

proc freq data=input.id_index; table cohort; run;
proc freq data=input.id_index; table cohort2; run;


* Among those paid at the first attempt, calculate the lag between index_rx_dt ~ index_svc_dt; 
data sample; set input.id_index; if index_decision ="PD"; run;   
data sample; set sample; day_lag = first_filled_date - index_rx_dt; run;
proc means data=sample n nmiss mean std median q1 q3 min max; var day_lag; run;



