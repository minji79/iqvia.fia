
 /*============================================================*
 | 1. aggregate long data at patient level
 *============================================================*/ 
proc sort data=plan.hopkins_users; by patient_id svc_dt; run;
data plan.hopkins_users; set plan.hopkins_users; if encnt_outcm_cd = "PD" then oop_30day = final_opc_amt / days_supply_cnt * 30; else oop_30day =.; run;

data plan.hopkins_users_wide;
  set plan.hopkins_users;
  by patient_id;
  format last_date yymmdd10.;
  if first.patient_id then do;
	claim_count =0;
  PD_count =0;
  RJ_count =0;
  RV_count =0;
	coupon_count =0;
  hopkins_npi_count =0;
	cumulative_oop = 0;
  end;
  
  claim_count + 1;

  if coupon =1 then coupon_count +1;
  if encnt_outcm_cd = "PD" then do; 
  PD_count +1; 
  cumulative_oop + final_opc_amt;
  end;
  if encnt_outcm_cd = "RV" then RV_count +1; 
  if encnt_outcm_cd = "RJ" then RJ_count +1;
  if hopkins_npi =1 then hopkins_npi_count +1;
  
  if last.patient_id then do;
  last_date = svc_dt;
  output;
  end;
run;
data plan.hopkins_users_wide; set plan.hopkins_users_wide; keep patient_id claim_count PD_count RJ_count RV_count coupon_count hopkins_npi_count cumulative_oop last_date; run;
data plan.hopkins_users_wide; set plan.hopkins_users_wide; if coupon_count > 0 then coupon_user = 1; else coupon_user =0; run;
data plan.hopkins_users_wide; set plan.hopkins_users_wide; 
  PD_pct = PD_count / claim_count * 100; 
  RJ_pct = RJ_count / claim_count * 100; 
  RV_pct = RV_count / claim_count * 100; 
  Hopkins_pct = hopkins_npi_count / claim_count * 100;   
  oop_per_claim =  cumulative_oop / PD_count * 100;   
 
run;


 /*============================================================*
 | 2. at first claim
 *============================================================*/ 
proc sort data=plan.hopkins_users; by patient_id svc_dt; run;
data firstclaims; set plan.hopkins_users; by patient_id; if first.patient_id; run;
proc contents data=firstclaims; run;

proc sql;
  create table plan.hopkins_users_wide as
  select a.*, b.svc_dt as first_date
  from plan.hopkins_users_wide as a
  left join firstclaims as b
    on a.patient_id = b.patient_id;
quit;

/* gap between first date to last date */
data plan.hopkins_users_wide; set plan.hopkins_users_wide; duration = last_date - first_date; run;
data plan.hopkins_users_wide; set plan.hopkins_users_wide; first_year = year(first_date); run;


/*============================================================*
 | 3. demograph variable 
 *============================================================*/ 
/* age */
proc sql;
    create table id_age as
    select distinct patient_id, max(patient_birth_year) as patient_birth_year
    from biosim.patient
    group by patient_id;
quit; /* 12170856 obs */

proc sql; 
	create table plan.hopkins_users_wide as
 	select a.*, b.patient_birth_year
    from plan.hopkins_users_wide as a
	left join id_age as b
 	on a.patient_id = b.patient_id;
 quit;

* calculate age at initiation and make invalid data null;
data plan.hopkins_users_wide; set plan.hopkins_users_wide;  age_at_claim = first_year - patient_birth_year; run;


/* gender */
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
	create table plan.hopkins_users_wide as
 	select distinct a.*, b.patient_gender
    from plan.hopkins_users_wide as a
	left join gender as b
 	on a.patient_id = b.patient_id;
quit;


/* region */
proc sort data=plan.hopkins_users; by patient_id svc_dt; run;
data firstclaims; set plan.hopkins_users; by patient_id; if first.patient_id; run;

data firstclaims;
    set firstclaims;

    length state $2 region $10;
    zip = put(provider_zip_code, z5.);
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

proc sql; 
	create table plan.hopkins_users_wide as
 	select a.*, b.state, b.region
    from plan.hopkins_users_wide as a
	left join firstclaims as b
 	on a.patient_id = b.patient_id;
 quit;


/*============================================================*
 | 4. glp1 users
 *============================================================*/ 
data glp1users; set plan.hopkins_users; if glp1=1; run;
proc sort data=glp1users; by patient_id svc_dt; run;
data glp1users; set glp1users; by patient_id; if first.patient_id; run;

proc sql; 
	create table plan.hopkins_users_wide as
 	select a.*, b.glp1, b.molecule_name as index_glp1
    from plan.hopkins_users_wide as a
	left join glp1users as b
 	on a.patient_id = b.patient_id;
 quit;
data plan.hopkins_users_wide; set plan.hopkins_users_wide; if missing(glp1) then glp1 =0; run;


proc freq data=plan.hopkins_users_wide; table index_glp1; run;
proc print data=plan.hopkins_users_wide (obs=10); run;

/*============================================================*
 | 5. table 1
 *============================================================*/ 

* age at the index claim;
proc means data=plan.hopkins_users_wide n nmiss median q1 q3 min max; var age_at_claim; run;
proc means data=plan.hopkins_users_wide n nmiss median q1 q3 min max;
    class glp1;
    var age_at_claim;
run;

* gender ; 
proc freq data=plan.hopkins_users_wide; table patient_gender; run;
proc freq data=plan.hopkins_users_wide; table patient_gender*glp1 /norow nopercent; run;

* region ; 
proc freq data=plan.hopkins_users_wide; table region; run;
proc freq data=plan.hopkins_users_wide; table region*glp1 /norow nopercent; run;

* duration of episode; 
data plan.hopkins_users_wide; set plan.hopkins_users_wide; duration_month = duration / 30; run;
proc means data=plan.hopkins_users_wide n nmiss median q1 q3 min max; var duration_month; run;
proc means data=plan.hopkins_users_wide n nmiss median q1 q3 min max;
    class glp1;
    var duration_month;
run;

* claim_count ;
proc means data=plan.hopkins_users_wide n nmiss median q1 q3 min max; var claim_count; run;
proc means data=plan.hopkins_users_wide n nmiss median q1 q3 min max;
    class glp1;
    var claim_count;
run;

* claim_count - PD_count ;
proc means data=plan.hopkins_users_wide n nmiss mean std; var PD_pct; run;
proc means data=plan.hopkins_users_wide n nmiss mean std;
    class glp1;
    var PD_pct;
run;

* claim_count - RJ_count ;
proc means data=plan.hopkins_users_wide n nmiss mean std; var RJ_pct; run;
proc means data=plan.hopkins_users_wide n nmiss mean std;
    class glp1;
    var RJ_pct;
run;

* claim_count - RV_count ;
proc means data=plan.hopkins_users_wide n nmiss mean std; var RV_pct; run;
proc means data=plan.hopkins_users_wide n nmiss mean std;
    class glp1;
    var RV_pct;
run;

* claim_count - Hopkins_pct ;
proc means data=plan.hopkins_users_wide n nmiss mean std; var Hopkins_pct; run;
proc means data=plan.hopkins_users_wide n nmiss mean std;
    class glp1;
    var Hopkins_pct;
run;

* coupon ever users ;
proc freq data=plan.hopkins_users_wide; table coupon_user; run;
proc freq data=plan.hopkins_users_wide; table coupon_user*glp1 /norow nopercent; run;

* oop_per_claim ;
proc means data=plan.hopkins_users_wide n nmiss median q1 q3; var oop_per_claim; run;
proc means data=plan.hopkins_users_wide n nmiss median q1 q3;
    class glp1;
    var oop_per_claim;
run;

* index year ; 
proc freq data=plan.hopkins_users_wide; table first_year; run;
proc freq data=plan.hopkins_users_wide; table first_year*glp1 /norow nopercent; run;

* index_glp1;
proc freq data=plan.hopkins_users_wide; table index_glp1; run;

