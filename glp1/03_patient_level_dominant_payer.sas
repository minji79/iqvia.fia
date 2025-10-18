
/*============================================================*
 | 1) 2nd cohort (N==768646)
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
  length first_glp1 after_glp1 first_payer_type after_payer_type first_plan_name after_plan_name first_model_type after_model_type first_npi first_provider_id first_indication $50;
  retain first_glp1 after_glp1 first_payer_type after_payer_type glp1_switcher plan_switcher claim_count reject_count reversed_count glp1_switch_count plan_switch_count first_indication
    first_plan_name after_plan_name first_model_type after_model_type first_date last_date glp1_switch_date plan_switch_date total_oop total_days_to_adjudct_cnt first_npi first_provider_id first_provider_zip;
  format first_date last_date glp1_switch_date plan_switch_date yymmdd10.;
  if first.patient_id then do;
        first_glp1 = molecule_name;
        after_glp1 = molecule_name;
        first_payer_type = payer_type;
        after_payer_type = payer_type;
        first_plan_name = plan_name;
        after_plan_name = plan_name;
        first_model_type = model_type;
        after_model_type = model_type;
		first_indication = indication;
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

    if payer_type ne after_payer_type then do;
        plan_switch_count + 1;  /* count all switches */
        if plan_switcher = 0 then do;  /* record first switch only */
            plan_switch_date = svc_dt;
            plan_switcher = 1;
        end;
  	end;
    after_payer_type = payer_type;
    after_plan_name = plan_name;
    after_model_type = model_type;
    
    last_date = svc_dt;

    if last.patient_id then output;
run;

data input.patients_v0; set input.patients_v0; 
keep patient_id days_supply_cnt first_indication first_glp1 after_glp1 first_payer_type after_payer_type glp1_switcher plan_switcher claim_count reject_count reversed_count glp1_switch_count plan_switch_count
    first_plan_name after_plan_name first_model_type after_model_type first_date last_date glp1_switch_date plan_switch_date total_oop total_days_to_adjudct_cnt first_npi first_provider_id first_provider_zip;
run; /* 768,646 obs */

data input.patients_v0; set input.patients_v0; 
paid_count = claim_count - reject_count - reversed_count;
if claim_count > 0 then pct_fill = paid_count / claim_count;
else pct_fill = .;
run;


 
