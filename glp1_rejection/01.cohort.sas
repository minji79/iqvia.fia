

/*============================================================*
 | 1. ONLY molecule_name in ("SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)"
 *============================================================*/
* for other GLP1s (6518707 claims); 
data input.rx17_25_other_glp1_long; set input.rx17_25_glp1_long; if molecule_name in ("DULAGLUTIDE", "EXENATIDE", "LIRAGLUTIDE", "LIRAGLUTIDE (WEIGHT MANAGEMENT)", "LIXISENATIDE"); run; 

* for GLP1s of interest (9664827 claims); /* 1008350 individuals */
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long; if molecule_name in ("SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)"); run;

/*============================================================*
 | 2. clean - remove invalid values
 *============================================================*/
 * exclude invalid data in molecule_name;
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long;  if not missing(molecule_name); run; /* none */
* exclude invalid data in encnt_outcm_cd;
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long;  if not missing(encnt_outcm_cd); run; /* -2270 claims */

/*============================================================*
 | 3. study period: 180 days wash out period | "30JUN2017"d < index_date < "30JUN2025"d 
 *============================================================*/

data input.id_index;
    set input.rx17_25_glp1_long;        
    if encnt_outcm_cd = "PD" then paid_priority = 2;  
    else if encnt_outcm_cd = "RV" then paid_priority = 1;  
    else paid_priority = 0;
run;
proc sort data=input.id_index; by patient_id svc_dt descending paid_priority;  run;

data input.id_index;
    set input.id_index;
    by patient_id svc_dt;
    if first.patient_id then output;
    drop paid_priority;
run; 

data input.id_index; set input.id_index (rename=(svc_dt=index_date)); run;

/* no GLP1 used for 180 days prior to the index date */
proc sql;
	create table input.rx17_25_glp1_long as
	select *
	from input.rx17_25_glp1_long as a
	where a.patient_id in (
		select patient_id
		from input.id_index
		where index_date > "30JUN2017"d
	);
quit;

/* to ensure everyone have 90 days follow-up days */
proc sql;
	create table input.rx17_25_glp1_long as
	select *
	from input.rx17_25_glp1_long as a
	where a.patient_id in (
		select patient_id
		from input.id_index
		where index_date < "30JUN2025"d
	);
quit; /* total claims number = 9553229 */

* distinct number of patients (N= 947450);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx17_25_glp1_long;
quit;

 /*============================================================*
 | 4. exclude claims with age < 18
 *============================================================*/

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
quit; /* 9460837 claims */

* distinct number of patients (N=925,056);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx17_25_glp1_long;
quit;


/*****************************
*  5. add States & region based on zip codes
*****************************/

data input.rx17_25_glp1_long;
    set input.rx17_25_glp1_long;

    length state $2 region $10;
    zip = put(provider_zip, z5.);
    state = zipstate(zip);

    /* Map state to region */
    select (state);
      when ('ME','NH','VT','MA','RI','CT','NY','NJ','PA') region='Northeast';
      when ('OH','IN','IL','MI','WI','MN','IA','MO','ND','SD','NE','KS') region='Midwest';
      when ('DE','MD','DC','VA','WV','NC','SC','GA','FL','KY','TN','AL','MS','AR','LA','OK','TX') region='South';
      when ('MT','ID','WY','CO','NM','AZ','UT','NV','WA','OR','CA','AK','HI') region='West';
      otherwise region='Unknown';
    end;
run;
proc freq data=input.rx17_25_glp1_long; table region; run;

/*****************************
*  6. add patients gender
*****************************/
/* 1) make patient - gender table without any duplication */
* clean the data;
data gender; set biosim.patient; keep patient_id patient_gender; run;
proc sort data=gender nodupkey; by patient_id; run; /* 12170856 obs */

* see the duplicated patient_id rows;
proc sql;
    create table gender_conflict as
    select patient_id,
           /* has_f = 1 if any F; has_m = 1 if any M */
           (sum(upcase(coalesce(patient_gender, '')) = 'F') > 0) as has_f,
           (sum(upcase(coalesce(patient_gender, '')) = 'M') > 0) as has_m
    from gender
    group by patient_id
    ;
quit;

data gender_conflict;
    set gender_conflict;
    invalid_gender = (has_f = 1 and has_m = 1);
    keep patient_id invalid_gender;
run;

proc sql;
    create table gender as
    select a.*,
           case when b.invalid_gender = 1 then 'invalid'
                else a.patient_gender
           end as patient_gender_clean
    from gender as a
    left join gender_conflict as b
      on a.patient_id = b.patient_id
    ;
quit; 
proc sort data=gender nodupkey; by patient_id; run;
data gender; set gender (drop=patient_gender); rename patient_gender_clean = patient_gender; run; /* 12170856 obs */


/* 2) merge with our dataset */
proc sql; 
	create table input.rx17_25_glp1_long as
 	select distinct a.*, b.patient_gender
    from input.rx17_25_glp1_long as a
	left join gender as b
 	on a.patient_id = b.patient_id;
quit; /* 10,999,619 obs*/

