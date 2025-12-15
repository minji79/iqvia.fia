
directory: cd /dcs07/hpm/data/iqvia_fia


/* run sas */
rm ~/.config/chromium/Singleton*
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* set library */
libname plan "/dcs07/hpm/data/iqvia_fia/jhu_plan";   
libname input "/dcs07/hpm/data/iqvia_fia/glp1_disc";   /* my own directory */
libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */
libname glp1 "/dcs04/hpm/data/iqvia_fia/glp1_paper/data";
libname biosim "/dcs07/hpm/data/iqvia_fia/biosim";   /* for reference files */
libname coupon "/dcs07/hpm/data/iqvia_fia/glp1_disc/glp1_coupon";   
libname parquet "/dcs07/hpm/data/iqvia_fia/parquet/data";   

libname fast "/fastscratch/myscratch/mkim";   /* my fastbarch with 1 TB memory */


/*============================================================*
 | 0. set up to add 2025 data -> make equivalent with the ilina data table
 *============================================================*/
* raw 2025 claims;
proc import datafile="/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2025.dta" out=biosim.RxFact2025 dbms=dta replace; run;

proc import datafile="/dcs07/hpm/data/iqvia_fia/biosim/insyr25.csv"
    out=biosim.insyr25
    dbms=csv
    replace;
    guessingrows=max;
run;

proc contents data=biosim.insyr25; run;
proc print data=biosim.insyr25 (obs=10); run;

data biosim.RxFact2025_clean; set biosim.RxFact2025; drop ama_do_not_contact_ind ama_pdrp_ind auth_rfll_nbr cob_ind daw_cd days_to_adjudct_cnt dspnsd_qty month_id provider_zip rx_orig_cd rx_typ_cd rx_written_dt sob_desc sob_value week_id; run;

data biosim.RxFact2025_clean; set biosim.RxFact2025_clean; rename ndc = product_ndc; run;


/* merge with plan file */
proc contents data=biosim.plan; run;
proc sql;
  create table biosim.RxFact2025_clean as
  select a.*, b.model_type, b.plan_name, b.payer_name, b.adjudicating_pbm_plan_name
  from biosim.RxFact2025_clean as a
  left join biosim.plan as b
    on a.plan_id=b.plan_id;
quit;

/* merge with product file */
proc contents data=biosim.product; run;
proc sql;
  create table biosim.RxFact2025_clean as
  select a.*, b.molecule_name, b.usc_3, b.usc_5, b.usc_3_description, b.usc_5_description, b.otc_indicator, b.branded_generic
  from biosim.RxFact2025_clean as a
  left join biosim.product as b
    on a.product_ndc=b.product_ndc;
quit;


/* plan_type */
data biosim.RxFact2025_clean;
  set biosim.RxFact2025_clean;
  length plan_type $20;
  plan_type='';

  if upcase(model_type)='CASH'                          then plan_type='Cash';
  else if upcase(model_type) in ('DISC CRD','DISC MED','SR CRD')
                                                        then plan_type='Discount Card';
  else if upcase(model_type)='VOUCHER'                  then plan_type='Coupon/Voucher';
  else if upcase(model_type)='FFS MED'                  then plan_type='Medicaid FFS';
  else if index(upcase(model_type),'HIX')>0             then plan_type='Exchange';
  else if upcase(model_type) in ('MED PDPG','MED PDP','DE MMP','EMP PDP','EMP RPDP')
                                                        then plan_type='Medicare TM';
  else if upcase(model_type) in ('MED ADVG','MED ADV','MED SNP','MED SNPG')
                                                        then plan_type='Medicare ADV';
  else if upcase(model_type) in ('MGD MEDI','MEDICAID') then plan_type='Medicaid MCO';
  else if upcase(model_type) in
       ('CDHP','COMBO','HMO','HMO - HR','INDIVIDUAL','PPO','POS','TRAD IND','WRAP',
        'EMPLOYER','STATE EMP','FED EMP','PBM','PBM BOB','NON-HMO','NETWORK',
        'GROUP','IPA','STAFF','EPO')                    then plan_type='Commercial';
  else plan_type='Other';
run;


/* rjct_grp */
data biosim.RxFact2025_clean;
  set biosim.RxFact2025_clean;
  length rjct_grp 3;
  if rjct_cd in ('88','608','088','0608') then rjct_grp=1;
  else if rjct_cd in ('3N','3P','3S','3T','3W','03N','03P','03S','03T','03W',
                      '3X','3Y','64','6Q','75','03X','03Y','064','06Q','075',
                      '80','EU','EV','MV','PA','080','0EU','0EV','0MV','0PA')
       then rjct_grp=2;
  else if rjct_cd in ('60','61','63','65','70','060','061','063','065','070',
                      '7Y','8A','8H','9Q','9R','9T','9Y','BB','MR',
                      '07Y','08A','08H','09Q','09R','09T','09Y','0BB','0MR')
       then rjct_grp=3;
  else if rjct_cd in ('76','7X','AG','RN','076','07X','0AG','0RN')
       then rjct_grp=4;
  else if rjct_cd in ('','00','000') then rjct_grp=0;
  else rjct_grp=5;

run;

/* merge with LevyPDRJRV file */
proc sql; 
  create table biosim.RxFact2025_clean as
  select distinct a.*, b.encnt_outcm_cd
  from biosim.RxFact2025_clean as a 
  left join input.LevyPDRJRV as b
  on a.claim_id = b.claim_id;
quit;

/* year */ 
data biosim.RxFact2025_clean; set biosim.RxFact2025_clean; year = year(svc_dt); run;


/*============================================================*
 | 1. identify Hopkin Plan -> payer_id & plan_id
 *============================================================*/
proc print data=biosim.plan;   where index(upcase(payer_name), "HOPKINS") > 0; run; /* one employee plan among 6 plans */
data plan.hopkins_plan; set biosim.plan; if payer_id = 13461186 and plan_id = 23142; run;
proc print data=plan.hopkins_plan; run;
 
/*============================================================*
 | 2. Anyone who ever had an attempted claim (FOR ANY DRUG) | hopkins_plan_claim_all & hopkins_plan_patient_all
 *============================================================*/

/* in the primary payer */
proc sql; 
  create table as_primary_1824 as
  select distinct a.*
  from input.RxFact_2018_2024_ili as a 
  inner join plan.hopkins_plan as b
  on a.payer_id = b.payer_id and a.plan_id = b.plan_id;
quit;

proc sql; 
  create table as_primary_25 as
  select distinct a.*
  from biosim.RxFact2025_clean as a 
  inner join plan.hopkins_plan as b
  on a.payer_id = b.payer_id and a.plan_id = b.plan_id;
quit;

data plan.as_primary; set as_primary_1824 as_primary_25; run;
data plan.as_primary; set plan.as_primary; length primary_secondary $100.; primary_secondary = "primary"; run;

/* in the secondary payer */
proc sql; 
  create table as_secondary_1824 as
  select distinct a.*
  from input.RxFact_2018_2024_ili as a 
  inner join plan.hopkins_plan as b
  on a.sec_payer_id = b.payer_id and a.sec_plan_id = b.plan_id;
quit;

proc sql; 
  create table as_secondary_25 as
  select distinct a.*
  from biosim.RxFact2025_clean as a 
  inner join plan.hopkins_plan as b
  on a.sec_payer_id = b.payer_id and a.sec_plan_id = b.plan_id;
quit;

data plan.as_secondary; set as_secondary_1824 as_secondary_25; run;
data plan.as_secondary; set plan.as_secondary; length primary_secondary $100.; primary_secondary = "secondary"; run;

/* merge */
data plan.hopkins_users; set plan.as_primary plan.as_secondary; run;
proc freq data=plan.hopkins_users; table primary_secondary; run;

/*============================================================*
 | 3. identify GLP1 users (80 out of 1153)
 *============================================================*/
data plan.hopkins_users; set plan.hopkins_users; if molecule_name in ("DULAGLUTIDE", "EXENATIDE", "LIRAGLUTIDE", "LIRAGLUTIDE (WEIGHT MANAGEMENT)", "LIXISENATIDE",
"SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)") then glp1 =1; else glp1 =0; run;

proc freq data=plan.hopkins_users; table glp1; run;

/* total number of all users (N=1153) */
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from plan.hopkins_users;
quit;

/* total number of those who used glp1 (N=80) */
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from plan.hopkins_users
    where molecule_name in ("DULAGLUTIDE", "EXENATIDE", "LIRAGLUTIDE", "LIRAGLUTIDE (WEIGHT MANAGEMENT)", "LIXISENATIDE",
"SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)");
quit;

proc freq data=plan.hopkins_users; table year*glp1; run;


/*============================================================*
 | 4. identify coupon use
 *============================================================*/

proc sql;
  create table plan.hopkins_users as
  select a.*, b.model_type_name as sec_model_type_name
  from plan.hopkins_users as a
  left join biosim.plan as b
    on a.sec_plan_id=b.plan_id;
quit;

data plan.hopkins_users; set plan.hopkins_users; if sec_model_type_name = 'COUPON/VOUCHER PROGRAM' then coupon = 1; else coupon = 0; run; 
proc freq data=plan.hopkins_users; table coupon; run;


/*============================================================*
 | 5. identify HOPKINS npi (hopkins zip code = (21287, 21205, 21202, 21224, 20016, 20814, 21044, 21287, 33701))
 | ref: https://www.hopkinsmedicine.org/patient-care/locations#:~:text=They%20also%20have%20a%20children's%20hospital%20in,Center**%205755%20Cedar%20Ln%2C%20Columbia%2C%20MD%2021044
 *============================================================*/

proc contents data=biosim.provider; run;
proc print data=biosim.provider (obs=10); run;

proc sql;
  create table plan.hopkins_users as
  select a.*, b.provider_zip_code, b.provider_state, b.specialty_description
  from plan.hopkins_users as a
  left join biosim.provider as b
    on a.provider_id = b.provider_id;
quit;

data plan.hopkins_users; set plan.hopkins_users; if provider_zip_code in (21287, 21205, 21202, 21224, 20016, 20814, 21044, 21287, 33701) then hopkins_npi = 1; else hopkins_npi = 0; run;
proc freq data=plan.hopkins_users; table hopkins_npi; run;

proc freq data=plan.hopkins_users; table plan_type; run;
proc freq data=plan.hopkins_users; table rjct_grp; run;
proc freq data=plan.hopkins_users; table encnt_outcm_cd; run;


