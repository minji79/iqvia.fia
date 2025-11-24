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






