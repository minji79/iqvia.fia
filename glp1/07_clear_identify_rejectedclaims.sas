

/*============================================================*
 | 1) identify the unique precription
 *============================================================*/

* 1. add fill_nbr, final_claim_ind to our cohorts; 

%macro yearly(year=, refer=);
proc sql; 
  create table input.rx_&year._glp1 as
  select distinct a.*, b.rx_written_dt, b.fill_nbr, b.final_claim_ind
  from input.rx_&year._glp1 as a 
  left join &refer as b
  on a.claim_id = b.claim_id;
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

proc print data=input.rx_24_glp1 (obs=10); run;



proc print data=input.rx18_24_glp1_long_v00 (obs=10); var patient_id svc_dt ndc npi payer_type model_type plan_name final_claim_ind encnt_outcm_cd; run;


* sample for one individual(1036706250);
data sample; set biosim.rxfact2024; if patient_id =1036706250; run;
proc sort data=sample; by patient_id svc_dt; run;
proc print data=sample (obs=10); 
var patient_id svc_dt ndc npi provider_id	rx_written_dt auth_rfll_nbr fill_nbr final_claim_ind rjct_cd; 
run;

data sample_22; set biosim.rxfact2022; if patient_id =1036706250; run;
data sample_20; set biosim.rxfact2020; if patient_id =1036706250; run;
data sample_18; set biosim.rxfact2018; if patient_id =1036706250; run;

data input.sample_1036706250; set sample sample_22 sample_20 sample_18; run;
proc sort data=input.sample_1036706250; by patient

proc print data=biosim.rxfact2024 (obs=10); 

var patient_id svc_dt ndc npi provider_id	rx_written_dt auth_rfll_nbr fill_nbr payer_type model_type plan_name final_claim_ind encnt_outcm_cd; 
run;
