/************************************************************************************
	1. distinct patients - biosimilar users (N = 39457)
************************************************************************************/
data input.adalimumab_claim_v0; set input.adalimumab_claim_v0; year = year(svc_dt); run;
proc sql;
    create table counts as
    select count(distinct patient_id) as count, year
    from input.adalimumab_claim_v0
	group by year;
quit;
proc print data=counts; run;

/* biosimilar users 1378 for 2024 */
data adalimumab_claim_v0; set input.adalimumab_claim_v0; if category ne "reference_biologics"; run;
proc sql;
    create table counts as
    select count(distinct patient_id) as count, year
    from adalimumab_claim_v0
	group by year;
quit;
proc print data=counts; run;

/************************************************************************************
	2. categorize patients to (1) biosimilar_initiator, and (2) switcher (N = 39457)
************************************************************************************/
* sort by patient_id svc_dt; 
proc sort data=input.adalimumab_claim_v0; by patient_id svc_dt; run;

data input.adalimumab_patient_v0;
    set input.adalimumab_claim_v0;
    by patient_id;

    length first_cat $50 switch_date 8;
    retain first_cat switcher biosim_initiator switch_date claim_count first_date last_date prev_cat;

    format first_date last_date switch_date yymmdd10.;

    if first.patient_id then do;
        first_cat = category;
        prev_cat = category;
        switcher = 0;
        biosim_initiator = 0;
        switch_date = .;
        claim_count = 0;

        first_date = svc_dt;
        if first_cat ne "reference_biologics" then biosim_initiator = 1;
    end;

    claim_count + 1;

    /* detect first switch in category */
    if category ne prev_cat and switcher = 0 then do;
        switch_date = svc_dt;
        switcher = 1;
    end;

    prev_cat = category;  /* update for next row comparison */
    last_date = svc_dt;

    if last.patient_id then output;
run;

proc print data=input.adalimumab_patient_v0 (obs=20); var patient_id first_date last_date claim_count switch_date first_cat biosim_initiator switcher; where switcher = 1; run;
proc print data=input.adalimumab_patient_v0 (obs=20); run;
proc contents data=input.adalimumab_patient_v0; run;


/*
patient_group
Group 1: reference_lover
Group 2: 
Group 3: 
Group 4: 
*/

data input.adalimumab_patient_v0; set input.adalimumab_patient_v0;
	length patient_group $100;
 	retain patient_group;
	if biosim_initiator = 0 and switcher = 0 then patient_group = "reference_lover"; 
 	else if biosim_initiator = 0 and switcher = 1 then patient_group = "switcher_to_biosim"; 
  	else if biosim_initiator = 1 and switcher = 0 then patient_group = "biosim_lover"; 
   	else if biosim_initiator = 1 and switcher = 1 then patient_group = "switcher_to_reference"; 
	else patient_group = "none"; 
run;
proc freq data=input.adalimumab_patient_v0; table patient_group; run;

proc freq data=input.adalimumab_claim_v0; table category; run;

proc freq data=input.adalimumab_patient_v0; table biosim_initiator*switcher; run;


proc print data=input.adalimumab_claim_v0 (obs=20); var patient_id svc_dt molecule_name category; where patient_id = 1237730811; run;


/************************************************************************************
	3. patients's plan over time
************************************************************************************/
data input.adalimumab_patient_plan_v0; set input.adalimumab_claim_v0; patient_id year 

proc contents data=input.adalimumab_claim_v0; run;












