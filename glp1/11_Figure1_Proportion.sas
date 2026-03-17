/*
input.first_attempt 
input.reject_first_attempt_summary
input.reverse_first_attempt_summary
input.secondary_cohort_wide
input.final_claims
*/

proc contents data=input.secondary_cohort_wide; run;
proc freq data=input.figure1; table RJ_reason_final; run;


/*============================================================*
 |     tracking - overall
 *============================================================*/

proc sql;
  create table input.figure1 as
  select distinct a.patient_id, a.RJ_reason_adj as RJ_reason_index, a.molecule_name as molecule_index, a.dominant_payer_adj as dominant_payer_index,
                  b.patient_id as secondary_cohort_id, 
                  b.final_claim_disposition,
                  b.disc_at_1y
  from input.first_attempt as a
  left join input.secondary_cohort_wide as b
  on a.patient_id = b.patient_id;
quit;

data input.figure1; set input.figure1; if missing(secondary_cohort_id) then secondary_cohort=0; else secondary_cohort=1; run;


/* ppl whose first not fill -> eventually filled */
data late_fill; set input.figure1; if upcase(RJ_reason_index) ne "APPROVED - PAID" and secondary_cohort = 1; run;
proc freq data=late_fill; table RJ_reason_index; run;

proc sql;
 create table input.figure1 as
 select distinct a.*, b.patient_id as late_fill_id
 from input.figure1 as a
 left join late_fill as b
 on a.patient_id = b.patient_id;
quit; 
data input.figure1; set input.figure1; if missing(late_fill_id) then late_fill_after_RJ = 0; else late_fill_after_RJ=1; run;


/* cash user */
* whether they paid their first paid claim with cash? ;
proc sort data=input.rx18_24_glp1_long_v01; by patient_id svc_dt; run;
proc print data=input.rx18_24_glp1_long_v01 (obs=20); var patient_id svc_dt; run;
data paid; set input.rx18_24_glp1_long_v01; if encnt_outcm_cd = "PD"; run;
data first_paid_claim; set paid; by patient_id; if first.patient_id; run;

proc sql;
 create table first_claim_late_fill as
 select distinct a.*
 from first_paid_claim as a
 inner join late_fill as b
 on a.patient_id = b.patient_id;
quit; /* 140737 individuals */

proc freq data=first_claim_late_fill; table payer_type; run;

/* add cash user */
data cash; set first_claim_late_fill; if payer_type = "Cash"; run;

proc sql;
  create table input.figure1 as
  select distinct a.*, b.patient_id as cash_paid_id
  from input.figure1 as a
  left join cash as b
  on a.patient_id = b.patient_id;
quit;
data input.figure1; set input.figure1; if missing(cash_paid_id) then cash_users_after_RJ = 0; else cash_users_after_RJ=1; run;

/* discontinucation */
proc freq data=input.figure1; table disc_at_1y*final_claim_disposition; run;


/*============================================================*
 semaglutide (N=544972) 
 data sample; set input.figure1; if molecule_index in ("SEMAGLUTIDE","SEMAGLUTIDE (WEIGHT MANAGEMENT)"); run;
 tirzepatide (N=184204)
 data sample; set input.figure1; if molecule_index in ("TIRZEPATIDE","TIRZEPATIDE (WEIGHT MANAGEMENT)"); run;
 *============================================================*/

/*============================================================*
Commercial (N=148181)
data sample; set input.figure1; if dominant_payer_index = "Commercial"; run;
Medicare (n=258220)
data sample; set input.figure1; if dominant_payer_index = "Medicare"; run;
Medicaid (n=137257)
data sample; set input.figure1; if dominant_payer_index = "Medicaid"; run;
Exchange (n=35878)
data sample; set input.figure1; if dominant_payer_index = "Exchange"; run;
 *============================================================*/
 
proc freq data=sample; table RJ_reason_index; run;
proc freq data=sample; table secondary_cohort; run;

data late_fill; set sample; if upcase(RJ_reason_index) ne "APPROVED - PAID" and secondary_cohort = 1; run;
proc freq data=late_fill; table RJ_reason_index; run;
proc freq data=late_fill; table cash_users_after_RJ*RJ_reason_index; run;

/* discontinucation */
proc freq data=sample; table disc_at_1y*final_claim_disposition; run;


/*============================================================*
 |     individuals who got rejected at their initial attempt
 *============================================================*/
proc print data=input.figure1 (obs=10); run;
proc freq data=input.figure1; table RJ_reason_index; run;

data input.fail_first_attempt_id; set input.figure1; if RJ_reason_index in ("RJ_NotFormulary","RJ_NtCv","RJ_UM","Approved - reversed"); run; 
/* RJ: 211507 +1 individuals; RV: 149053 = total of 360560 individuals */

/* make longitudinal dataset for this cohort */
proc print data=input.rx18_24_glp1_long_v01 (obs=10); run;

proc sql;
  create table input.fail_first_attempt_long as
  select distinct a.*, b.RJ_reason_index, b.secondary_cohort
  from input.rx18_24_glp1_long_v00 as a
  inner join input.fail_first_attempt_id as b
  on a.patient_id = b.patient_id;
quit; /* 2069565 individuals */

proc sort data=input.fail_first_attempt_long; by patient_id svc_dt; run;
proc print data=input.fail_first_attempt_long (obs=30); var patient_id svc_dt plan_name plan_type molecule_name encnt_outcm_cd RJ_reason RJ_reason_index secondary_cohort; run;

/* id = 2837133 */
data id_2837133_24; set input.rx_24_glp1; if patient_id = 2837133; run;
data id_2837133_23; set input.rx_23_glp1; if patient_id = 2837133; run;
data id_2837133_22; set input.rx_22_glp1; if patient_id = 2837133; run;
data id_2837133_21; set input.rx_21_glp1; if patient_id = 2837133; run;
data id_2837133_20; set input.rx_20_glp1; if patient_id = 2837133; run;
data id_2837133_19; set input.rx_19_glp1; if patient_id = 2837133; run;
data id_2837133_18; set input.rx_18_glp1; if patient_id = 2837133; run;
data id_2837133_17; set input.rx_17_glp1; if patient_id = 2837133; run;

data id_2837133; set id_2837133_17 id_2837133_18 id_2837133_19 id_2837133_20 id_2837133_21 id_2837133_22 id_2837133_23 id_2837133_24; run; /* 68 obs */

* clean the patient_birth_year;
proc sql;
    create table id_age as
    select distinct patient_id, max(patient_birth_year) as patient_birth_year
    from biosim.patient
    group by patient_id;
quit; /* 12170856 obs */

* merge with the dataset without duplication;
proc sql; 
	create table input.id_2837133 as
 	select a.*, b.patient_birth_year
 from id_2837133 as a
	left join id_age as b
 	on a.patient_id = b.patient_id;
 quit;

proc sort data=input.id_2837133; by svc_dt; run;
proc print data=input.id_2837133; var patient_id svc_dt plan_name plan_type molecule_name encnt_outcm_cd rjct_grp rjct_cd; run;

data input.id_2837133; set input.id_2837133; 
	length RJ_reason_index $50.; RJ_reason_index = "RJ_NtCv";
	age_at_claim = year - patient_birth_year; 
	secondary_cohort= 1;
run;

data input.id_2837133; set input.id_2837133; 
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


data input.id_2837133; set input.id_2837133; 
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


/*============================================================*
 |    compare /* RJ: 211507 +1 individuals; RV: 149053 = total of 360560 individuals */
 *============================================================*/

/* pooling with input.fail_first_attempt_long */
proc contents data= input.fail_first_attempt_long; run;
proc contents data= input.id_2837133; run;


data input.fail_first_attempt_long; set input.fail_first_attempt_long input.id_2837133; run;
data input.fail_first_attempt_long; set input.fail_first_attempt_long; if patient_id = 2837133 then secondary_cohort =1; else secondary_cohort=secondary_cohort; run;
proc print data=input.fail_first_attempt_long (obs=30); where patient_id = 2837133; var patient_id svc_dt plan_name plan_type molecule_name encnt_outcm_cd RJ_reason RJ_reason_index secondary_cohort; run;

/* individuals level forming */
proc sort data=input.fail_first_attempt_long; by patient_id svc_dt; run;

/* first paid claim information */
data first; set input.fail_first_attempt_long; if encnt_outcm_cd = "PD"; run;

proc sort data=first; by patient_id svc_dt; run;
data first; set first; by patient_id svc_dt; if first.patient_id; run; /* 140738 individuals */
proc freq data=first; table plan_type; run;
proc print data=first (obs=10); var patient_id svc_dt plan_name plan_type molecule_name encnt_outcm_cd RJ_reason RJ_reason_index secondary_cohort; run;

proc sort data=input.fail_first_attempt_long; by patient_id svc_dt; run;
data input.fail_first_attempt_wide; set input.fail_first_attempt_long;
by patient_id;
	retain attempt_glp1 attempt_plan_type attempt_plan_name first_attempt_date;
 	format first_attempt_date  yymmdd10.;
	if first.patient_id then do;
		first_attempt_date = svc_dt;
        attempt_glp1 = molecule_name;
        attempt_plan_type = plan_type;
        attempt_plan_name = plan_name;
        claim_count = 0;
		paid_count = 0;
        reject_count = 0;
		reversed_count = 0;
        
    end;
	
	claim_count + 1;
	
	if encnt_outcm_cd = "RJ" then reject_count + 1;
	if encnt_outcm_cd = "RV" then reversed_count + 1;
    if encnt_outcm_cd = "PD" then paid_count + 1;

	if last.patient_id then output;
	
 run;   
proc print data=input.fail_first_attempt_wide (obs=10); var patient_id first_attempt_date RJ_reason_index attempt_glp1 attempt_plan_type attempt_plan_name claim_count paid_count; run;

proc sql;
	create table input.fail_first_attempt_wide as
	select distinct a.*, b.svc_dt as first_paid_date, b.plan_name as paid_plan_name, b.plan_type as paid_plan_type, b.molecule_name as paid_glp1
	from input.fail_first_attempt_wide as a
	left join first as b
	on a.patient_id = b.patient_id;
quit; 

/* switching indicator */
data input.fail_first_attempt_wide;
    set input.fail_first_attempt_wide;

    if secondary_cohort = 1 then do;
        if not missing(attempt_glp1) and not missing(paid_glp1) then do;
            if attempt_glp1 = paid_glp1 then switch_glp1 = 1;
            else switch_glp1 = 0;
        end;
        else switch_glp1 = .;
    end;
    else switch_glp1 = .;
run;

data input.fail_first_attempt_wide;
    set input.fail_first_attempt_wide;

    if secondary_cohort = 1 then do;
        if not missing(attempt_plan_name) and not missing(paid_plan_name) then do;
            if attempt_plan_name = paid_plan_name then switch_plan_name = 1;
            else switch_plan_name = 0;
        end;
        else switch_plan_name = .;
    end;
    else switch_plan_name = .;
run;

data input.fail_first_attempt_wide;
    set input.fail_first_attempt_wide;

    if secondary_cohort = 1 then do;
        if not missing(attempt_plan_type) and not missing(paid_plan_type) then do;
            if attempt_plan_type = paid_plan_type then switch_plan_type = 1;
            else switch_plan_type = 0;
        end;
        else switch_plan_type = .;
    end;
    else switch_plan_type = .;
run;

data input.fail_first_attempt_wide; set input.fail_first_attempt_wide; length RJ_reason_index_adj $100.; if RJ_reason_index in ("RJ_NtCv","RJ_UM","RJ_NotFormulary") then RJ_reason_index_adj="RJ_index"; else RJ_reason_index_adj=RJ_reason_index; run;
data input.fail_first_attempt_wide; set input.fail_first_attempt_wide; 
if secondary_cohort = 1 
       and not missing(first_paid_date)
       and not missing(first_attempt_date)
    then time_to_paid = first_paid_date - first_attempt_date;
    else time_to_paid = .; run;


proc print data=input.fail_first_attempt_wide (obs=10); 
var patient_id first_attempt_date RJ_reason_index attempt_glp1 attempt_plan_type attempt_plan_name secondary_cohort time_to_paid first_paid_date paid_plan_type paid_plan_name paid_glp1 claim_count paid_count reject_count reversed_count; 
run;

/*============================================================*
 |    Table 1 (N=)
 *============================================================*/
proc freq data=input.fail_first_attempt_wide; table RJ_reason_index_adj*secondary_cohort  /norow nopercent; run;

/* how to overcome? among secondary_cohort */
data sample; set input.fail_first_attempt_wide; if secondary_cohort=1; run;
proc freq data=sample; table paid_plan_type*RJ_reason_index_adj /norow nopercent; run;
proc freq data=sample; table switch_plan_type /norow nopercent; run;
proc freq data=sample; table switch_glp1 /norow nopercent; run;

proc means data=sample n nmiss median q1 q3 min max; var time_to_paid; class paid_plan_type; run;






















