
/*============================================================*
 |  update  study cohorts
 |   1. input.rx18_24_glp1_long_v00
 |   2. input.rx18_24_glp1_long_v01
 |   3. input.first_attempt
 *============================================================*/

/*============================================================*
 | excluded * null in encnt_outcm_cd; ( - 2110 obs)
 *============================================================*/
* null in encnt_outcm_cd;
proc freq data=input.rx18_24_glp1_long_v00; table encnt_outcm_cd; run;

data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if not missing(encnt_outcm_cd); run;

/*============================================================*
 | primary cohort (N=842027) with 7480791 claims
 *============================================================*/
/* excluded dula & exenatide from all claims */
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if molecule_name in ("LIRAGLUTIDE","LIRAGLUTIDE (WEIGHT MANAGEMENT)","SEMAGLUTIDE","SEMAGLUTIDE (WEIGHT MANAGEMENT)","TIRZEPATIDE","TIRZEPATIDE (WEIGHT MANAGEMENT)"); run;
   /* 7482901 obs */

* distinct number of patients (N= 842209);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v00;
quit;


proc sort data=input.rx18_24_glp1_long_v00; by patient_id svc_dt; run;

/* the first claim */
data first_attempt;
    set input.rx18_24_glp1_long_v00;        
    if encnt_outcm_cd = "PD" then paid_priority = 2;  
    else if encnt_outcm_cd = "RV" then paid_priority = 1;  
    else paid_priority = 0;
run;
proc sort data=first_attempt; by patient_id svc_dt descending paid_priority;  run;

data input.first_attempt;
    set first_attempt;
    by patient_id svc_dt;
    if first.patient_id then output;
    drop paid_priority;
run; /* 842027 obs */

proc contents data=input.first_attempt; run; /* 72 variables, 842209 obs */ 


/*============================================================*
 | secondary cohort (N=622,204) from 7099559 claims
 *============================================================*/
* identify; 
proc sql; 
  create table input.disposition as
  select
    	 patient_id,
         sum(case when encnt_outcm_cd = "PD" then 1 else 0 end) as count_PD, 
		 sum(case when encnt_outcm_cd = "RV" then 1 else 0 end) as count_RV, 
		 sum(case when encnt_outcm_cd = "RJ" then 1 else 0 end) as count_RJ
  
  from input.rx18_24_glp1_long_v00
  group by patient_id;
quit;

data input.disposition; set input.disposition; if count_PD = 0 then no_PD_ever = 1; else no_PD_ever = 0; run;
data input.disposition; set input.disposition; if count_PD = 0 and count_RV = 0 then no_PD_only_RJ = 1; else no_PD_only_RJ = 0; run;

proc freq data=input.disposition; table no_PD_ever; run;

proc sql; 
    select count(distinct patient_id) as total_patient_number
    from input.disposition;
quit; /* 842027 individuals */


proc sql;
    create table input.rx18_24_glp1_long_v01 as
    select *
    from input.rx18_24_glp1_long_v00 as a
    where a.patient_id in (
        select distinct patient_id
        from input.disposition
        where no_PD_ever = 0
    );
quit; /* 7099559 obs */

proc sql; 
    select count(distinct patient_id) as total_patient_number
    from rx18_24_glp1_long_v01;
quit; /* 622204 individuals */

data input.id_primary; set input.disposition; keep patient_id; run;
data input.id_secondary; set input.disposition; if no_PD_ever =0; run;
data input.id_secondary; set input.id_secondary; keep patient_id; run;


/*============================================================*
 | secondary cohort (N=622,204) from 7100432 claims
 *============================================================*/

