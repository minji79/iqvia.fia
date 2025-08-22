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
	2. categorize patients to patient_group : (1) biosimilar_initiator, and (2) switcher (N = 39457)
************************************************************************************/
/*
patient_group
Group 1: reference_lover
Group 2: switcher_to_biosim
Group 3: biosim_lover
Group 4: switcher_to_reference
*/

* sort by patient_id svc_dt; 
proc sort data=input.adalimumab_claim_v0; by patient_id svc_dt; run;
proc contents data=input.adalimumab_claim_v0; run;

data input.adalimumab_patient_v0;
    set input.adalimumab_claim_v0;
    by patient_id;

    length first_cat $50 switch_date 8;
    retain first_cat switcher biosim_initiator switch_date claim_count first_date last_date prev_cat ;

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

* test;
proc print data=input.adalimumab_patient_v0 (obs=20); var patient_id first_date last_date claim_count switch_date first_cat biosim_initiator switcher; where switcher = 1; run;
proc print data=adalimumab_patient_v0 (obs=20); run;
proc contents data=input.adalimumab_patient_v0; run;

proc freq data=input.adalimumab_patient_v0; table biosim_initiator*switcher; run;
proc print data=input.adalimumab_claim_v0 (obs=20); var patient_id svc_dt molecule_name category; where patient_id = 1237730811; run;

* merge patient_group & switch_date with total claims;
proc sql; 
 	create table input.adalimumab_claim_v0 as
  	select distinct a.*, b.patient_group, b.switch_date
  	from input.adalimumab_claim_v0 as a
   	left join input.adalimumab_patient_v0 as b
	on a.patient_id = b.patient_id; 
 quit;


/************************************************************************************
	3. patients's demograph and characteristics
************************************************************************************/

/*****************************
*  Gender
*****************************/

proc sql; 
	create table input.adalimumab_patient_v0 as
 	select distinct a.*, b.patient_gender
    from input.adalimumab_patient_v0 as a
	left join input.patient as b
 	on a.patient_id = b.patient_id;
 quit;

* see the duplicated patient_id rows;
/* 1) Find patients that have BOTH F and M recorded */
proc sql;
    create table gender_conflict as
    select patient_id,
           /* has_f = 1 if any F; has_m = 1 if any M */
           (sum(upcase(coalesce(patient_gender, '')) = 'F') > 0) as has_f,
           (sum(upcase(coalesce(patient_gender, '')) = 'M') > 0) as has_m
    from input.adalimumab_patient_v0
    group by patient_id
    ;
quit;

data gender_conflict;
    set gender_conflict;
    invalid_gender = (has_f = 1 and has_m = 1);
    keep patient_id invalid_gender;
run;

/* 2) Join back and set 'invalid' where needed */
proc sql;
    create table input.adalimumab_patient_v0 as
    select a.*,
           case when b.invalid_gender = 1 then 'invalid'
                else a.patient_gender
           end as patient_gender_clean
    from input.adalimumab_patient_v0 as a
    left join gender_conflict as b
      on a.patient_id = b.patient_id
    ;
quit;
proc sort data=input.adalimumab_patient_v0 nodupkey; by patient_id; run;

* test : 
proc freq data=input.adalimumab_patient_v0; table patient_gender; run;
proc freq data=input.adalimumab_patient_v0; table patient_gender*patient_group; run;


* test for duplication; 
proc sql;
    create table df_multi as
    select a.*
    from adalimumab_patient_v0 as a
    inner join (
        select patient_id
        from adalimumab_patient_v0
        group by patient_id
        having count(*) > 1
    ) as b
    on a.patient_id = b.patient_id;
quit;
proc print data=df_multi (obs=20); run;


/*****************************
*  Age at initiation;
*****************************/
* set year_init; 
data input.adalimumab_patient_v0; set input.adalimumab_patient_v0; year_init = year(svc_dt); run;

* merge with patient file -> get year of birth;
proc sql; 
	create table id_age as
 	select distinct a.*, b.patient_birth_year
    from input.adalimumab_patient_v0 as a
	left join input.patient as b
 	on a.patient_id = b.patient_id;
 quit;

* to resolve conflicts when a patient_id has two different patient_birth_year values (0 and 1998), and want to keep only the valid one;
proc sql;
    create table id_age as
    select patient_id, 
           max(patient_birth_year) as patient_birth_year
    from id_age
    group by patient_id;
quit;

* merge with the adalimumab_patient_v0; 
proc sql; 
	create table adalimumab_patient_v0 as
 	select distinct a.*, b.patient_birth_year
    from input.adalimumab_patient_v0 as a
	left join id_age as b
 	on a.patient_id = b.patient_id;
 quit;

* but, there is still invalid value (416 obs) where patient_birth_year = 0 -> let's make them null later; 
data what; set adalimumab_patient_v0; if patient_birth_year = 0; run;

* calculate age at initiation and make invalid data null;
data adalimumab_patient_v0; set adalimumab_patient_v0; age_at_init = year_init - patient_birth_year; run;
data input.adalimumab_patient_v0; set adalimumab_patient_v0; if patient_birth_year=0 then age_at_init = .; run;

* test : 
proc means data=input.adalimumab_patient_v0 n nmiss mean std;  var age_at_init; run;
proc means data=input.adalimumab_patient_v0 n nmiss mean std;
    class patient_group;
    var age_at_init;
run;

/*****************************
*  # of claims per patient: claim_count
*****************************/
proc means data=input.adalimumab_patient_v0 n nmiss mean std;
    class patient_group;
    var claim_count;
run;

/*****************************
*  duration of medication in month
*****************************/
data input.adalimumab_patient_v0; set input.adalimumab_patient_v0; duration_on_med = (last_date - first_date) / 30.5; run;

proc means data=input.adalimumab_patient_v0 n nmiss mean std;
    class patient_group;
    var duration_on_med;
run;

/*****************************
*  OOP for 28 days 
******************************
* identify how many OOP with null or 0;
proc sql;
    select 
        patient_group,
        sum(missing(final_opc_amt)) as count_missing,
        sum(final_opc_amt = 0)      as count_zero
    from input.adalimumab_claim_v0
    group by patient_group;
quit;

* nonzero OOP; 
data adalimumab_claim_v0; set input.adalimumab_claim_v0; if final_opc_amt ne 0 and not missing(final_opc_amt); run;
data adalimumab_claim_v0; set adalimumab_claim_v0; OOP_for_28day = final_opc_amt/days_supply_cnt * 28 ; run;


/*****************************
*  make separate data tables; 
******************************
* make separate data tables; 
proc sort data=input.adalimumab_claim_v0; by patient_id svc_dt; run;

/**** Group 1: reference_lover ****/
data adalimumab_claim_g1; set input.adalimumab_claim_v0; if patient_group = "reference_lover"; run;

/**** Group 2: switcher_to_biosim ****/
data adalimumab_claim_g2; set input.adalimumab_claim_v0; if patient_group = "switcher_to_biosim"; run;
data adalimumab_claim_g2_pre; set adalimumab_claim_g2; if svc_dt < switch_date; run;  
data adalimumab_claim_g2_post; set adalimumab_claim_g2; if svc_dt >= switch_date; run;  

/**** Group 3: biosim_lover ****/
data adalimumab_claim_g3; set input.adalimumab_claim_v0; if patient_group = "biosim_lover"; run;

/**** Group 4: switcher_to_reference ****/
data adalimumab_claim_g4; set input.adalimumab_claim_v0; if patient_group = "switcher_to_reference"; run;
data adalimumab_claim_g4_pre; set adalimumab_claim_g4; if svc_dt < switch_date; run;  
data adalimumab_claim_g4_post; set adalimumab_claim_g4; if svc_dt >= switch_date; run;  


/*****************************
*  with separate data tables; insurance type
******************************

/**** Group 1: reference_lover ****/
* plan_type;
proc freq data=adalimumab_claim_g1 order=freq; table plan_type; title "Group 1 | Insurance type overall"; run;

* pay_type_description;
proc freq data=adalimumab_claim_g1 order=freq; table pay_type_description; title "Group 1 | Insurance type overall"; run;

* adjudicating_pbm_plan_name;
proc freq data=adalimumab_claim_g1 order=freq; table adjudicating_pbm_plan_name; title "Group 1 | Insurance type overall"; run;

* model_type;
proc freq data=adalimumab_claim_g1 order=freq; table model_type; title "Group 1 | Insurance type overall"; run;

* rejection rate in plan_type;
proc sql;
    select plan_type,
           count(*) as total_claims
    from adalimumab_claim_g1
    group by plan_type;
quit;

proc sql;
    select plan_type,
           count(*) as count_RJ
    from adalimumab_claim_g1
    where encnt_outcm_cd = 'RJ'
    group by plan_type;
quit;

* rejection rate in pay_type_description;
proc sql;
    select pay_type_description,
           count(*) as total_claims
    from adalimumab_claim_g1
    group by pay_type_description;
quit;

proc sql;
    select pay_type_description,
           count(*) as count_RJ
    from adalimumab_claim_g1
    where encnt_outcm_cd = 'RJ'
    group by pay_type_description;
quit;

* rejection rate in major PBM;
data adalimumab_claim_g1;
	set adalimumab_claim_g1;
 	length pbm $100;
  	retain pbm;
	if adjudicating_pbm_plan_name in ("OPTUMRX (PROC-UNSP)", "CAREMARK (PROC-UNSP)") then pbm = adjudicating_pbm_plan_name; 
 	else if index(upcase(adjudicating_pbm_plan_name), "EXPRESS") > 0 then pbm = adjudicating_pbm_plan_name; 
 	else pbm = "Others"; 
run;

proc sql;
    select pbm,
           count(*) as total_claims
    from adalimumab_claim_g1
    group by pbm;
quit;

proc sql;
    select pbm,
           count(*) as count_RJ
    from adalimumab_claim_g1
    where encnt_outcm_cd = 'RJ'
    group by pbm;
quit;


/**** Group 2: switcher_to_biosim ****/
data adalimumab_claim_g2_at_switching; set adalimumab_claim_g2; if svc_dt = switch_date; run;  

* plan_type;
proc freq data=adalimumab_claim_g2_at_switching order=freq; table plan_type; title "Group 2 | Insurance type at the switching date"; run;

* pay_type_description;
proc freq data=adalimumab_claim_g2_at_switching order=freq; table pay_type_description; title "Group 2 | Insurance type at the switching date"; run;

* adjudicating_pbm_plan_name;
proc freq data=adalimumab_claim_g2_at_switching order=freq; table adjudicating_pbm_plan_name; title "Group 2 | Insurance type at the switching date"; run;

* model_type;
proc freq data=adalimumab_claim_g2_at_switching order=freq; table model_type; title "Group 2 | Insurance type at the switching date"; run;

* rejection rate in plan_type;
proc sql;
    select plan_type,
           count(*) as total_claims
    from adalimumab_claim_g2_at_switching
    group by plan_type;
quit;

proc sql;
    select plan_type,
           count(*) as count_RJ
    from adalimumab_claim_g2_at_switching
    where encnt_outcm_cd = 'RJ'
    group by plan_type;
quit;

* rejection rate in pay_type_description;
proc sql;
    select pay_type_description,
           count(*) as total_claims
    from adalimumab_claim_g2_at_switching
    group by pay_type_description;
quit;

proc sql;
    select pay_type_description,
           count(*) as count_RJ
    from adalimumab_claim_g2_at_switching
    where encnt_outcm_cd = 'RJ'
    group by pay_type_description;
quit;

* rejection rate in major PBM;
data adalimumab_claim_g2_at_switching; 
	set adalimumab_claim_g2_at_switching; 
 	length pbm $100;
  	retain pbm;
	if adjudicating_pbm_plan_name in ("OPTUMRX (PROC-UNSP)", "CAREMARK (PROC-UNSP)") then pbm = adjudicating_pbm_plan_name; 
 	else if index(upcase(adjudicating_pbm_plan_name), "EXPRESS") > 0 then pbm = adjudicating_pbm_plan_name; 
 	else pbm = "Others"; 
run;

proc sql;
    select pbm,
           count(*) as total_claims
    from adalimumab_claim_g2_at_switching
    group by pbm;
quit;

proc sql;
    select pbm,
           count(*) as count_RJ
    from adalimumab_claim_g2_at_switching
    where encnt_outcm_cd = 'RJ'
    group by pbm;
quit;


/**** Group 3: biosim_lover ****/
data adalimumab_claim_g3_at_init; set adalimumab_claim_g2; by patient_id; if first.patient_id; run;

* plan_type;
proc freq data=adalimumab_claim_g3_at_init order=freq; table plan_type; title "Group 3 | Insurance type at biosimilar initiation"; run;

* pay_type_description;
proc freq data=adalimumab_claim_g3_at_init order=freq; table pay_type_description; title "Group 3 | Insurance type at biosimilar initiation"; run;

* adjudicating_pbm_plan_name;
proc freq data=adalimumab_claim_g3_at_init order=freq; table adjudicating_pbm_plan_name; title "Group 3 | Insurance type at biosimilar initiation"; run;

* model_type;
proc freq data=adalimumab_claim_g3_at_init order=freq; table model_type; title "Group 3 | Insurance type at biosimilar initiation"; run;

* rejection rate in plan_type;
proc sql;
    select plan_type,
           count(*) as total_claims
    from adalimumab_claim_g3_at_init
    group by plan_type;
quit;

proc sql;
    select plan_type,
           count(*) as count_RJ
    from adalimumab_claim_g3_at_init
    where encnt_outcm_cd = 'RJ'
    group by plan_type;
quit;

* rejection rate in pay_type_description;
proc sql;
    select pay_type_description,
           count(*) as total_claims
    from adalimumab_claim_g3_at_init
    group by pay_type_description;
quit;

proc sql;
    select pay_type_description,
           count(*) as count_RJ
    from adalimumab_claim_g3_at_init
    where encnt_outcm_cd = 'RJ'
    group by pay_type_description;
quit;

* rejection rate in major PBM;
data adalimumab_claim_g3_at_init;
	set adalimumab_claim_g3_at_init;
 	length pbm $100;
  	retain pbm;
	if adjudicating_pbm_plan_name in ("OPTUMRX (PROC-UNSP)", "CAREMARK (PROC-UNSP)") then pbm = adjudicating_pbm_plan_name; 
 	else if index(upcase(adjudicating_pbm_plan_name), "EXPRESS") > 0 then pbm = adjudicating_pbm_plan_name; 
 	else pbm = "Others"; 
run;

proc sql;
    select pbm,
           count(*) as total_claims
    from adalimumab_claim_g3_at_init
    group by pbm;
quit;

proc sql;
    select pbm,
           count(*) as count_RJ
    from adalimumab_claim_g3_at_init
    where encnt_outcm_cd = 'RJ'
    group by pbm;
quit;


/**** Group 4: switcher_to_reference ****/
data adalimumab_claim_g4_at_switching; set adalimumab_claim_g4; if svc_dt = switch_date; run;  

* plan_type;
proc freq data=adalimumab_claim_g4_at_switching order=freq; table plan_type; title "Group 4 | Insurance type at switching date"; run;

* pay_type_description;
proc freq data=adalimumab_claim_g4_at_switching order=freq; table pay_type_description; title "Group 4 | Insurance type at switching date"; run;

* adjudicating_pbm_plan_name;
proc freq data=adalimumab_claim_g4_at_switching order=freq; table adjudicating_pbm_plan_name; title "Group 4 | Insurance type at switching date"; run;

* model_type;
proc freq data=adalimumab_claim_g4_at_switching order=freq; table model_type; title "Group 4 | Insurance type at switching date"; run;


proc print data=adalimumab_claim_g2_at_switching (obs=30); 
var patient_id svc_dt switch_date category encnt_outcm_cd adjudicating_pbm_plan_name model_type pay_type_description plan_type plan_name; run;



proc print data=adalimumab_claim_g2 (obs=100); var patient_id svc_dt switch_date adjudicating_pbm_plan_name model_type pay_type_description plan_type plan_name; run;



/*****************************
*  with separate data tables; rejection rate
******************************

if encnt_outcm_cd = "RJ";

reason -> rjct_grp









/*****************************
*  insurance type at initiation
******************************
proc sort data=input.adalimumab_claim_v0; by patient_id svc_dt; run;
*remain useful variables;
data adalimumab_patient_plan; set input.adalimumab_claim_v0;
	keep patient_id patient_group svc_dt switch_date adjudicating_pbm_plan_name model_type pay_type_description plan_type plan_name; run;

* 1) Ensure svc_dt is a SAS date and normalize plan_type;
data adalimumab_patient_plan; set adalimumab_patient_plan;
    if vtype(svc_dt)='C' then do;
        svc_dt_d = input(svc_dt, mmddyy10.);
        format svc_dt_d yymmdd10.;
    end;
    else svc_dt_d = svc_dt;

    length plan_type_norm $60;
    plan_type_norm = strip(upcase(plan_type));
run;

/* Emit one row for the first plan, then one for each change in plan_type */
data adalimumab_patient_plan;
    set adalimumab_patient_plan;
    by patient_id svc_dt_d;

    length last_type $60 from_plan_type $60 to_plan_type $60;
    retain last_type;

    /* First record for patient: keep as initial plan event */
    if first.patient_id then do;
        plan_switch_date = svc_dt_d;
        from_plan_type   = '';
        to_plan_type     = plan_type_norm;
        output;
        last_type = plan_type_norm;
    end;
    else do;
        /* Output only when plan_type changes */
        if not missing(plan_type_norm) and plan_type_norm ne last_type then do;
            plan_switch_date = svc_dt_d;
            from_plan_type   = last_type;
            to_plan_type     = plan_type_norm;
            output;
            last_type = plan_type_norm;
        end;
    end;
    format plan_switch_date yymmdd10.;
run;

/* (Optional) If multiple claims exist on the same switch date & plan, dedupe */
proc sort data=adalimumab_patient_plan out=input.adalimumab_patient_plan nodupkey;
    by patient_id plan_switch_date to_plan_type;
run;
proc print data=adalimumab_patient_plan (obs=20); where patient_id = 116490214; run;

proc print data=input.adalimumab_claim_v0 (obs=30); 
var patient_id svc_dt switch_date category encnt_outcm_cd adjudicating_pbm_plan_name model_type pay_type_description plan_type plan_name;
where patient_id = 116490214 and year(svc_dt) = 2024 ; run;








