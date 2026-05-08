

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

data input.glp1_users_long; set minji.rx_25_glp1 minji.rx_24_glp1 minji.rx_23_glp1 minji.rx_22_glp1 minji.rx_21_glp1 minji.rx_20_glp1 minji.rx_19_glp1 minji.rx_18_glp1 minji.rx_17_glp1; run; 


/************************************************************************************
	2. all GLP1 users claims in long form (Jan 17 - Sep 25)
************************************************************************************/

* clean the patient_birth_year;
proc sql;
    create table id_age as
    select distinct patient_id, max(patient_birth_year) as patient_birth_year
    from biosim.patient
    group by patient_id;
quit; /* 12170856 obs */

* merge with the dataset without duplication;
proc sql; 
	create table input.rx17_25_glp1_long as
 	select a.*, b.patient_birth_year
    from input.rx17_25_glp1_long as a
	left join id_age as b
 	on a.patient_id = b.patient_id;
quit;
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long;  age_at_claim = year - patient_birth_year; run;

proc sql; 
	create table input.id_index as
 	select a.*, b.patient_birth_year
    from input.id_index as a
	left join id_age as b
 	on a.patient_id = b.patient_id;
quit;
data input.id_index; set input.id_index;  age_at_index = year - patient_birth_year; run;

* exclude individuals who aged < 18 at their index date ; 
proc sql;
	create table input.rx17_25_glp1_long as
	select *
	from input.rx17_25_glp1_long as a
	where a.patient_id in (
		select patient_id
		from input.id_index
		where age_at_index >= 18
	);
quit; /* 19865806 claims */

* distinct number of patients (N=938,371);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx17_25_glp1_long;
quit;


/************************************************************************************
	3. 
************************************************************************************/


