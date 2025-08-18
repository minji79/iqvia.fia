/************************************************************************************
	1. distinct patients (N = 39457)
************************************************************************************/
data input.adalimumab_claim_v0; set input.adalimumab_claim_v0; year = year(svc_dt); run;
proc sql;
    create table counts as
    select count(distinct patient_id) as count, year
    from input.adalimumab_claim_v0
	group by year;
quit;
proc print data=counts; run;

/* biosimilar users 1378 for 2024*/
data adalimumab_claim_v0; set input.adalimumab_claim_v0; if category ne "reference_biologics"; run;
proc sql;
    create table counts as
    select count(distinct patient_id) as count, year
    from adalimumab_claim_v0
	group by year;
quit;
proc print data=counts; run;

* sort by patient_id svc_dt; 
proc sort data=input.adalimumab_claim_v0; by patient_id svc_dt; run;
