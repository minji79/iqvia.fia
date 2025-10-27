

/*============================================================*
 | 1) start from all glp1 claims between 2018 - 2024
 *============================================================*/

proc contents data=input.rx18_24_glp1_long_v00; run;
proc contents data=input.patients_v1; run;

/* how many claims in 2017 Jan - 2017 Jun */
data sample; set input.rx_17_glp1; if svc_dt < "01JUL2017"d; run; /* 404194 out of 854405 */

proc sort data=input.rx18_24_glp1_long_v00; by patient_id svc_dt; run;
proc sql; create table coupon.cohort_long_v00 as 
	select * 
	from input.rx18_24_glp1_long_v00 as a 
	where a.patient_id in ( 
		select patient_id from input.patients_v1 
		where first_date > "01JAN2018"d ); 
quit; /* 10030201 obs */


 /*============================================================*
 | 2) only paid claims (N=745240)
 *============================================================*/
data coupon.cohort_long_v00; set coupon.cohort_long_v00; if encnt_outcm_cd = "PD"; run; /* 8250478 obs */

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from coupon.cohort_long_v00;
quit; /* 745240 individuals */

/*============================================================*
 | 3) exclude Medicare / Medicaid (N=472220, with 4757398 obs)
 *============================================================*/ 
 * identify individuals who enrolled in either Medicare or Medicaid; 
data medi;
  set coupon.cohort_long_v00;    
  by patient_id;
  if first.patient_id then do;
	medicare_count = 0;
	medicaid_count = 0;
  end;

  if payer_type in ("Medicaid: FFS","Medicaid: MCO","Medicaid: Unspec") then medicaid_count + 1;
  if payer_type in ("Medicare D: ADV","Medicare D: TM","Medicare D: Unspec","Part B") then medicare_count + 1;

  if last.patient_id then output;
run;

data medi; set medi; if medicare_count = 0 and medicaid_count = 0 then medi_enroll =0; else medi_enroll =1; run;
proc freq data=medi; table medi_enroll; run;

* merge with cohort, and exclude them;
proc sql;
	create table coupon.cohort_long_v00 as
	select a.*, b.medi_enroll
	from coupon.cohort_long_v00 as a
	left join medi as b
	on a.patient_id = b.patient_id; 
quit;
data coupon.cohort_long_v00; set coupon.cohort_long_v00; if medi_enroll = 0; run; /* 3693474 obs */

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from coupon.cohort_long_v00;
quit; /* 359,029 individuals */

/*============================================================*
 | 4) required at least 2 fills for a given product (N=336166)
 *============================================================*/ 
proc sort data=coupon.cohort_long_v00; by patient_id svc_dt; run;

data criteria;
  set coupon.cohort_long_v00;    
  by patient_id;
  if first.patient_id then do;
	claim_count = 0;
  end;
  
  claim_count + 1;

  if last.patient_id then output;
run;
data criteria; set criteria; if claim_count > 1; keep patient_id claim_count; run; /* 336166 obs */

/*
proc sql;
	create table coupon.cohort_long_v00 as
	select distinct a.*, b.claim_count
	from coupon.cohort_long_v00 as a
	inner join criteria as b
	on a.patient_id = b.patient_id;
quit;

proc print data=coupon.cohort_long_v00 (obs=10); run;
proc freq data=coupon.cohort_long_v00; table payer_type; run;
