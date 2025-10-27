
/*============================================================*
 | 1) censored after discontinuation (include only first episode)  (N=252,371, 1,651,909 obs )
 *============================================================*/ 
* coupon use indicator;
data coupon.cohort_long_v00; set coupon.cohort_long_v00; if payer_type = "Coupon" then coupon = 1; else coupon =0; run;

proc sql;
  create table coupon.cohort_long_v01 as
  select distinct a.*, b.first_date, b.disc_date, b.last_date
  from coupon.cohort_long_v00 as a
  left join input.patients_v1 as b
  on a.patient_id = b.patient_id; 
quit; /* 4049286 obs */

data coupon.cohort_long_v01; set coupon.cohort_long_v01; if svc_dt <= disc_date; run; /* 1,651,909 obs */

 /*============================================================*
 | 5) coupon use indicator
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

run;
data coupon; set coupon; if coupon_count = 0 then coupon_user = 0; else coupon_user =1; run; 

proc sql;
  create table coupon.cohort_long_v01 as
  select distinct a.*, b.coupon_user, b.coupon_count
  from coupon.cohort_long_v01 as a
  left join coupon as b
  on a.patient_id = b.patient_id; 
quit; /* 1651909 obs */

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from coupon.cohort_long_v00;
quit; /* 745240 individuals */



/*
pri_pat_pay_amt
pri_payer_pay_amt

sec_plan_id
sec_payer_pay_amt

std_copay_amt
*/


