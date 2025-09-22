

/*============================================================*
 | 1) start with the first claim data
 *============================================================*/
/* Sort by patient → earliest svc_dt → prefer paid on that date */
data rx18_24_glp1_long_v01;
    set input.rx18_24_glp1_long_v01;
    if encnt_outcm_cd = "PD" then paid_priority = 1;   /* 1 if encnt_outcm_cd = "PD", else 0 */
    else paid_priority = 0;
run;
proc sort data=rx18_24_glp1_long_v01; by patient_id svc_dt descending paid_priority; run;

/* pool claim level data at patient level */
data input.patients_v0; 
  set rx18_24_glp1_long_v01;       
  by patient_id;
  length first_glp1 after_glp1 first_plan_type after_plan_type first_plan_name after_plan_name first_model_type after_model_type first_npi first_provider_id $50;
  retain first_glp1 after_glp1 first_plan_type after_plan_type glp1_switcher plan_switcher claim_count reject_count reversed_count glp1_switch_count plan_switch_count
    first_plan_name after_plan_name first_model_type after_model_type first_date last_date glp1_switch_date plan_switch_date total_oop total_days_to_adjudct_cnt first_npi first_provider_id first_provider_zip;
  format first_date last_date glp1_switch_date plan_switch_date yymmdd10.;
  if first.patient_id then do;
        first_glp1 = molecule_name;
        after_glp1 = molecule_name;
        first_plan_type = plan_type;
        after_plan_type = plan_type;
        first_plan_name = plan_name;
        after_plan_name = plan_name;
        first_model_type = model_type;
        after_model_type = model_type;
        glp1_switcher = 0;
        glp1_switch_date = .;
        plan_switcher = 0;
        plan_switch_date = .;
		glp1_switch_count = 0;
        plan_switch_count = 0;
        claim_count = 0;
        reject_count = 0;
		reversed_count = 0;
        total_oop = 0;
        total_days_to_adjudct_cnt	=0;
        first_npi = npi;
        first_provider_id = provider_id;
        first_provider_zip = provider_zip;
        first_date = svc_dt;
    end;

    claim_count + 1;
    total_days_to_adjudct_cnt + days_to_adjudct_cnt;
    if rjct_grp ne 0 then reject_count + 1;
	if encnt_outcm_cd = "RV" then reversed_count + 1;
    if encnt_outcm_cd = "PD" then total_oop + final_opc_amt;

  	if molecule_name ne after_glp1 then do;
        glp1_switch_count + 1;  /* count all switches */
        if glp1_switcher = 0 then do;  /* record first switch only */
            glp1_switch_date = svc_dt;
            glp1_switcher = 1;
        end;
 	end;
    after_glp1 = molecule_name;

    if plan_type ne after_plan_type then do;
        plan_switch_count + 1;  /* count all switches */
        if plan_switcher = 0 then do;  /* record first switch only */
            plan_switch_date = svc_dt;
            plan_switcher = 1;
        end;
  	end;
    after_plan_type = plan_type;
    after_plan_name = plan_name;
    after_model_type = model_type;
    
    last_date = svc_dt;

    if last.patient_id then output;
run;

data input.patients_v0; set input.patients_v0; 
keep patient_id first_glp1 after_glp1 first_plan_type after_plan_type glp1_switcher plan_switcher claim_count reject_count reversed_count glp1_switch_count plan_switch_count
    first_plan_name after_plan_name first_model_type after_model_type first_date last_date glp1_switch_date plan_switch_date total_oop total_days_to_adjudct_cnt first_npi first_provider_id first_provider_zip;
run; /* 951,434 obs */

data input.patients_v0; set input.patients_v0; 
paid_count = claim_count - reject_count - reversed_count;
if claim_count > 0 then pct_fill = paid_count / claim_count;
else pct_fill = .;
run;

data year; set input.rx18_24_glp1_long_v01; year = year(svc_dt); run;
proc means data=year n nmiss min max mean std; var year; run;

proc print data=input.patients_v0 (obs=30); where paid_count = 0; run; /* one patient (30219224134) -> (-) */
data nonfill; set input.patients_v0; if paid_count = 0; run; /* 124,013 */ 

proc contents data=input.patients_v0; run;



/*============================================================*
 | 2) merge with patients's demograph and characteristics
 *============================================================*/
 * make group; 
 data input.patients_v0;
    set input.patients_v0;
    length group $50;
    if first_plan_type in ("Medicaid FFS", "Medicaid MCO") then group = "Medicaid";
    else if first_plan_type in ("Medicare ADV", "Medicare TM") then group = "Medicare Part D";
    else if first_plan_type in ("Coupon/Voucher", "Other", "Discount Card") then group = "Others";
    else group = first_plan_type; 
run;
 
/*****************************
*  Gender
*****************************/
proc sql; 
	create table patients_v0 as
 	select distinct a.*, b.patient_gender
    from input.patients_v0 as a
	left join biosim.patient as b
 	on a.patient_id = b.patient_id;
quit; /* 959,538 >> 951,434 obs */

* see the duplicated patient_id rows;
/* 1) Find patients that have BOTH F and M recorded */
proc sql;
    create table gender_conflict as
    select patient_id,
           /* has_f = 1 if any F; has_m = 1 if any M */
           (sum(upcase(coalesce(patient_gender, '')) = 'F') > 0) as has_f,
           (sum(upcase(coalesce(patient_gender, '')) = 'M') > 0) as has_m
    from patients_v0
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
    create table patients_v1 as
    select a.*,
           case when b.invalid_gender = 1 then 'invalid'
                else a.patient_gender
           end as patient_gender_clean
    from patients_v0 as a
    left join gender_conflict as b
      on a.patient_id = b.patient_id
    ;
quit; 
proc sort data=patients_v1 nodupkey; by patient_id; run;
data input.patients_v0; set patients_v1 (drop=patient_gender); rename patient_gender_clean = patient_gender; run; /* 951,434 obs */

* test : 
proc freq data=input.patients_v0; table patient_gender; run;
proc freq data=input.patients_v0; table patient_gender*group; run;

/*****************************
*  States & region based on zip codes
*****************************/
data input.patients_v0;
    set input.patients_v0;

    length state $2 region $10;
    zip = put(first_provider_zip, z5.);
    state = zipstate(zip);

    /* Map state to region */
    select (state);
      when ('ME','NH','VT','MA','RI','CT','NY','NJ','PA') region='Northeast';
      when ('OH','IN','IL','MI','WI','MN','IA','MO','ND','SD','NE','KS') region='Midwest';
      when ('DE','MD','DC','VA','WV','NC','SC','GA','FL','KY','TN','AL','MS','AR','LA','OK','TX') region='South';
      when ('MT','ID','WY','CO','NM','AZ','UT','NV','WA','OR','CA','AK','HI') region='West';
      otherwise region='Unknown';
    end;
run; /* 951,434 obs */

proc freq data=input.patients_v0; table region; run;
proc freq data=input.patients_v0; table region*group /norow nopercent; run;

/*****************************
*  Age at initiation;
*****************************/
* set year_init; 
data patient_age; set input.first_claim; year_init = year(svc_dt); run;

proc sql; 
	create table id_age as
 	select distinct a.patient_id, a.year_init, b.patient_birth_year
    from patient_age as a
	left join biosim.patient as b
 	on a.patient_id = b.patient_id;
 quit;

* to resolve conflicts when a patient_id has two different patient_birth_year values (0 and 1998), and want to keep only the valid one;
proc sql;
    create table id_age as
    select patient_id, year_init,
           max(patient_birth_year) as patient_birth_year
    from id_age
    group by patient_id;
quit;  /* 960,673 >> 951,434 obs */

* but, there is still invalid value (9082 obs) where patient_birth_year = 0 -> let's make them null later; 
data what; set id_age; if patient_birth_year = 0; run;

* calculate age at initiation and make invalid data null;
data id_age; set id_age;  age_at_init = year_init - patient_birth_year; run;
data id_age; set id_age;  if patient_birth_year=0 then age_at_init = .; run;
proc sort data=id_age nodupkey; by patient_id; run; /* 951,434 obs */

* merge with the input.patients_v0;
proc sql; 
	create table input.patients_v0 as
 	select distinct a.*, b.age_at_init
    from input.patients_v0 as a
	left join id_age as b
 	on a.patient_id = b.patient_id;
 quit; /* 951,434 obs */

* test : 
proc means data=input.patients_v0 n nmiss median q1 q3 min max; var age_at_init; run;
proc means data=input.patients_v0 n nmiss median q1 q3 min max;
    class group;
    var age_at_init;
run;

/*****************************
* other variables | claim_count, reject_count, total_oop, total_days_to_adjudct_cnt
*****************************/
proc print data=input.patients_v0 (obs=10); run;

proc means data=input.patients_v0 n nmiss median q1 q3 min max; var total_days_to_adjudct_cnt;
proc means data=input.patients_v0 n nmiss median q1 q3 min max;
    class group;
    var total_days_to_adjudct_cnt;
run;


proc freq data=input.patients_v0; table glp1_switcher; run;
proc freq data=input.patients_v0; table glp1_switcher*group; run;

proc freq data=input.patients_v0; table plan_switcher; run;
proc freq data=input.patients_v0; table plan_switcher*group; run;


proc print data=input.patients_v0 (obs=10); run;
