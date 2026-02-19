
/*============================================================*
 | 1. check 25 files
 *============================================================*/
proc contents data=biosim.RxFact2025; run;
proc freq data=biosim.RxFact2025; table rjct_cd; run;

data biosim.RxFact2025; set biosim.RxFact2025; year=year(svc_dt); run;
data biosim.RxFact2025; set biosim.RxFact2025; if year = 2025; run;
proc freq data=biosim.RxFact2025; table year; run;



proc contents data=biosim.RxFact2025_clean; run;
proc freq data=biosim.RxFact2025_clean; table year; run;
data biosim.RxFact2025_clean; set biosim.RxFact2025_clean; if year = 2025; run;

proc freq data=biosim.RxFact2025_clean; table encnt_outcm_cd; run;



proc contents data=input.RxFact_2018_2024_ili; run;

/*============================================================*
 | 2. merge encnt_outcm_cd again
 *============================================================*/
* make pdrjrv file for 2025;
proc import datafile="/dcs07/hpm/data/iqvia_fia/full_raw/2025_addon/LevyPDRJRV_25.dta" out=biosim.LevyPDRJRV_25 dbms=dta replace; run;

proc print data=biosim.LevyPDRJRV_25 (obs=10); run;

* merge with pdrjrv file for 2025 data;
data biosim.RxFact2025_clean; set biosim.RxFact2025_clean; drop encnt_outcm_cd; run;
proc sql; 
  create table biosim.RxFact2025_clean as
  select distinct a.*, b.encnt_outcm_cd
  from biosim.RxFact2025_clean as a 
  left join biosim.LevyPDRJRV_25 as b
  on a.claim_id = b.claim_id;
quit;
proc freq data=biosim.RxFact2025_clean; table encnt_outcm_cd; run;

