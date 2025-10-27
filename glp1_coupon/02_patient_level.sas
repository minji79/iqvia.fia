
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
 | 2) coupon use indicator
 *============================================================*/ 
data coupon.cohort_long_v01; set coupon.cohort_long_v01; if payer_type = "Coupon" then coupon = 1; else coupon =0; run;

proc sort data=coupon.cohort_long_v01; by patient_id svc_dt; run;
data coupon;
  set coupon.cohort_long_v01;
  by patient_id;
  retain coupon_count;

  if first.patient_id then coupon_count = 0;
  if coupon = 1 then coupon_count + 1;
  if last.patient_id then output;

run; /* 359029 individuals */
data coupon; set coupon; if coupon_count = 0 then coupon_user = 0; else coupon_user =1; run; 
proc freq data=coupon; table coupon_user; run;

proc sql;
  create table coupon.cohort_long_v01 as
  select distinct a.*, b.coupon_user, b.coupon_count
  from coupon.cohort_long_v01 as a
  left join coupon as b
  on a.patient_id = b.patient_id; 
quit; /* 2364194 obs */


 /*============================================================*
 | 3) Table 1 with the wide dataset (N=359029)
 *============================================================*/ 
/* pool claim level data at patient level */
proc sort data=coupon.cohort_long_v01; by patient_id svc_dt; run;

data coupon;
  set coupon.cohort_long_v01;
  by patient_id;
  retain coupon_count;

  if first.patient_id then coupon_count = 0;
  if coupon = 1 then coupon_count + 1;
  if last.patient_id then output;

run;

data claim_count;
  set coupon.cohort_long_v01;    
  by patient_id;
  if first.patient_id then do;
	claim_count = 0;
  end;
  
  claim_count + 1;

  if last.patient_id then output;
run;



data coupon.cohort_wide_v00;
  set coupon.cohort_long_v01;
  by patient_id;
  format last_date mmddyy10.;

  if first.patient_id then do;  
		      claim_count = 0;
        coupon_count = 0;
        state_program_count = 0;
        cumulative_oop = 0;
    end;
    
    if coupon = 1 then coupon_count + 1;
    if model_type_name in ("STATE ASSISTANCE PROGRAM","STATE EMPLOYEES") then state_program_count + 1;

    claim_count + 1;
    cumulative_oop = cumulative_oop + final_opc_amt;
    cumulative_days_supply = cumulative_days_supply + days_supply_cnt;
    if last.patient_id then last_date = svc_dt;
    
run;

data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; by patient_id; if first.patient_id; run;

* cumulative_oop_30day = cumulative_oop / cumulative_days_supply * 30; ; 
data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; cumulative_oop_30day = cumulative_oop / cumulative_days_supply * 30; run;

* days_supply_per_claim = cumulative_days_supply / claim_count; 
data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; days_supply_per_claim = cumulative_days_supply / claim_count; run;

proc contents data=coupon.cohort_wide_v00; run;
data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; rename svc_dt =index_date; run;

* duration;
data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; drop  duration_days; run;
data coupon.cohort_wide_v00; set coupon.cohort_wide_v00; duration_days = intck('day', index_date, last_date); run;

proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max; var duration_days; run;




/*============================================================*
 | 4) distribtuion for the Table 1
 *============================================================*/ 
* index_date ;
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



* age at the index claim;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max; var age_at_claim; run;
proc means data=coupon.cohort_wide_v00 n nmiss median q1 q3 min max;
    class coupon_user;
    var age_at_claim;
run;

* claim_count ;
proc means data=claim_count n nmiss median q1 q3 min max; var claim_count; run;
proc means data=claim_count n nmiss median q1 q3 min max;
    class coupon_user;
    var claim_count;
run;

* coupon_count ;
proc means data=coupon n nmiss median q1 q3 mean std min max; var coupon_count; run;
proc means data=coupon n nmiss median q1 q3 mean std min max;
    class coupon_user;
    var coupon_count;
run;

* index_payer_type ; 
proc freq data=coupon.cohort_wide_v00; table payer_type; run;
proc freq data=coupon.cohort_wide_v00; table payer_type*coupon_user /norow nopercent; run;

* gander ; 
proc freq data=coupon.cohort_wide_v00; table patient_gender; run;
proc freq data=coupon.cohort_wide_v00; table patient_gender*coupon_user /norow nopercent; run;

* region ; 
proc freq data=coupon.cohort_wide_v00; table region; run;
proc freq data=coupon.cohort_wide_v00; table region*coupon_user /norow nopercent; run;

* diabetes_history ; 
proc freq data=coupon.cohort_wide_v00; table diabetes_history; run;
proc freq data=coupon.cohort_wide_v00; table diabetes_history*coupon_user /norow nopercent; run;

* chnl_cd ; 
proc freq data=coupon.cohort_wide_v00; table chnl_cd; run;
proc freq data=coupon.cohort_wide_v00; table chnl_cd*coupon_user /norow nopercent; run;

* molecule_name; 
proc freq data=coupon.cohort_wide_v00; table molecule_name; run;
proc freq data=coupon.cohort_wide_v00; table molecule_name*coupon_user /norow nopercent; run;








