

/*============================================================*
 | 1) Need to include only the final decision on each prescription (incl. initial fill, and following refills) -> exclude them in the cohort derivation step
 *============================================================*/

/*============================================================*
 | 2) Need to exclude rejected claims due to plan switching
 *============================================================*/
proc contents data=input.rx18_24_glp1_long_v00; run;
proc print data=patient_plan (obs=10); run; 

/*****************************
* 1. make id table for our cohort: patient_id year plan_id table; 
*****************************/
data input.patient_plan; set input.rx18_24_glp1_long_v00; keep patient_id year plan_name plan_id plan_type; run;
proc sort data=input.patient_plan nodupkey; by patient_id year plan_id; run;

/*****************************
* 2. merge with the claims table to count the PD, RJ, RV claims;
*****************************/
data input.RxFact_2018_2024_ili; set input.RxFact_2018_2024_ili; year = year(svc_dt); run;

* 2-1. count disposition on any drug;
proc sql; 
  create table input.plan_enrollment_v1 as
  select a.*,         
         sum(case when b.encnt_outcm_cd = "PD" then 1 else 0 end) as any_drug_PD, 
         sum(case when b.encnt_outcm_cd = "RJ" then 1 else 0 end) as any_drug_RJ, 
         sum(case when b.encnt_outcm_cd = "RV" then 1 else 0 end) as any_drug_RV
         
  from input.plan_enrollment as a 
  left join input.RxFact_2018_2024_ili as b
  on a.patient_id = b.patient_id and a.year = b.year and a.plan_id = b.plan_id
  group by a.patient_id, a.year, a.plan_id;
quit;

* 2-2. count disposition on glp1;
proc sql; 
  create table input.plan_enrollment as
  select a.*,
         sum(case when b.encnt_outcm_cd = "PD" then 1 else 0 end) as any_glp1_PD, 
         sum(case when b.encnt_outcm_cd = "RJ" then 1 else 0 end) as any_glp1_RJ, 
         sum(case when b.encnt_outcm_cd = "RV" then 1 else 0 end) as any_glp1_RV
         
  from input.plan_enrollment_v1 as a 
  left join input.rx18_24_glp1_long_v00 as b
  on a.patient_id = b.patient_id and a.year = b.year and a.plan_id = b.plan_id
  group by a.patient_id, a.year, a.plan_id;
quit;
proc sort data=input.plan_enrollment nodupkey; by patient_id year plan_id; run;
proc print data=input.plan_enrollment_v1 (obs=10); run;


/*****************************
* 3. identify the last-year enrollment;
*****************************/
proc sort data=input.plan_enrollment out=plan_enrollment; by patient_id plan_id year; run;
data input.plan_enrollment_v1;
    set plan_enrollment;
    by patient_id plan_id year;
    retain prev_plan prev_year;
    enrolled_last_yr = 0;

    if first.patient_id then do;
        prev_plan = plan_id;
        prev_year = year;
    end;
    else do;
        if year = prev_year + 1 and plan_id = prev_plan then enrolled_last_yr = 1;
        prev_plan = plan_id;
        prev_year = year;
    end;
run;
data input.plan_enrollment; set input.plan_enrollment_v1; drop prev_plan prev_year; run;
proc sort data=input.plan_enrollment; by patient_id year; run;

/*****************************
* 4. enrollment indicator -> merge with the all dataset
*****************************/
* merge with payer_type and payer_type_indicator;
data id; set input.rx18_24_glp1_long_v00; keep plan_id payer_type payer_type_indicator; run;
proc sort data=id nodupkey; by plan_id payer_type; run;

proc sql; 
  create table input.plan_enrollment_v1 as
  select a.*, b.payer_type, b.payer_type_indicator 
  from input.plan_enrollment as a 
  left join id as b
  on a.plan_id = b.plan_id;
quit;

data input.plan_enrollment_v1; set input.plan_enrollment_v1; drop plan_type; run;
data input.plan_enrollment_v1;
    retain patient_id year plan_id plan_name payer_type payer_type_indicator any_drug_PD any_drug_RJ any_drug_RV any_glp1_PD any_glp1_RJ any_glp1_RV enrolled_last_yr	;
    set input.plan_enrollment_v1;
run;
proc sort data=input.plan_enrollment_v1; by patient_id year; run;
proc print data=input.plan_enrollment_v1 (obs=0); where any_drug_PD = 0 and any_glp1_PD ne 0;  run;

* enrollment;
data input.plan_enrollment; set input.plan_enrollment_v1; if any_drug_PD ne 0 or any_glp1_PD ne 0 then enrollment = 1; else enrollment =0; run;
proc print data=input.plan_enrollment (obs=10); run;

* merge with the overall dataset;
proc sql; 
  create table input.rx18_24_glp1_long_v00 as
  select a.*, b.enrollment
  from input.rx18_24_glp1_long_v00 as a 
  left join input.plan_enrollment as b
  on a.patient_id = b.patient_id and a.plan_id = b.plan_id and a.year = b.year;
quit;

proc sql; 
  create table input.rx18_24_glp1_long_v01 as
  select a.*, b.enrollment
  from input.rx18_24_glp1_long_v01 as a 
  left join input.plan_enrollment as b
  on a.patient_id = b.patient_id and a.plan_id = b.plan_id and a.year = b.year;
quit;


/*****************************
* 5. re-categorize rejection reasons
*****************************/
* for input.rx18_24_glp1_long_v00; 
data input.rx18_24_glp1_long_v00; 
    set input.rx18_24_glp1_long_v00; 
    length rj_grp $100.;
    rj_grp = "";

  if rjct_cd in ('88','608','088','0608') then rj_grp="rj_step";
  else if rjct_cd in ('3N','3P','3S','3T','3W','03N','03P','03S','03T','03W',
                      '3X','3Y','64','6Q','75','03X','03Y','064','06Q','075',
                      '80','EU','EV','MV','PA','080','0EU','0EV','0MV','0PA')
       then rj_grp="rj_pa";
  else if rjct_cd in ('60','61','63','060','061','063',
                      '7Y','8A','8H','9R','9T','9Y','BB',
                      '07Y','08A','08H','09R','09T','09Y','0BB')
       then rj_grp="rj_not_covered";
  else if rjct_cd in ('MR','0MR','70','070','9Q','09Q') then rj_grp="rj_ndc_block";
  else if rjct_cd in ('76','7X','AG','RN','076','07X','0AG','0RN')
       then rj_grp="rj_qty_limit";
  else if rjct_cd in ('','00','000') then rj_grp="approved";
  else if rjct_cd in ('65','065','67','067','68','068','69','069') then rj_grp="rj_coverage_not_active";
  else rj_grp="rj_others_non_formulary";
run;


data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; 
 length RJ_reason $100.;
 RJ_reason = "";
 if encnt_outcm_cd = "PD" then RJ_reason = 'Approved - paid';
 else if encnt_outcm_cd = "RV" then RJ_reason = 'Approved - reversed';
 *else if encnt_outcm_cd = 'RJ' and payer_type_indicator = "secondary_payer" then RJ_reason = 'RJ by Secondary Payer';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_step" then RJ_reason = 'RJ_Step';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_pa" then RJ_reason = 'RJ_PrAu';
 else if encnt_outcm_cd = 'RJ' and rj_grp in ("rj_not_covered", "rj_ndc_block") then RJ_reason = 'RJ_NtCv';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_qty_limit" then RJ_reason = 'RJ_QtyLimit';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_coverage_not_active" then RJ_reason = 'RJ_Coverage_Not_Active';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_others_non_formulary" then RJ_reason = 'RJ_Others_NotForm';
 else RJ_reason = 'NA';
run;

proc freq data=rx18_24_glp1_long_v00; table RJ_reason; run;
proc freq data=rx18_24_glp1_long_v00; table rj_grp; run;
proc freq data=rx18_24_glp1_long_v00; table rj_grp*payer_type_indicator /nocol nopercent; run;
proc freq data=rx18_24_glp1_long_v00; table rj_grp*enrollment /nocol nopercent; run;


* for input.rx18_24_glp1_long_v01; 
data input.rx18_24_glp1_long_v01; 
    set input.rx18_24_glp1_long_v01; 
    length rj_grp $100.;
    rj_grp = "";

  if rjct_cd in ('88','608','088','0608') then rj_grp="rj_step";
  else if rjct_cd in ('3N','3P','3S','3T','3W','03N','03P','03S','03T','03W',
                      '3X','3Y','64','6Q','75','03X','03Y','064','06Q','075',
                      '80','EU','EV','MV','PA','080','0EU','0EV','0MV','0PA')
       then rj_grp="rj_pa";
  else if rjct_cd in ('60','61','63','060','061','063',
                      '7Y','8A','8H','9R','9T','9Y','BB',
                      '07Y','08A','08H','09R','09T','09Y','0BB')
       then rj_grp="rj_not_covered";
  else if rjct_cd in ('MR','0MR','70','070','9Q','09Q') then rj_grp="rj_ndc_block";
  else if rjct_cd in ('76','7X','AG','RN','076','07X','0AG','0RN')
       then rj_grp="rj_qty_limit";
  else if rjct_cd in ('','00','000') then rj_grp="approved";
  else if rjct_cd in ('65','065','67','067','68','068','69','069') then rj_grp="rj_coverage_not_active";
  else rj_grp="rj_others_non_formulary";
run;


data input.rx18_24_glp1_long_v01; set input.rx18_24_glp1_long_v01; 
 length RJ_reason $100.;
 RJ_reason = "";
 if encnt_outcm_cd = "PD" then RJ_reason = 'Approved - paid';
 else if encnt_outcm_cd = "RV" then RJ_reason = 'Approved - reversed';
 *else if encnt_outcm_cd = 'RJ' and payer_type_indicator = "secondary_payer" then RJ_reason = 'RJ by Secondary Payer';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_step" then RJ_reason = 'RJ_Step';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_pa" then RJ_reason = 'RJ_PrAu';
 else if encnt_outcm_cd = 'RJ' and rj_grp in ("rj_not_covered", "rj_ndc_block") then RJ_reason = 'RJ_NtCv';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_qty_limit" then RJ_reason = 'RJ_QtyLimit';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_coverage_not_active" then RJ_reason = 'RJ_Coverage_Not_Active';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_others_non_formulary" then RJ_reason = 'RJ_Others_NotForm';
 else RJ_reason = 'NA';
run;

* within the payer_type_indicator = "dominant_payer";
data sample; set rx18_24_glp1_long_v00; if payer_type_indicator = "dominant_payer"; run;
proc freq data=sample; table RJ_reason* payer_type /norow nopercent; run;

proc freq data=input.rx18_24_glp1_long_v00; table encnt_outcm_cd; run;
proc freq data=input.rx18_24_glp1_long_v00; table rjct_grp; run;



/*============================================================*
 | test
 *============================================================*/

/* investigate the */
data sample; set input.rx_24_glp1 input.rx_23_glp1 input.rx_22_glp1 input.rx_21_glp1 input.rx_20_glp1 input.rx_19_glp1 input.rx_18_glp1 input.rx_17_glp1; run;
data sample; set sample;
    length rj_grp $100.;
    rj_grp = "";

  if rjct_cd in ('88','608','088','0608') then rj_grp="rj_step";
  else if rjct_cd in ('3N','3P','3S','3T','3W','03N','03P','03S','03T','03W',
                      '3X','3Y','64','6Q','75','03X','03Y','064','06Q','075',
                      '80','EU','EV','MV','PA','080','0EU','0EV','0MV','0PA')
       then rj_grp="rj_pa";
  else if rjct_cd in ('60','61','63','060','061','063',
                      '7Y','8A','8H','9R','9T','9Y','BB',
                      '07Y','08A','08H','09R','09T','09Y','0BB')
       then rj_grp="rj_not_covered";
  else if rjct_cd in ('MR','0MR','70','070','9Q','09Q') then rj_grp="rj_ndc_block";
  else if rjct_cd in ('76','7X','AG','RN','076','07X','0AG','0RN')
       then rj_grp="rj_qty_limit";
  else if rjct_cd in ('','00','000') then rj_grp="approved";
  else if rjct_cd in ('65','065','67','067','68','068','69','069') then rj_grp="rj_coverage_not_active";
  else rj_grp="rj_others_non_formulary";
run;

proc freq data=sample; table rj_grp; run;
proc freq data=sample; table rj_grp*final_claim_ind /nocol nopercent; run;

proc freq data=sample order=freq; table rjct_cd*final_claim_ind /nocol nopercent; run;

data sample; set sample; length rjct_cd_v1 $100.; rjct_cd_v1 = "";
	if rjct_cd in ('','00','000') then rjct_cd_v1 = "null,00,000 - approved";
	else if rjct_cd in ('75','075') then rjct_cd_v1 = "75,075 - PA";
	else if rjct_cd in ('88','088') then rjct_cd_v1 = "88,088 - step";
	else if rjct_cd in ('79','079') then rjct_cd_v1 = "79,079 - refill restriction";
	else if rjct_cd in ('70','070') then rjct_cd_v1 = "70,070 - not covered (ndc_block)";
	else if rjct_cd in ('76','076') then rjct_cd_v1 = "76,076 - qty limit";
	else if rjct_cd in ('608','0608') then rjct_cd_v1 = "608,0608 - step";
	else rjct_cd_v1 = rjct_cd; 
run;

proc sort data=sample; by rjct_cd_v1; run;
data sample_summary;
    set sample;
    by rjct_cd_v1;

    retain count_Y count_N count_total 0;

    if first.rjct_cd_v1 then do;
        count_Y = 0;
        count_N = 0;
        count_total = 0;
    end;

    /* Add counts */
    if final_claim_ind = "Y" then count_Y + 1;
    else if final_claim_ind = "N" then count_N + 1;

    count_total + 1;

    /* Output only once per rjct_cd_v1 group */
    if last.rjct_cd_v1 then output;
run;
data sample_summary; set sample_summary; keep rjct_cd_v1 count_Y count_N count_total; run;

data sample_summary; set sample_summary; pct_Y = count_Y / count_total; pct_N = count_N / count_total; run;

proc sort data=sample_summary; by descending count_total descending pct_Y; run;
proc print data=sample_summary (obs=20); run;








