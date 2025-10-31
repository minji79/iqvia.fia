
proc print data=input.rx18_24_glp1_long_v01 (obs=70); var patient_id svc_dt encnt_outcm_cd days_supply_cnt payer_type discontinuation disc_date disc_at_6m disc_at_1y disc_at_2y; run;

proc sort data=input.rx18_24_glp1_long_v01 out=final_claim; by patient_id descending svc_dt; run;
proc print data=final_claim (obs=50); var patient_id svc_dt payer_type encnt_outcm_cd days_supply_cnt discontinuation disc_date disc_at_6m disc_at_1y disc_at_2y; run;

/*============================================================*
| 1. identify the final claim among individuals with discontinuation ==1 (N= 611 703)
*============================================================*/
proc freq data=patients_v1; table discontinuation; run;

proc sql;
  create table final_claim_disc as 
  select *
  from input.rx18_24_glp1_long_v01
  where patient_id in (
      select patient_id 
      from input.patients_v1 where discontinuation =1
  );
quit;

proc sql; 
  select count(distinct patient_id) as count_pt
  from final_claim_disc; 
quit; /* 611 703 */

proc sort data=final_claim_disc; by patient_id descending svc_dt; run;
data final_claim_disc; set final_claim_disc; if svc_dt <= disc_date; run;
proc print data=final_claim_disc (obs=30); var patient_id svc_dt encnt_outcm_cd discontinuation disc_date disc_at_6m disc_at_1y disc_at_2y; run;

data final_claim_disc; set final_claim_disc; by patient_id; if first.patient_id; run; /* 611 703 individuals */


/*============================================================*
| 2. identify the final claim among individuals with discontinuation ==0 (N= 156 943)
*============================================================*/
proc sql;
  create table final_claim_non_disc as 
  select *
  from input.rx18_24_glp1_long_v01
  where patient_id in (
      select patient_id 
      from input.patients_v1 where discontinuation =0
  );
quit;

proc sql; 
  select count(distinct patient_id) as count_pt
  from final_claim_non_disc; 
quit; /* 156 943 obs */

proc sort data=final_claim_non_disc; by patient_id descending svc_dt; run;
proc print data=final_claim_non_disc (obs=70); var patient_id svc_dt encnt_outcm_cd discontinuation disc_date disc_at_6m disc_at_1y disc_at_2y; run;

data final_claim_non_disc; set final_claim_non_disc; by patient_id; if first.patient_id; run; /* 156 943 individuals */


/*============================================================*
| 3. pool both datasets
*============================================================*/
data input.final_claims; set final_claim_disc final_claim_non_disc; run;








