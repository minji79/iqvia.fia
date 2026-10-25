
/************************************************************************************
	0.   Library Setting
************************************************************************************/

directory: cd /dcs07/hpm/data/iqvia_fia

/* run sas */
rm ~/.config/chromium/Singleton*
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* set library */
libname coupon "/dcs07/hpm/data/iqvia_fia/coupon";   /* shared directory */

libname input "/dcs07/hpm/data/iqvia_fia/glp1_disc";   /* my own directory */
libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */
libname glp1 "/dcs04/hpm/data/iqvia_fia/glp1_paper/data";
libname biosim "/dcs07/hpm/data/iqvia_fia/biosim";   /* for reference files */
libname fast "/fastscratch/myscratch/mkim";   /* my fastbarch with 1 TB memory */

* new product files;
"/dcs07/hpm/data/iqvia_fia/codex_levy/rxfact_pipeline_release_hardened/scratch/v1.0.0_2017_2025_full_year_hardened_candidate/enriched/product_reference.parquet"

/* 2017-2024 raw data */
/*  1-3Q 2025 raw data */
/*  4Q 2025 raw data */
/dcs07/hpm/data/iqvia_fia/full_raw/2025_addon/Q42025RxFact.txt



proc contents data=input.RxFact_2018_2024_ili; run;

proc contents data=biosim.rxfact2025; run;
proc contents data=biosim.patient; run;
proc contents data=biosim.plan; run;
proc freq data=biosim.plan; table model_type_name; run;
proc freq data=biosim.plan; table model_type; run;

proc contents data=biosim.product; run;
proc contents data=biosim.provider; run;
proc contents data=input.LevyPDRJRV; run;
proc contents data=input.redbook2019; run;
proc print data=input.redbook2019 (obs=5); run;
