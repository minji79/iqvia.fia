


/*============================================================*
 | 1. id for WALMART employees
 *============================================================*/

data plan.id_walmart; set plan.eric_claim; if index(upcase(plan_name), "WALMART") > 0; run;
proc sql;
    create table plan.id_walmart as
    select distinct patient_id
    from plan.id_walmart;
quit;

/*============================================================*
 | 2. all claims for the WALMART employees
 *============================================================*/







