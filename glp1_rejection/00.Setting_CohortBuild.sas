
/************************************************************************************
	1.   Library Setting
************************************************************************************/

directory: cd /dcs07/hpm/data/iqvia_fia

/* run sas */
rm ~/.config/chromium/Singleton*
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* set library */
libname input "/dcs07/hpm/data/iqvia_fia/glp1_disc";   /* my own directory */
libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */
libname glp1 "/dcs04/hpm/data/iqvia_fia/glp1_paper/data";
libname biosim "/dcs07/hpm/data/iqvia_fia/biosim";   /* for reference files */

libname fast "/fastscratch/myscratch/mkim";   /* my fastbarch with 1 TB memory */



/*============================================================*
 | 1) Load raw claims - adding 25 datasets
 *============================================================*/
* add 25 dataset;
proc contents data=input.rx_24_glp1; run;
proc contents data=biosim.RxFact2025_clean; run;

* glp1 users in 2025;
data input.rx_25_glp1; set biosim.RxFact2025_clean; if molecule_name in ("DULAGLUTIDE", "EXENATIDE", "LIRAGLUTIDE", "LIRAGLUTIDE (WEIGHT MANAGEMENT)", "LIXISENATIDE",
"SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)"); run;

* convert dominant payer file for 2025 and merge with data;
proc import datafile="/dcs07/hpm/data/iqvia_fia/parquet/data/insurance_patient_year25.dta" out=biosim.insurance_patient_year25 dbms=dta replace; run;
proc print data=biosim.insurance_patient_year25 (obs=10); where year ==2024; run;

* with primary cohort;
proc sql;
	create table input.rx_25_glp1 as
	select distinct a.*, b.dominant_payer
	from input.rx_25_glp1 as a
	left join biosim.insurance_patient_year25 as b
	on a.patient_id = b.patient_id;
quit;






proc sql;
  create table input.rx_17_glp1 as
  select a.*, 
         b.molecule_name, 
         b.package_size, 
         b.strength
  from rx_17_glp1 as a
  inner join glp1 as b
    on a.ndc = b.product_ndc;
quit; /* 854,405 */

