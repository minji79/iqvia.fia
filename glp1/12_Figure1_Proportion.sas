/*
input.first_attempt  (N=984398)
input.reject_first_attempt_summary
input.reverse_first_attempt_summary
input.secondary_cohort_wide
input.final_claims
*/

/*============================================================*
 |     tracking 
 *============================================================*/


proc contents data=input.secondary_cohort_wide; run;
proc freq data=input.figure2; table RJ_reason_final; run;

proc sql;
  create table figure2 as
  select distinct a.patient_id, a.RJ_reason as RJ_reason_index, b.patient_id as secondary_cohort_id, b.discontinuation
  from input.first_attempt as a
  left join input.id_secondary as b
  on a.patient_id = b.patient_id;
quit;

proc sql;
  create table figure2 as
  select distinct a.*, b.RJ_reason as RJ_reason_final
  from figure2 as a
  left join input.final_claims as b
  on a.patient_id = b.patient_id;
quit;

data input.figure2; set figure2; if missing(secondary_cohort_id) then secondary_cohort=0; else secondary_cohort=1; run;

/* ppl whose first not fill -> eventually filled */
data late_fill; set input.figure2; if upcase(RJ_reason_index) ne "APPROVED - PAID" and secondary_cohort = 1; run;
proc freq data=late_fill; table RJ_reason_index; run;


/**/
proc freq data=input.secondary_cohort_wide; table disc_at_1y; run;
data discont; set input.secondary_cohort_wide; if disc_at_1y=1; run;
proc freq data=discont; table final_claim_disposition; run;


proc print data=figure2 (obs=10); run;


data input.figure2; set input.figure2; 
  length disc_final_disposition $100.;
  if discontinuation=1 and RJ_reason_final in ("RJ_PrAu","RJ_Step","RJ_QtyLimit") then disc_final_disposition="final_RJ_UM"; 
  else if discontinuation=1 and RJ_reason_final in ("NA","RJ_Coverage_Not_Active","RJ_Others_NotForm") then disc_final_disposition="final_RJ_Non_formulary"; 
  else if discontinuation=1 and RJ_reason_final in ("RJ_NtCv") then disc_final_disposition="final_RJ_Not_covered"; 
  else if discontinuation=1 and RJ_reason_final in ("Approved - paid") then disc_final_disposition="final_paid"; 
  else if discontinuation=1 and RJ_reason_final in ("Approved - reversed") then disc_final_disposition="final_reversed"; 
  else if discontinuation=0 then disc_final_disposition="NOT DISC"; 
  else disc_final_disposition=""; 
run;

proc freq data=input.figure2; table disc_final_disposition; run;
