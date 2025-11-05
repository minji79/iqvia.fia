
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



/*============================================================*
 | 2) coupon / discount card use indicator
 *============================================================*/
proc print data=input.rx18_24_glp1_long_v01 (obs=10); run;
proc freq data= input.rx18_24_glp1_long_v01; table payer_type; run;

proc sort data=input.rx18_24_glp1_long_v01; by patient_id svc_dt; run;

data coupon; 
  set input.rx18_24_glp1_long_v01;       
  by patient_id;
  retain cash_count coupon_count_1st discount_card_count_1st coupon_count_2nd discount_card_count_2nd claim_count;

  if first.patient_id then do;
    cash_count = 0;
    coupon_count_1st = 0;
    discount_card_count_1st = 0;
	coupon_count_2nd = 0;
    discount_card_count_2nd = 0;
    claim_count = 0;
  end;

  claim_count + 1;
  if payer_type = "Cash" then cash_count_1st + 1;
  else if payer_type = "Coupon" then coupon_count_1st + 1;
  else if payer_type = "Discount Card" then discount_card_count_1st + 1;
  else if secondary_coupon = 1 then coupon_count_2nd + 1;
  else if secondary_discount_card = 1 then discount_card_count_2nd + 1;

  if last.patient_id then output;

  keep patient_id cash_count coupon_count_1st coupon_count_2nd discount_card_count_1st discount_card_count_2nd claim_count;
run;

data coupon; set coupon; if cash_count >0 then cash_ever = 1; else cash_ever = 0; run;
data coupon; set coupon; if coupon_count_1st >0 or coupon_count_2nd >0 then coupon_ever = 1; else coupon_ever = 0; run;
data coupon; set coupon; if discount_card_count_1st >0 or discount_card_count_2nd >0 then discount_card_ever = 1; else discount_card_ever = 0; run;

proc print data=coupon (obs=10); run;


* merge with the dataset; 
data input.patients_v0; set input.patients_v0; drop claim_count cash_count coupon_count discount_card_count cash_ever coupon_ever discount_card_ever; run;
data input.patients_v1; set input.patients_v1; drop claim_count cash_count coupon_count discount_card_count cash_ever coupon_ever discount_card_ever; run;


proc sql;
	 create table input.patients_v0 as
	 select distinct a.*, b.claim_count, b.cash_count, b.coupon_count_1st, b.coupon_count_2nd, b.discount_card_count_1st, b.discount_card_count_2nd, b.cash_ever, b.coupon_ever, b.discount_card_ever 
	 from input.patients_v0 as a
	 left join coupon as b
	 on a.patient_id = b.patient_id;
quit;

proc sql;
	 create table input.patients_v1 as
	 select distinct a.*, b.claim_count, b.cash_count, b.coupon_count_1st, b.coupon_count_2nd, b.discount_card_count_1st, b.discount_card_count_2nd, b.cash_ever, b.coupon_ever, b.discount_card_ever 
	 from input.patients_v1 as a
	 left join coupon as b
	 on a.patient_id = b.patient_id;
quit;

proc freq data=input.patients_v1; table discount_card_ever; run;


 

