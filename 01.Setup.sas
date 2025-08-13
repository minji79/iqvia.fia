
/************************************************************************************
	1.   Library Setting
************************************************************************************/

directory: cd /dcs07/hpm/data/iqvia_fia

/* run sas */
rm ~/.config/chromium/Singleton*
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* run R */
srun --pty --x11 --partition sas bash
module load R
module load rstudio
rstudio

setwd("/users/59883/c-mkim255-59883/glp1off/sas_input")
*/

/* set library */
libname input "/dcs07/hpm/data/iqvia_fia/biosim";   /* my own directory */
libname tuto "/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r/data";   /* my own directory */

libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */

libname glp1 "/dcs07/hpm/data/iqvia_fia/glp1_paper";
libname auth_gen "/dcs07/hpm/data/iqvia_fia/auth_generics";
libname form_apx "/dcs07/hpm/data/iqvia_fia/formulary_approx";   /* formulary_approx  */

* see the files under glp1;

/*
01_load_and_merge_glp1.do
****Xcode****
Step1b_UniqueUsers.do -> 25 rows to identify unique plan for each patient
01_load_and_merge_glp1.do
01_load_and_merge_glp1_v2.do
Step1_FindUsers.do -> 15 rows to merge files
Step2_GetAllClaims.do -> 10 rows to merge files
Descriptive_stats.do 
Descriptive_stats_index.do -> 48 rows
glp_switchers_analysis.do
glp_switchers.do   -> similar as the above
*/

/************************************************************************************
	2.   Coverting DTA files to SAS files
************************************************************************************/

proc import datafile="/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2024.dta" out=input.RxFact2024 dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2022.dta" out=input.RxFact2022 dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2020.dta" out=input.RxFact2020 dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2018.dta" out=input.RxFact2018 dbms=dta replace; run;


/************************************************************************************
	3.   Read other files
************************************************************************************/
* convert do file to sas files;
filename dofile "/dcs07/hpm/data/iqvia_fia/glp1_paper/01_load_and_merge_glp1.do";
data do_commands;
    infile dofile;
    input line $char200.;
run;

proc print data=do_commands; run;


* see the dta files;
proc import datafile="/dcs07/hpm/data/iqvia_fia/reduced/RxFact2020_small.dta"
    out=mydata
    dbms=dta
    replace;
run;
proc print data=mydata (obs=10); title "RxFact2020_small.dta"; run;
proc contents data=mydata; run;






filename myfile "/dcs07/hpm/data/iqvia_fia/glp1_paper/01_load_and_merge_glp1.sh ";

data preview;
    infile myfile;
    input line $char200.;
run;

proc print data=preview(obs=10); run;
