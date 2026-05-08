

/************************************************************************************
	0.   Library Setting
************************************************************************************/

directory: cd /dcs07/hpm/data/iqvia_fia

/* run sas */
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* set library */
libname input "/dcs07/hpm/data/iqvia_fia/glp1_adolescents";   /* emaan directory */
libname minji "/dcs07/hpm/data/iqvia_fia/glp1_disc";   /* minji directory */
libname biosim "/dcs07/hpm/data/iqvia_fia/biosim";   /* all cleaned reference files */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files from Joe */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */


/************************************************************************************
	1. all GLP1 users claims in long form (Jan 17 - Sep 25)
************************************************************************************/

data input.glp1_users_long_v0; set minji.rx_25_glp1 minji.rx_24_glp1 minji.rx_23_glp1 minji.rx_22_glp1 minji.rx_21_glp1 minji.rx_20_glp1 minji.rx_19_glp1 minji.rx_18_glp1 minji.rx_17_glp1; run; 
/* total # of claims = 31,484,793 */

/************************************************************************************
	2. index claims (the very first rx prescriptions - attempt) for all GLP1 users claims in wide form
************************************************************************************/

/* paid > reversed > rejected */
data input.id_index;
    set input.glp1_users_long_v0;
    if encnt_outcm_cd = "PD" then paid_priority = 0;  
    else if encnt_outcm_cd = "RV" then paid_priority = 1;  
    else paid_priority = 2;
run;
proc sort data=input.id_index; by patient_id rx_written_dt svc_dt final_claim_ind descending paid_priority; run;
/* proc print data=input.id_index (obs=20); var patient_id rx_written_dt svc_dt fill_nbr encnt_outcm_cd final_claim_ind; run; */

data input.id_index;
    set input.id_index;
    by patient_id rx_written_dt svc_dt;
    if first.patient_id then output;
    drop paid_priority;
run;           /* 1,262,977 individuals */


/************************************************************************************
	3. all GLP1 users claims in long form (Jan 17 - Sep 25)
************************************************************************************/

* clean the patient_birth_year;
proc sql;
    create table id_age as
    select distinct patient_id, max(patient_birth_year) as patient_birth_year
    from biosim.patient
    group by patient_id;
quit; /* 12170856 obs */

* merge with the dataset without duplication - age at claim;
proc sql; 
	create table input.id_index as
 	select a.*, b.patient_birth_year
    from input.id_index as a
	left join id_age as b
 	on a.patient_id = b.patient_id;
quit;
data input.id_index; set input.id_index;  age_at_index = year - patient_birth_year; run;
proc means data=input.id_index n nmiss mean std min max; var age_at_index; run; /* missing N = 34,365 among 1,262,977 */


* include individuals who aged < 18 at their index date ; 
proc sql;
	create table input.glp1_users_long_v1 as
	select *
	from input.glp1_users_long_v0 as a
	where a.patient_id in (
		select patient_id
		from input.id_index
		where age_at_index < 18 and not missing(age_at_index)
	);
quit; /* 60775 claims */

* distinct number of patients (N=2760);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.glp1_users_long_v1;
quit;

* keep age_at_index in the long data; 
proc sql; 
	create table input.glp1_users_long_v1 as
 	select a.*, b.age_at_index
    from input.glp1_users_long_v1 as a
	left join input.id_index as b
 	on a.patient_id = b.patient_id;
quit;

/************************************************************************************
	4. 
************************************************************************************/


