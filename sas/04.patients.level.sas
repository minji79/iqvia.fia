/************************************************************************************
	1. distinct patients - biosimilar users (N = 39457)
************************************************************************************/
data input.adalimumab_claim_v0; set input.adalimumab_claim_v0; year = year(svc_dt); run;
proc sql;
    create table counts as
    select count(distinct patient_id) as count, year
    from input.adalimumab_claim_v0
	group by year;
quit;
proc print data=counts; run;

/* biosimilar users 1378 for 2024 */
data adalimumab_claim_v0; set input.adalimumab_claim_v0; if category ne "reference_biologics"; run;
proc sql;
    create table counts as
    select count(distinct patient_id) as count, year
    from adalimumab_claim_v0
	group by year;
quit;
proc print data=counts; run;

/************************************************************************************
	2. categorize patients to patient_group : (1) biosimilar_initiator, and (2) switcher (N = 39457)
************************************************************************************/
/*
patient_group
Group 1: reference_lover
Group 2: switcher_to_biosim
Group 3: biosim_lover
Group 4: switcher_to_reference
*/


* sort by patient_id svc_dt; 
proc sort data=input.adalimumab_claim_v0; by patient_id svc_dt; run;

data input.adalimumab_patient_v0;
    set input.adalimumab_claim_v0;
    by patient_id;

    length first_cat $50 switch_date 8;
    retain first_cat switcher biosim_initiator switch_date claim_count first_date last_date prev_cat;

    format first_date last_date switch_date yymmdd10.;

    if first.patient_id then do;
        first_cat = category;
        prev_cat = category;
        switcher = 0;
        biosim_initiator = 0;
        switch_date = .;
        claim_count = 0;

        first_date = svc_dt;
        if first_cat ne "reference_biologics" then biosim_initiator = 1;
    end;

    claim_count + 1;

    /* detect first switch in category */
    if category ne prev_cat and switcher = 0 then do;
        switch_date = svc_dt;
        switcher = 1;
    end;

    prev_cat = category;  /* update for next row comparison */
    last_date = svc_dt;

    if last.patient_id then output;
run;

data input.adalimumab_patient_v0; set input.adalimumab_patient_v0;
	length patient_group $100;
 	retain patient_group;
	if biosim_initiator = 0 and switcher = 0 then patient_group = "reference_lover"; 
 	else if biosim_initiator = 0 and switcher = 1 then patient_group = "switcher_to_biosim"; 
  	else if biosim_initiator = 1 and switcher = 0 then patient_group = "biosim_lover"; 
   	else if biosim_initiator = 1 and switcher = 1 then patient_group = "switcher_to_reference"; 
	else patient_group = "none"; 
run;
proc freq data=input.adalimumab_patient_v0; table patient_group; run;

* test;
proc print data=input.adalimumab_patient_v0 (obs=20); var patient_id first_date last_date claim_count switch_date first_cat biosim_initiator switcher; where switcher = 1; run;
proc print data=adalimumab_patient_v0 (obs=20); run;
proc contents data=input.adalimumab_patient_v0; run;

proc freq data=input.adalimumab_patient_v0; table biosim_initiator*switcher; run;
proc print data=input.adalimumab_claim_v0 (obs=20); var patient_id svc_dt molecule_name category; where patient_id = 1237730811; run;


/************************************************************************************
	3. patients's demograph and characteristics
************************************************************************************/

/*****************************
*  Gender
*****************************/

proc sql; 
	create table input.adalimumab_patient_v0 as
 	select distinct a.*, b.patient_gender
    from input.adalimumab_patient_v0 as a
	left join input.patient as b
 	on a.patient_id = b.patient_id;
 quit;

* see the duplicated patient_id rows;
/* 1) Find patients that have BOTH F and M recorded */
proc sql;
    create table gender_conflict as
    select patient_id,
           /* has_f = 1 if any F; has_m = 1 if any M */
           (sum(upcase(coalesce(patient_gender, '')) = 'F') > 0) as has_f,
           (sum(upcase(coalesce(patient_gender, '')) = 'M') > 0) as has_m
    from input.adalimumab_patient_v0
    group by patient_id
    ;
quit;

data gender_conflict;
    set gender_conflict;
    invalid_gender = (has_f = 1 and has_m = 1);
    keep patient_id invalid_gender;
run;

/* 2) Join back and set 'invalid' where needed */
proc sql;
    create table input.adalimumab_patient_v0 as
    select a.*,
           case when b.invalid_gender = 1 then 'invalid'
                else a.patient_gender
           end as patient_gender_clean
    from input.adalimumab_patient_v0 as a
    left join gender_conflict as b
      on a.patient_id = b.patient_id
    ;
quit;
proc sort data=input.adalimumab_patient_v0 nodupkey; by patient_id; run;

* test : 
proc freq data=input.adalimumab_patient_v0; table patient_gender; run;
proc freq data=input.adalimumab_patient_v0; table patient_gender*patient_group; run;


* test for duplication; 
proc sql;
    create table df_multi as
    select a.*
    from adalimumab_patient_v0 as a
    inner join (
        select patient_id
        from adalimumab_patient_v0
        group by patient_id
        having count(*) > 1
    ) as b
    on a.patient_id = b.patient_id;
quit;
proc print data=df_multi (obs=20); run;


/*****************************
*  Age at initiation;
*****************************/
* set year_init; 
data adalimumab_patient_v0; set input.adalimumab_patient_v0; year_init = year(svc_dt); run;

* merge with patient file -> get year of birth;
proc sql; 
	create table id_age as
 	select distinct a.*, b.patient_birth_year
    from input.adalimumab_patient_v0 as a
	left join input.patient as b
 	on a.patient_id = b.patient_id;
 quit;

* to resolve conflicts when a patient_id has two different patient_birth_year values (0 and 1998), and want to keep only the valid one;
proc sql;
    create table id_age as
    select patient_id, 
           max(patient_birth_year) as patient_birth_year
    from id_age
    group by patient_id;
quit;

* merge with the adalimumab_patient_v0; 
proc sql; 
	create table adalimumab_patient_v0 as
 	select distinct a.*, b.patient_birth_year
    from input.adalimumab_patient_v0 as a
	left join id_age as b
 	on a.patient_id = b.patient_id;
 quit;

* but, there is still invalid value (416 obs) where patient_birth_year = 0 -> let's make them null later; 
data what; set adalimumab_patient_v0; if patient_birth_year = 0; run;

* calculate age at initiation and make invalid data null;
data adalimumab_patient_v1;
    set adalimumab_patient_v0;
    if patient_birth_year = 0 then age_at_init = .;
    else age_at_init = year_init - patient_birth_year;
run;

* test : 
proc means data=adalimumab_patient_v1; var age_at_init; run;
proc freq data=adalimumab_patient_v0; table age_at_init; run;
proc freq data=adalimumab_patient_v0; table age_at_init*patient_group; run;




proc sql;
  create table work.index_final2 as
  select a.*, b.count_generics, b.count_brands, b.count_ts
  from work.index_final a
  left join work.by_moly b
    on a.molecule_name=b.molecule_name and a.year=b.year;
quit;


data input.adalimumab_patient_plan_v0; set input.adalimumab_claim_v0; patient_id year 

proc contents data=input.adalimumab_claim_v0; run;












