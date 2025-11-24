
input.rx_all_med; 
input.rx_diabetes_med; 


/*============================================================*
 | 1. list up anti-diabetics medications
 *============================================================*/
proc contents data=biosim.product; run;
proc print data=biosim.product; where index(lowcase(usc_3_description), "diabetes") > 0; run;

data diabetes_med; set biosim.product; keep usc_3 usc_3_description usc_5 usc_5_description molecule_name product_ndc; if index(lowcase(usc_3_description), "diabetes") > 0; run;
data input.diabetes_med; set diabetes_med; retain usc_3 usc_3_description usc_5 usc_5_description molecule_name product_ndc; run;
proc sort data=input.diabetes_med nodupkey; by usc_3 usc_5 molecule_name; run;
data input.diabetes_med; set input.diabetes_med; if usc_3 in ('39100', '39200', '39300'); run;
data input.diabetes_med; set input.diabetes_med; if usc_5 in ('39110','39121','39122','39123','39124','39131','39133','39134','39135','39210','39221','39222','39231','39233','39241',
'39252','39261','39262','39269','39271','39272','39281','39290','39311','39312','39313','39319'); run;

proc print data=input.diabetes_med; run;


/*============================================================*
 | 2. merge with all medication history
 *============================================================*/
* id with start_date;
proc sort data=input.rx18_24_glp1_long_v00; by patient_id svc_dt; run;
data id; set input.rx18_24_glp1_long_v00; keep patient_id svc_dt; run;
data id; set id; by patient_id svc_dt; if first.patient_id; run;
data input.id; set id; rename svc_dt = start_date; run;

* merge with the original dataset;
%macro yearly(year=, refer=);
proc sql; 
  create table rx_&year._diabetes_med as
  select distinct a.*, b.svc_dt, b.ndc, b.rjct_cd
  from input.id as a 
  left join &refer as b
  on a.patient_id = b.patient_id;
quit;

%mend yearly;
%yearly(year=24, refer=biosim.rxfact2024);
%yearly(year=23, refer=biosim.rxfact2024);
%yearly(year=22, refer=biosim.rxfact2022);
%yearly(year=21, refer=biosim.rxfact2022);
%yearly(year=20, refer=biosim.rxfact2020);
%yearly(year=19, refer=biosim.rxfact2020);
%yearly(year=18, refer=biosim.rxfact2018);
%yearly(year=17, refer=biosim.rxfact2018);

data input.rx_all_med; set rx_24_diabetes_med rx_23_diabetes_med rx_22_diabetes_med rx_21_diabetes_med rx_20_diabetes_med rx_19_diabetes_med rx_18_diabetes_med; run;
proc sort data=input.rx_all_med nodupkey; by patient_id svc_dt; run; /* 177,470,368 obs */

* merge with molecule_name, usc_3, 5; 
proc sql; 
  create table input.rx_all_med as
  select distinct a.*, b.molecule_name, b.usc_3, b.usc_3_description, b.usc_5, b.usc_5_description
  from input.rx_all_med as a 
  left join biosim.product as b
  on a.ndc = b.product_ndc;
quit; /* 177,470,368 obs */

/*
data input.rx_all_med; set input.rx_all_med_v1; run;
proc datasets library=input nolist; delete rx_all_med_v1; quit;
*/

/*============================================================*
 | 3. remain claims for anti-diabetes medications
 *============================================================*/
* using usc 3 level to form anti-diabetes medications;
data rx_diabetes_med; set input.rx_all_med; if usc_3 in ('39100', '39200', '39300'); run; /* 39,091,900 */

* exclude GLP1s;
data input.rx_diabetes_med; set rx_diabetes_med; if usc_5 in ('39110','39121','39122','39123','39124','39131','39133','39134','39135','39210','39221','39222','39231','39233','39241',
'39252','39261','39262','39269','39271','39272','39281','39290','39311','39312','39313','39319'); run; /* 25,020,725 */ 

proc sort data=input.rx_diabetes_med; by patient_id svc_dt; run;


/*============================================================*
 | 4. within (-180, 0) days - identify patients who had at least one paid claims for anti-diabetes medications
 *============================================================*/
* remain only paid claims;
data input.rx_diabetes_med_v1; set input.rx_diabetes_med; if rjct_cd in ('','00','000'); run; /* 22,200,492 obs */ 

* remain (-180 days, index date + 180 days); 
data input.rx_diabetes_med_v1; set input.rx_diabetes_med_v1; if svc_dt > (start_date - 180) and svc_dt <= (start_date + 180); run; /* 3,929,045 obs */ 

* identify individuals who had anti-diabetics medication history;
data input.rx_diabetes_med_v1; 
   set input.rx_diabetes_med_v1; 
   by patient_id;
   retain count;
   if first.patient_id then count = 0;
   count +1; 
   if last.patient_id then output;
run;
data input.rx_diabetes_med_v1;  set input.rx_diabetes_med_v1;  diabetes_history = 1; run; /* 517,964 obs */ 
proc means data=input.rx_diabetes_med_v1 n nmiss mean std min max median q1 q3; var count; run;


/*============================================================*
 | 5. merge with the cohort dataset;
 *============================================================*/
/*
input.rx18_24_glp1_long_v00
input.rx18_24_glp1_long_v01
input.patients_v0
input.patients_v1
*/
data input.patients_v1; set input.patients_v1; drop diabetes_history; run;
data input.patients_v0; set input.patients_v0; drop diabetes_history; run;
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; drop diabetes_history; run;
data input.rx18_24_glp1_long_v01; set input.rx18_24_glp1_long_v01; drop diabetes_history; run;

proc sql; 
  create table input.patients_v0 as
  select distinct a.*, b.diabetes_history
  from input.patients_v0 as a 
  left join input.rx_diabetes_med_v1 as b
  on a.patient_id = b.patient_id;
quit;
data input.patients_v0; set input.patients_v0; if missing(diabetes_history) then diabetes_history =0; run;

proc sql; 
  create table input.patients_v1 as
  select distinct a.*, b.diabetes_history
  from input.patients_v1 as a 
  left join input.rx_diabetes_med_v1 as b
  on a.patient_id = b.patient_id;
quit;
data input.patients_v1; set input.patients_v1; if missing(diabetes_history) then diabetes_history =0; run;


proc sql; 
  create table input.rx18_24_glp1_long_v00 as
  select distinct a.*, b.diabetes_history
  from input.rx18_24_glp1_long_v00 as a 
  left join input.rx_diabetes_med_v1 as b
  on a.patient_id = b.patient_id;
quit;
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if missing(diabetes_history) then diabetes_history =0; run;

proc sql; 
  create table input.rx18_24_glp1_long_v01 as
  select distinct a.*, b.diabetes_history
  from input.rx18_24_glp1_long_v01 as a 
  left join input.rx_diabetes_med_v1 as b
  on a.patient_id = b.patient_id;
quit;
data input.rx18_24_glp1_long_v01; set input.rx18_24_glp1_long_v01; if missing(diabetes_history) then diabetes_history =0; run;

proc freq data=input.rx18_24_glp1_long_v00; table diabetes_history; run;


proc sql; 
  create table input.secondary_cohort_wide as
  select distinct a.*, b.diabetes_history
  from input.secondary_cohort_wide as a 
  left join input.rx_diabetes_med_v1 as b
  on a.patient_id = b.patient_id;
quit;
data input.secondary_cohort_wide; set input.secondary_cohort_wide; if missing(diabetes_history) then diabetes_history =0; run;


