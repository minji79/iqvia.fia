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
/* RJ: 211507 individuals; RV: 149053 = total of 360560 individuals */

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
proc print data=input.id_2837133 (obs=10); var patient_birth_year; run; /* 1976 */




proc print data=input.fail_first_attempt_long (obs=30); where patient_id = 2837133; var patient_id svc_dt plan_name plan_type molecule_name encnt_outcm_cd RJ_reason RJ_reason_index secondary_cohort; run;






