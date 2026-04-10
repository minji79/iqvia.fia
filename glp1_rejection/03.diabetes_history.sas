
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
data id; set input.id_index; keep patient_id index_date; run;

* merge with the original dataset;
%macro yearly(year=, refer=);
proc sql; 
  create table rx_&year._diabetes_med as
  select distinct a.*, b.svc_dt, b.ndc, b.rjct_cd
  from id as a 
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
proc sort data=input.rx_all_med nodupkey; by patient_id svc_dt; run;

* merge with molecule_name, usc_3, 5; 
proc sql; 
  create table input.rx_all_med as
  select distinct a.*, b.molecule_name, b.usc_3, b.usc_3_description, b.usc_5, b.usc_5_description
  from input.rx_all_med as a 
  left join biosim.product as b
  on a.ndc = b.product_ndc;
quit; 

/*============================================================*
 | 3. remain claims for anti-diabetes medications
 *============================================================*/
* using usc 3 level to form anti-diabetes medications;
data rx_diabetes_med; set input.rx_all_med; if usc_3 in ('39100', '39200', '39300'); run; /* 39,091,900 */

* exclude GLP1s + should include other GLP1s;
data input.rx_diabetes_med; set rx_diabetes_med; if usc_5 in ('39110','39121','39122','39123','39124','39131','39133','39134','39135','39210','39221','39222','39231','39233','39241',
'39252','39261','39262','39269','39271','39272','39281','39290','39311','39312','39313','39319'); run; /* 25,020,725 */ 


/*============================================================*
 | 4. within (-180, 0) days - identify patients who had at least one paid claims for anti-diabetes medications
 *============================================================*/

/* non-GLP1 diabetes_history | diabetes_history_nonglp1 */
* remain only paid claims;
data input.rx_diabetes_med_v1; set input.rx_diabetes_med; if rjct_cd in ('','00','000'); run; 

* remain (-180 days, index date + 180 days); 
data input.rx_diabetes_med_v1; set input.rx_diabetes_med_v1; if svc_dt > (index_rx_dt - 180) and svc_dt <= (index_rx_dt + 180); run;

* identify individuals who had anti-diabetics medication history;
data input.rx_diabetes_med_v1; 
   set input.rx_diabetes_med_v1; 
   by patient_id;
   retain count;
   if first.patient_id then count = 0;
   count +1; 
   if last.patient_id then output;
run;
data input.rx_diabetes_med_v1;  set input.rx_diabetes_med_v1;  diabetes_history_nonglp1 = 1; run; /* 423541 obs */ 
proc means data=input.rx_diabetes_med_v1 n nmiss mean std min max median q1 q3; var count; run;


/* other GLP1s diabetes_history | diabetes_history_glp1 */
* remain only paid claims;
data rx17_25_other_glp1_long; set input.rx17_25_other_glp1_long; if rjct_cd in ('','00','000'); run;
proc sort data=rx17_25_other_glp1_long; by patient_id svc_dt; run;

proc print data=rx17_25_other_glp1_long (obs=10); run;

proc sql; 
  create table rx_diabetes_glp1 as
  select distinct a.patient_id, a.svc_dt as svc_dt_glp1, b.index_rx_dt
  from rx17_25_other_glp1_long as a 
  left join input.id_index as b
  on a.patient_id = b.patient_id;
quit; 
data rx_diabetes_glp1; set rx_diabetes_glp1; if svc_dt_glp1 > (index_rx_dt - 180) and svc_dt_glp1 <= (index_rx_dt + 180); run;

* identify individuals who had anti-diabetics medication history;
proc sort data=rx_diabetes_glp1; by patient_id svc_dt; run;
data rx_diabetes_glp1_wide;
   set rx_diabetes_glp1;
   by patient_id;
   retain count;
   if first.patient_id then count = 0;
   count +1; 
   if last.patient_id then output;
run;
data rx_diabetes_glp1_wide;  set rx_diabetes_glp1_wide;  diabetes_history_glp1 = 1; run; /* 137682 obs */ 


/*============================================================*
 | 5. merge with the cohort dataset (input.id_index)
 *============================================================*/

/* diabetes_history_nonglp1 */
proc sql; 
  create table input.id_index as
  select distinct a.*, b.diabetes_history_nonglp1
  from input.id_index as a 
  left join input.rx_diabetes_med_v1 as b
  on a.patient_id = b.patient_id;
quit;
data input.id_index; set input.id_index; if missing(diabetes_history_nonglp1) then diabetes_history_nonglp1 =0; run;

/* diabetes_history_glp1 */
proc sql; 
  create table input.id_index as
  select distinct a.*, b.diabetes_history_glp1
  from input.id_index as a 
  left join rx_diabetes_glp1_wide as b
  on a.patient_id = b.patient_id;
quit;
data input.id_index; set input.id_index; if missing(diabetes_history_glp1) then diabetes_history_glp1 =0; run;

/* diabetes_history | including both */
data input.id_index; set input.id_index; if diabetes_history_glp1 =0 and diabetes_history_nonglp1 =0 then diabetes_history =0; else diabetes_history=1; run;
proc freq data=input.id_index; table diabetes_history; run;



/*============================================================*
 | 5. merge with the long dataset (input.rx17_25_glp1_long)
 *============================================================*/

/* diabetes_history_nonglp1 */
proc sql; 
  create table input.rx17_25_glp1_long as
  select distinct a.*, b.diabetes_history_nonglp1
  from input.rx17_25_glp1_long as a 
  left join input.rx_diabetes_med_v1 as b
  on a.patient_id = b.patient_id;
quit;
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long; if missing(diabetes_history_nonglp1) then diabetes_history_nonglp1 =0; run;

/* diabetes_history_glp1 */
proc sql; 
  create table input.rx17_25_glp1_long as
  select distinct a.*, b.diabetes_history_glp1
  from input.rx17_25_glp1_long as a 
  left join rx_diabetes_glp1_wide as b
  on a.patient_id = b.patient_id;
quit;
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long; if missing(diabetes_history_glp1) then diabetes_history_glp1 =0; run;

/* diabetes_history | including both */
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long; if diabetes_history_glp1 =0 and diabetes_history_nonglp1 =0 then diabetes_history =0; else diabetes_history=1; run;



