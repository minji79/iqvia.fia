/************************************************************************************
| Project name : Biosimilar 
| Program name : 01_Cohort_dertivation
| Date (update): June 2024
| Task Purpose : 
|      1. 00
| Main dataset : (1) procedure, (2) tx.patient, (3) tx.patient_cohort & tx.genomic (but not merged)
| Final dataset : min.bs_user_all_v07 (with distinct indiv)
************************************************************************************/

directory: cd /dcs07/hpm/data/iqvia_fia

/* run sas */
rm ~/.config/chromium/Singleton*
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* set library */
libname input "/dcs07/hpm/data/iqvia_fia/biosim";   /* my own directory */

libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */

libname glp1 "/dcs07/hpm/data/iqvia_fia/glp1_paper";
libname auth_gen "/dcs07/hpm/data/iqvia_fia/auth_generics";
libname form_apx "/dcs07/hpm/data/iqvia_fia/formulary_approx";   /* formulary_approx  */

/************************************************************************************
	1. molecule	     N = 99,350
************************************************************************************/

%macro yearly(data=, refer=);

data &data;
  set &refer;
  if index(upcase(molecule_name),'ADALIMUMAB')>0;
run;

%mend yearly;
%yearly(data=input.adalimumab_24_v00, refer=input.RxFact2024);
%yearly(data=input.adalimumab_22_v00, refer=input.RxFact2022);
%yearly(data=input.adalimumab_20_v00, refer=input.RxFact2020);
%yearly(data=input.adalimumab_18_v00, refer=input.RxFact2018);

proc contents data=input.adalimumab_24_v00; run;
