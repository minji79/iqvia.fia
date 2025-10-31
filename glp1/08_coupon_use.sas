
/************************************************************************************
	1. add secondary payer information - coupon
************************************************************************************/

proc sql; 
   create table input.secondary_plan_rxfact as
   select distinct a.*, b.model_type_name
   from input.secondary_plan_rxfact as a
   left join biosim.plan as b
   on a.sec_plan_id = b.plan_id;
quit;

data input.secondary_plan_rxfact; set input.secondary_plan_rxfact; if model_type_name = 'COUPON/VOUCHER PROGRAM' then secondary_coupon =1; else secondary_coupon=0; run;
data input.secondary_plan_rxfact; set input.secondary_plan_rxfact; if model_type_name = 'DISCOUNT CARD PROGRAM' then secondary_discount_card =1; else secondary_discount_card=0; run; /* 'MEDICARE DISCOUNT CARD PROGRAM' */

data input.secondary_plan_rxfact; set input.secondary_plan_rxfact; if model_type_name in ('STATE ASSISTANCE PROGRAM','STATE EMPLOYEES') then state_employee =1; else state_employee=0; run; /* 'MANAGED MEDICAID/MEDICARE SUPPLEMENT/MEDIGAP/STATE ASSISTANCE' */
data input.secondary_plan_rxfact; set input.secondary_plan_rxfact; if model_type_name in ('FEDERAL ASSISTANCE PROGRAM','FEDERAL EMPLOYEE') then federal_employee =1; else federal_employee=0; run;

proc print data=input.secondary_plan_rxfact (obs=10); run;

/* input.rx18_24_glp1_long_v00 */
proc sql; 
   create table input.rx18_24_glp1_long_v00 as
   select distinct a.*, b.sec_plan_id, b.sec_payer_pay_amt, b.secondary_coupon, b.secondary_discount_card
   from input.rx18_24_glp1_long_v00 as a
   left join input.secondary_plan_rxfact as b
   on a.claim_id = b.claim_id;
quit;

/* input.rx18_24_glp1_long_v01 */
proc sql; 
   create table input.rx18_24_glp1_long_v01 as
   select distinct a.*, b.sec_plan_id, b.sec_payer_pay_amt, b.secondary_coupon, b.secondary_discount_card
   from input.rx18_24_glp1_long_v01 as a
   left join input.secondary_plan_rxfact as b
   on a.claim_id = b.claim_id;
quit;
