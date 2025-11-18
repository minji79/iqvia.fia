
directory: cd /dcs07/hpm/data/iqvia_fia


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

libname fast "/fastscratch/myscratch/mkim";   /* my fastbarch with 1 TB memory */



/*============================================================*
 | 1. identify Hopkin Plan -> payer_id & plan_id
 *============================================================*/
proc print data=biosim.plan;   where index(upcase(payer_name), "HOPKINS") > 0; run; /* one employee plan among 6 plans */
data plan.hopkins_plan; set biosim.plan; if payer_id = 13461186 and plan_id = 23142; run;

proc contents data=input.RxFact_2018_2024_ili; run;
proc contents data=biosim.RxFact2024; run;
 
/*============================================================*
 | 2. Anyone who ever had an attempted claim (FOR ANY DRUG) | hopkins_plan_claim_all & hopkins_plan_patient_all
 *============================================================*/

/* in the primary payer */
proc sql; 
  create table plan.as_primary as
  select distinct a.*
  from input.RxFact_2018_2024_ili as a 
  inner join plan.hopkins_plan as b
  on a.payer_id = b.payer_id and a.plan_id = b.plan_id;
quit;

/* in the secondary payer */
proc sql; 
  create table plan.as_secondary as
  select distinct a.*
  from input.RxFact_2018_2024_ili as a 
  inner join plan.hopkins_plan as b
  on a.sec_payer_id = b.payer_id and a.sec_plan_id = b.plan_id;
quit;




/*============================================================*
 | 3. Ever filled or attempted to fill a glp1 (WITH ANY PLAN ID) | glp1_claim_all & glp1_patient_all
 *============================================================*/







/*============================================================*
 | 4. Ever filled or attempted to fill a glp1 (WITH ANY PLAN ID) | glp1_claim_all
 *============================================================*/










