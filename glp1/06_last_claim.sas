
/*============================================================*
| 1. identify the final claim among individuals with discontinuation ==1 
*============================================================*/
data final_claims_disc; set input.rx18_24_glp1_long_v01; if discontinuation = 1; run;
data final_claims_disc; set final_claims_disc; if svc_dt < disc_date; run;

proc print data=input.rx18_24_glp1_long_v01 (obs=70); var patient_id svc_dt encnt_outcm_cd days_supply_cnt payer_type discontinuation disc_date disc_at_6m disc_at_1y disc_at_2y; run;

proc sort data=input.rx18_24_glp1_long_v01 out last_claim; by patient_id descending svc_dt; run;
proc print data=last_claim (obs=30); var patient_id svc_dt discontinuation disc_date disc_at_6m disc_at_1y disc_at_2y; run;


/*============================================================*
| 2. identify the final claim among individuals with discontinuation ==0
*============================================================*/
data final_claims_non_disc; set input.rx18_24_glp1_long_v01; if discontinuation = 0; run;
