
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
libname input "/dcs07/hpm/data/iqvia_fia/glp1_disc";   /* my own directory */
libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */
libname glp1 "/dcs04/hpm/data/iqvia_fia/glp1_paper/data";
libname biosim "/dcs07/hpm/data/iqvia_fia/biosim";   /* for reference files */

/*
libname tuto "/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/stata/data";   
libname auth_gen "/dcs07/hpm/data/iqvia_fia/auth_generics";
libname form_apx "/dcs07/hpm/data/iqvia_fia/formulary_approx";   /* formulary_approx  */


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
* raw claims;
proc import datafile="/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2024.dta" out=input.RxFact2024 dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2022.dta" out=input.RxFact2022 dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2020.dta" out=input.RxFact2020 dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2018.dta" out=input.RxFact2018 dbms=dta replace; run;

* reference files;
proc import datafile="/dcs07/hpm/data/iqvia_fia/ref/patient.dta" out=input.patient dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/ref/provider.dta" out=input.provider dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/ref/plan.dta" out=input.plan dbms=dta replace; run;

proc import datafile="/dcs07/hpm/data/iqvia_fia/glp1_disc/LevyPDRJRV.csv"
    out=input.LevyPDRJRV
    dbms=csv
    replace;
    getnames=yes;   /* first row has column names */
    guessingrows=max; /* lets SAS scan all rows to guess column types */
run;

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
/* mydata: Step1_Index_18_glp_switch.dta */
proc import datafile="/dcs04/hpm/data/iqvia_fia/glp1_paper/data/Step1_Index_18_glp_switch.dta"
    out=mydata
    dbms=dta
    replace;
run;
proc print data=mydata (obs=10); title "Step1_Index_18_glp_switch.dta"; run;
proc contents data=mydata; run;

* distinct patient number;
proc sql; 
    select count(distinct patient_id) as count_patient_switch
    from mydata;
quit;

/* mydata2: Step1_Index_18_glp_ER.dta */
proc import datafile="/dcs04/hpm/data/iqvia_fia/glp1_paper/data/Step1_Index_24_glp_ER.dta"
    out=mydata2
    dbms=dta
    replace;
run;
proc sort data=mydata2; by patient_id svc_dt; run;
proc print data=mydata2 (obs=20); title "Step1_Index_24_glp_ER.dta"; run;
proc contents data=mydata2; run;

* check the name of molecule;
proc freq data=mydata2; table molecule_name; run;
proc freq data=mydata2; table rjct_cd; run;

* distinct patient number;
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from mydata2;
quit;


data patient; set biosim.patient; keep patient_id; run;
proc sort data=patient nodupkey; by patient_id; run;
proc contents data=patient; run;

