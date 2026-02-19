


/*============================================================*
 | 1. id for WALMART employees
 *============================================================*/

data plan.id_walmart; set plan.eric_claim; if index(upcase(plan_name), "WALMART") > 0; run;
proc sql;
    create table plan.id_walmart as
    select distinct patient_id
    from plan.id_walmart;
quit;

/*============================================================*
 | 2. all claims for the WALMART employees
 *============================================================*/

proc contents data=biosim.RxFact2025; run;  /* 36 var */
proc contents data=input.RxFact_2018_2024_ili; run; /* 35 var */



/* 2017 ~ 2024 */
proc sql; 
  create table walmart_claim_1824 as
  select distinct a.*
  from input.RxFact_2018_2024_ili as a 
  inner join plan.id_walmart as b
  on a.patient_id = b.patient_id;
quit;



/* 2025 */
proc sql; 
  create table walmart_claim_25 as
  select distinct a.*
  from biosim.RxFact2025 as a 
  inner join plan.id_walmart as b
  on a.patient_id = b.patient_id;
quit;

data plan.walmart_claim; set walmart_claim_1824 walmart_claim_25; run; 
proc print data=plan.walmart_claim (obs=10); where year=2025; run;

/* number of claims by year */
proc freq data=plan.walmart_claim; table year; run;





