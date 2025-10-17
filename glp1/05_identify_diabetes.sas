
input.rx_all_med; 
input.rx_diabetes_med; 


/*============================================================*
 | 1. list up anti-diabetics medications
 *============================================================*/

 * form patient_id index_svc_dt
 * merge the 

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


/*============================================================*
 | 3. within (-180, 0) days - identify patients who had at least one paid claims for anti-diabetes medications
 *============================================================*/

* remain only diabetes med;
proc sql; 
  create table input.rx_diabetes_med as
  select distinct a.*, b.usc_5, b.usc_5_description, b.molecule_name
  from input.rx_all_med as a 
  inner join input.diabetes_med as b
  on a.ndc = b.product_ndc;
quit; /* 711333 obs */

proc sort data=input.rx_diabetes_med; by patient_id svc_dt; run;

* remain only paid claims;
data input.rx_diabetes_med; set input.rx_diabetes_med; if rjct_cd in ('','00','000'); run; /* 615124 obs */ 

* remain (-180 days, index date); 
data rx_diabetes_med; set input.rx_diabetes_med; if svc_dt > (start_date - 180) and svc_dt <= (start_date + 180); run;

proc print data=input.rx_diabetes_med (obs=10); run;
proc freq data=input.rx_diabetes_med; table usc_5_description; run;


data input.rx_diabetes_med; 
   set input.rx_diabetes_med; 
   by patient_id;
   retain count;
   if first.patient_id then count = 0;
   count +1; 
   if last.patient_id then output;
run;
data input.rx_diabetes_med; set input.rx_diabetes_med; diabetes_history = 1; run;

proc print data=input.rx_diabetes_med (obs=10); run;
proc means data=input.rx_diabetes_med n nmiss mean std min max median q1 q3; var count; run;



* merge with the cohort dataset;
/*
input.rx18_24_glp1_long_v00
input.rx18_24_glp1_long_v01
input.patients_v0
input.patients_v1
*/

proc sql; 
  create table patients_v0 as
  select distinct a.*, b.diabetes_history
  from input.patients_v0 as a 
  left join input.rx_diabetes_med as b
  on a.patient_id = b.patient_id;
quit;
data patients_v0; set patients_v0; if missing(diabetes_history) then diabetes_history =0; run;
proc freq data=patients_v0; table diabetes_history; run;





proc sql; 
  create table input.rx18_24_glp1_long_v00 as
  select distinct a.*, b.diabetes_history
  from input.rx18_24_glp1_long_v00 as a 
  left join input.rx_diabetes_med as b
  on a.patient_id = b.patient_id;
quit;
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if missing(diabetes_history) then diabetes_history =0; run;
proc freq data=input.rx18_24_glp1_long_v00; table diabetes_history; run;












