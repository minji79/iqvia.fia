
/*
pri_pat_pay_amt
pri_payer_pay_amt

sec_plan_id
sec_payer_pay_amt

std_copay_amt
oop_30day_v0 = final_opc_amt / days_supply_cnt * 30;


*/

/*============================================================*
 | 1) censored after discontinuation (include only first episode)  (N=359029, with 2364194 obs )
 *============================================================*/ 
proc sql;
  create table coupon.cohort_long_v01 as
  select distinct a.*, b.first_date, b.disc_date, b.last_date
  from coupon.cohort_long_v00 as a
  left join input.patients_v1 as b
  on a.patient_id = b.patient_id; 
quit; /* 3693474 obs */

* missing(disc_date) -> not discontinuation -> just censored; 
data coupon.cohort_long_v00; set coupon.cohort_long_v00; if missing(disc_date) then discontinuation =0; else discontinuation = discontinuation; run;

/* censored after disc among individuals with discontinuation */
data disc; set coupon.cohort_long_v00; if discontinuation =1; run; /* 2806188 obs */
data non_disc; set coupon.cohort_long_v00; if discontinuation =0; run; /* 887286 obs */

data disc; set disc; if svc_dt <= disc_date; run; /* 2806188 -> 1476908 obs */

data coupon.cohort_long_v01; set disc non_disc; run; /* 2364194 obs */

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from coupon.cohort_long_v01;
quit; /* 359029 individuals !!! */

 /*============================================================*
 | 2) merge with secondary coupon use
 *============================================================*/ 

proc sql; 
   create table coupon.cohort_long_v01 as
   select distinct a.*, b.sec_plan_id, b.sec_payer_pay_amt, b.secondary_coupon
   from coupon.cohort_long_v01 as a
   left join input.secondary_plan_rxfact as b
   on a.claim_id = b.claim_id;
quit;
data coupon.cohort_long_v01; set coupon.cohort_long_v01; if missing(secondary_coupon) then secondary_coupon=0; else secondary_coupon=secondary_coupon; run;

 /*============================================================*
 | 2) primary coupon use & overall coupon use indicators
 *============================================================*/ 
data coupon.cohort_long_v01; set coupon.cohort_long_v01; if payer_type = "Coupon" then primary_coupon=1; else primary_coupon=0; run; 
data coupon.cohort_long_v01; set coupon.cohort_long_v01; if primary_coupon=1 or secondary_coupon=1 then coupon = 1; else coupon =0; run;
proc print data=coupon.cohort_long_v01 (obs=20); where coupon=1; var patient_id svc_dt payer_type primary_coupon secondary_coupon coupon; run;

 /*============================================================*
 | 3) state_program enrollee
 *============================================================*/ 
data coupon.cohort_long_v01; set coupon.cohort_long_v01; drop state_program_count; run;
data coupon.cohort_long_v01; set coupon.cohort_long_v01; if model_type_name in ("STATE ASSISTANCE PROGRAM","STATE EMPLOYEES") then state_program =1; else state_program=0; run;
proc freq data=coupon.cohort_long_v01; table state_program; run;

/*============================================================*
 | 4) OOP standarized for 30days supplies
 *============================================================*/ 
data coupon.cohort_long_v01; set coupon.cohort_long_v01; oop_30day = final_opc_amt / days_supply_cnt * 30; run;

/*============================================================*
 | 5) coupon offset calculate
 *============================================================*/ 
data coupon.cohort_long_v01; set coupon.cohort_long_v01; if primary_coupon=1 then primary_coupon_offset = pri_payer_pay_amt; else primary_coupon_offset=.; run;
data coupon.cohort_long_v01; set coupon.cohort_long_v01; if secondary_coupon=1 then secondary_coupon_offset = sec_payer_pay_amt; else secondary_coupon_offset=.; run;

/*============================================================*
 | 6) total cost per 30 days
 *============================================================*/ 
data coupon.cohort_long_v01; set coupon.cohort_long_v01; total_drug_cost_30day = sum(pri_payer_pay_amt, sec_payer_pay_amt, final_opc_amt)/ days_supply_cnt * 30; run;

proc means data=coupon.cohort_long_v01 n nmiss median q1 q3 min max; var total_drug_cost_30day; run;
 
 /*============================================================*
 | 7) aggregate long data at patient level
 *============================================================*/ 
proc sort data=coupon.cohort_long_v01; by patient_id svc_dt; run;

data coupon.cohort_wide_v00;
  set coupon.cohort_long_v01;    
  by patient_id;
  if first.patient_id then do;
	claim_count =0;
	primary_coupon_count =0;
	secondary_coupon_count =0;
	state_program_count =0;
	cumulative_oop = 0;
	cumulative_1_coupon_offset = 0;
	cumulative_2_coupon_offset = 0;
  end;
  
  claim_count + 1;
  cumulative_oop + oop_30day;
  cumulative_1_coupon_offset + primary_coupon_offset;
  cumulative_2_coupon_offset + secondary_coupon_offset;

  if state_program =1 then state_program_count +1;
  if primary_coupon =1 then primary_coupon_count +1;
  if secondary_coupon =1 then secondary_coupon_count +1;
  
  if last.patient_id then do;
  last_date = svc_dt;
  output;
  end;
run;

/* indicate coupon_user*/
data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; drop coupon_user coupon_count; run;
data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; if primary_coupon_count =0 and secondary_coupon_count =0 then coupon_user=0; else coupon_user=1; run;
data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; coupon_count = primary_coupon_count + secondary_coupon_count; run;
proc freq data=coupon.cohort_wide_v00; table coupon_user; run;


/* aggregate charateristics at the index claim */
proc sort data=coupon.cohort_long_v01; by patient_id svc_dt; run;
data first_claim; set coupon.cohort_long_v01; by patient_id; if first.patient_id; run;

/* merge with the pateint level data */
proc sql;
	create table coupon.cohort_wide_v00 as
	select distinct a.*, b.svc_dt as index_date, b.payer_type as payer_type_index, b.age_at_claim as age_index
	from coupon.cohort_wide_v00 as a
	left join first_claim as b
	on a.patient_id=b.patient_id;
quit;

* oop_30day_per_claim, calculate total coupon offset by patient;
data coupon.cohort_wide_v00;
  set coupon.cohort_wide_v00;

  /* Safely handle division by zero */
  if claim_count > 0 then oop_30day_per_claim = cumulative_oop / claim_count;
  else oop_30day_per_claim = .;

  if primary_coupon_count > 0 then coupon_1_offset_per_coupon = cumulative_1_coupon_offset / primary_coupon_count;
  else coupon_1_offset_per_coupon = .;

  if secondary_coupon_count > 0 then coupon_2_offset_per_coupon = cumulative_2_coupon_offset / secondary_coupon_count;
  else coupon_2_offset_per_coupon = .;

  if coupon_count > 0 then coupon_offset_per_coupon = 
    (cumulative_1_coupon_offset + cumulative_2_coupon_offset) / coupon_count;
  else coupon_offset_per_coupon = .;
run;

data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; if state_program_count >0 then ever_state_program =1; else ever_state_program =0; run;

* duration;
data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; duration_days = intck('day', index_date, last_date); run;
data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; duration_months = duration_days/30; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max; var duration_days; run;


/*============================================================*
 | 5) Table 1 with the wide dataset (N=359029)
 *============================================================*/ 
* age at the index claim;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max; var age_index; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max;
    class coupon_user;
    var age_index;
run;

* gander ; 
proc freq data=coupon.cohort_wide_v00; table patient_gender; run;
proc freq data=coupon.cohort_wide_v00; table patient_gender*coupon_user /norow nopercent; run;

* region ; 
proc freq data=coupon.cohort_wide_v00; table region; run;
proc freq data=coupon.cohort_wide_v00; table region*coupon_user /norow nopercent; run;

* diabetes_history ; 
proc freq data=coupon.cohort_wide_v00; table diabetes_history; run;
proc freq data=coupon.cohort_wide_v00; table diabetes_history*coupon_user /norow nopercent; run;

* duration of episode; 
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max; var duration_months; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max;
    class coupon_user;
    var duration_months;
run;


* claim_count ;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max; var claim_count; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max;
    class coupon_user;
    var claim_count;
run;

* coupon_count ;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max; var coupon_count; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max;
    class coupon_user;
    var coupon_count;
run;

* primary_coupon_count ;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max; var primary_coupon_count; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max;
    class coupon_user;
    var primary_coupon_count;
run;

* secondary_coupon_count ;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max; var secondary_coupon_count; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max;
    class coupon_user;
    var secondary_coupon_count;
run;

* OOP: oop_30day_per_claim coupon_1_offset_per_coupon coupon_2_offset_per_coupon coupon_offset_per_coupon;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std; var oop_30day_per_claim; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max;
    class coupon_user;
    var oop_30day_per_claim;
run;

proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std; var coupon_offset_per_coupon; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max;
    class coupon_user;
    var coupon_offset_per_coupon;
run;

proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std; var coupon_1_offset_per_coupon; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max;
    class coupon_user;
    var coupon_1_offset_per_coupon;
run;

proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std; var coupon_2_offset_per_coupon; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max;
    class coupon_user;
    var coupon_2_offset_per_coupon;
run;


* chnl_cd ; 
proc freq data=coupon.cohort_wide_v00; table chnl_cd; run;
proc freq data=coupon.cohort_wide_v00; table chnl_cd*coupon_user /norow nopercent; run;

* days_supply_cnt ; 
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max; var days_supply_cnt; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 mean std min max;
    class coupon_user;
    var days_supply_cnt;
run;

* index_payer_type with adjusted;
data adjusted; set coupon.cohort_wide_v00; length payer_type_index_adj $100.; 
	if payer_type_index in ("Cash","Discound Card","Unspec","missing","Coupon") then payer_type_index_adj = "Others"; else payer_type_index_adj = payer_type_index; run;
proc freq data=adjusted; table payer_type_index_adj; run;
proc freq data=adjusted; table payer_type_index_adj*coupon_user /norow nopercent; run;

* molecule_name at index; 
proc freq data=coupon.cohort_wide_v00; table molecule_name; run;
proc freq data=coupon.cohort_wide_v00; table molecule_name*coupon_user /norow nopercent; run;

* ever_state_program ; 
proc freq data=coupon.cohort_wide_v00; table ever_state_program; run;
proc freq data=coupon.cohort_wide_v00; table ever_state_program*coupon_user /norow nopercent; run;

* index_date;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max; var index_date; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max;
    class coupon_user;
    var index_date;
run;

* last day;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max; var last_date; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max;
    class coupon_user;
    var last_date;
run;






