


/* run sas */
rm ~/.config/chromium/Singleton*
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* set library */
libname plan "/dcs07/hpm/data/iqvia_fia/jhu_plan";   
libname input "/dcs07/hpm/data/iqvia_fia/glp1_disc";   /* my own directory */
libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */
libname glp1 "/dcs04/hpm/data/iqvia_fia/glp1_paper/data";
libname biosim "/dcs07/hpm/data/iqvia_fia/biosim";   /* for reference files */
libname coupon "/dcs07/hpm/data/iqvia_fia/glp1_disc/glp1_coupon";   
libname parquet "/dcs07/hpm/data/iqvia_fia/parquet/data";   

libname fast "/fastscratch/myscratch/mkim";   /* my fastbarch with 1 TB memory */


/*============================================================*
 | 1. set list up for plan information - 277 plans were identified
 *============================================================*/
* plan;
proc contents data=biosim.plan; run;

data plan.eric_plan;
    set biosim.plan;
    if index(upcase(plan_name), "3M COMPANY") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "ALIGHT") > 0 then flag = 1;  
    else if index(upcase(plan_name), "ALLIANT HEALTH") > 0 then flag = 1;
    else if index(upcase(plan_name), "AMAZON") > 0 then flag = 1;  /* include discount card program */
    else if index(upcase(plan_name), "AMERICAN AIR") > 0 then flag = 1;
    else if index(upcase(plan_name), "AON") > 0 then flag = 1;
    else if index(upcase(plan_name), "GALLAGHER") > 0 then flag = 1; /* 2 */
    else if index(upcase(plan_name), "AT AND T") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "BANK OF AMERICA") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLACKROCK") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLUE SHIELD MED D GNRL (CA)") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLUE SHIELD 65 PLUS 2 (CA)") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLUE SHIELD MDCR RX ENHD (CA)") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLUE SHIELD MED ADV GENERAL (CA)") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLUE SHIELD OF CA MEDI-CAL (CA)") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLUE SHIELD SPECTRUM PPO (CA)") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLUE SHIELD OF CA HIX PPO GNRL") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLUE SHIELD MED PDP GENERAL (CA)") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLUE SHIELD CA UNSPECIFIED") > 0 then flag = 1;
    else if index(upcase(plan_name), "BOEING COMPANY") > 0 then flag = 1;  /* 2 */
    else if index(upcase(plan_name), "BRISTOL-MYERS") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "CATERPILLAR") > 0 then flag = 1;
    else if index(upcase(plan_name), "CHEVRON CORPORATION") > 0 then flag = 1;
    else if index(upcase(plan_name), "CIGNA") > 0 then flag = 1;          /* 169 plans */
    else if index(upcase(plan_name), "COMCAST/NBC") > 0 then flag = 1;
    else if index(upcase(plan_name), "COSTCO WHOLESALE") > 0 then flag = 1;
    else if index(upcase(plan_name), "CROWELL") > 0 then flag = 1;
    else if index(upcase(plan_name), "CVS HEALTH") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "DEERE") > 0 then flag = 1;
    else if index(upcase(plan_name), "DELTA AIR") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "EATON") > 0 then flag = 1; /* 2 */
    else if index(upcase(plan_name), "ELEVANCE") > 0 then flag = 1;
    else if index(upcase(plan_name), "EXXON") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "FEDERAL RESERVE") > 0 then flag = 1;
    else if index(upcase(plan_name), "FIDELITY INVESTMENTS") > 0 then flag = 1;
    else if index(upcase(plan_name), "FRESENIUS") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "GENERAL DYNAMICS") > 0 then flag = 1;
    else if index(upcase(plan_name), "GENERAL ELECTRIC") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "HALLIBURTON") > 0 then flag = 1;
    else if index(upcase(plan_name), "HEWLETT") > 0 then flag = 1;
    else if index(upcase(plan_name), "HOME DEPOT") > 0 then flag = 1;
    else if index(upcase(plan_name), "HONEYWELL") > 0 then flag = 1;
    else if index(upcase(plan_name), "HYATT") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "IBM") > 0 then flag = 1;
    else if index(upcase(plan_name), "MOTORS") > 0 then flag = 1;
    else if index(upcase(plan_name), "JOHNSON AND JOHNSON") > 0 then flag = 1;
    else if index(upcase(plan_name), "JPMORGAN") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "KAISER") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "LOCKHEED MARTIN") > 0 then flag = 1;
    else if index(upcase(plan_name), "LOWES") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "MERCER") > 0 then flag = 1;
    else if index(upcase(plan_name), "METLIFE") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "NESTLE") > 0 then flag = 1;
    else if index(upcase(plan_name), "NOKIA") > 0 then flag = 1;
    else if index(upcase(plan_name), "NOVARTIS PHARMACEUTICALS") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "PEPSI") > 0 then flag = 1;
    else if index(upcase(plan_name), "PHILIP") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "T ROWE PRICE GROUP INC") > 0 then flag = 1;
    else if index(upcase(plan_name), "TIAA") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "US BANK") > 0 then flag = 1;
    else if index(upcase(plan_name), "UNION PACIFIC") > 0 then flag = 1;
    else if index(upcase(plan_name), "UNITED SERVICE") > 0 then flag = 1;
    else if index(upcase(plan_name), "UNITEDHEALTH") > 0 then flag = 1;
    else if index(upcase(plan_name), "UPS - ESI") > 0 then flag = 1;
    else if index(upcase(plan_name), "UPS - CAREMARK") > 0 then flag = 1;
    else if index(upcase(plan_name), "UPS UNION EMPLOYEE") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "VERIZON") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "WALMART") > 0 then flag = 1;
    else if index(upcase(plan_name), "WELLS FARGO CORP") > 0 then flag = 1;
    else if index(upcase(plan_name), "WILLIS TOWERS WATSON") > 0 then flag = 1;
    else if index(upcase(plan_name), "WINSTON") > 0 then flag = 1;
    else if index(upcase(plan_name), "WORKDAY") > 0 then flag = 1;
    
    else flag = 0;
run;
data plan.eric_plan; set plan.eric_plan; if flag=1; run;
proc print data=plan.eric_plan; run; /* 277 unit plans */

proc print data=biosim.plan; 
where index(upcase(plan_name), "FEDERAL RESERVE") > 0 or index(upcase(plan_name), "GENERAL DYNAMICS") > 0;
    run;


/*============================================================*
 | 2. form all claims for under ERIC plans (at claim level) -  
 *============================================================*/

/* 2017 ~ 2024 */
proc sql; 
  create table eric_claim_1824 as
  select distinct a.*
  from input.RxFact_2018_2024_ili as a 
  inner join plan.eric_plan as b
  on a.payer_id = b.payer_id and a.plan_id = b.plan_id;
quit;

/* 2025 */
proc sql; 
  create table eric_claim_25 as
  select distinct a.*
  from biosim.RxFact2025_clean as a 
  inner join plan.eric_plan as b
  on a.payer_id = b.payer_id and a.plan_id = b.plan_id;
quit;

data plan.eric_claim; set eric_claim_1824 eric_claim_25; run; /* 103262143 claims */
proc print data=plan.eric_claim (obs=10); where year=2025; run;

/* number of claims by year */
proc freq data=plan.eric_claim; table year; run;


/*============================================================*
 | 3. patient level (generate number of patients in data (by year) as well as N claims for each employer?)
 *============================================================*/
/* total number of all users (N=) */
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from plan.eric_claim;
quit;

/* number of patients by year */
proc sql;
  create table patient_count_by_year as
  select 
      year,
      count(distinct patient_id) as count_patient_all
  from plan.eric_claim
  group by year(svc_dt)
  order by year;
quit;
proc sort data=patient_count_by_year nodupkey; by _ALL_; run;
proc print data= patient_count_by_year (obs=10); run;
 
/* median number of months stay */
proc sort data=plan.eric_claim; by plan_id patient_id; run;

data plan.eric_patient; 
set plan.eric_claim; 
by plan_id patient_id; 
 
run;

