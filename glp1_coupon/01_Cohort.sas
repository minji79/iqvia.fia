

/*============================================================*
 | 1) start from all glp1 claims between 2018 - 2024
 *============================================================*/

proc contents data=input.rx18_24_glp1_long_v00; run;
proc contents data=input.patients_v1; run;

/* how many claims in 2017 Jan - 2017 Jun */
data sample; set input.rx_17_glp1; if svc_dt < "01JUL2017"d; run; /* 404194 out of 854405 */

proc sql;
	create table coupon.cohort_long_v00 as
	select *
	from input.rx18_24_glp1_long_v00 as a
	where a.patient_id in (
		select patient_id
		from input.patients_v1
		where first_date > "01JAN2018"d
	);
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
 | 3) exclude Medicare / Medicaid (N=413380)
 *============================================================*/ 
data coupon.cohort_long_v00; set coupon.cohort_long_v00; if payer_type in ("Commercial","Exchange","Cash","Coupon","Unspec","PBM","Discount Card","PPO/HMO","Unspecified"); run; /* 4126500 obs */

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from coupon.cohort_long_v00;
quit;


