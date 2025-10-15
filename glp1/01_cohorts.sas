/************************************************************************************
| Project name : Reduced Files of FIA data in YODA server
| Date (update): Aug 2025
| Task Purpose : 
|      1. To make personalized reduced-sized FIA datasets in YODA server
|      2. To identify prescription drugs, categorize claim rejection reason, and clean datasets
| Refer dataset : RxFact_2018_2024_small.dta
| Final dataset : 
************************************************************************************/


/*============================================================*
 | 1) Load raw claims 
 *============================================================*/
 * convert dta file to sas files; 
 %macro yearly(year=);
proc import 
    datafile="/dcs04/hpm/data/iqvia_fia/glp1_paper/data/Step1_Index_&year._glp_ER.dta"
    out=input.rx_&year._glp1 
    dbms=dta 
    replace;
run;
%mend yearly;
%yearly(year=24);
%yearly(year=23);
%yearly(year=22);
%yearly(year=21);
%yearly(year=20);
%yearly(year=19);
%yearly(year=18);

/* import 2017 data */
data rx_17_glp1; set biosim.rxfact2018; if year(svc_dt) = 2017; run; /* 214718703 obs */

data glp1; set biosim.product; if molecule_name in ("DULAGLUTIDE", "EXENATIDE", "LIRAGLUTIDE", "LIRAGLUTIDE (WEIGHT MANAGEMENT)", "LIXISENATIDE",
"SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)"); run;

proc sql;
  create table input.rx_17_glp1 as
  select a.*, 
         b.molecule_name, 
         b.package_size, 
         b.strength
  from rx_17_glp1 as a
  inner join glp1 as b
    on a.ndc = b.product_ndc;
quit; /* 854,405 */


proc contents data=input.rx_24_glp1; run;
proc print data=biosim.product (obs=5); run;

proc freq data=input.rx_17_glp1; table molecule_name; run;

/* merge with from LevyPDRJRV */
%macro yearly(year=);
proc sql; 
  create table input.rx_&year._glp1 as
  select distinct a.*, b.encnt_outcm_cd
  from input.rx_&year._glp1 as a 
  left join input.LevyPDRJRV as b
  on a.claim_id = b.claim_id;
quit;

proc sort data=input.rx_&year._glp1 nodupkey; by claim_id; run;

%mend yearly;
%yearly(year=24);
%yearly(year=23);
%yearly(year=22);
%yearly(year=21);
%yearly(year=20);
%yearly(year=19);
%yearly(year=18);
%yearly(year=17);

/*============================================================*
 | 2) Classify rejection group (rjct_grp) & encounter flags
 *============================================================*/
/*
rjct_grp=0 | Group 0: Successful Fill
rjct_grp=1 | Group 1: Step Edit
rjct_grp=2 | Group 2: Prior Auth
rjct_grp=3 | Group 3: Not Covered
rjct_grp=4 | Group 4: Plan Limit
rjct_grp=5 | Group 5: Non-formulary or Others
*/

%macro yearly(year=);
data input.rx_&year._glp1;
  set input.rx_&year._glp1;
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

  /* Flags from encnt_ */ 
  PD = (encnt_='PD'); 
  RV = (encnt_='RV'); 
  RJ_Step = (encnt_='RJ' and rjct_grp=1); 
  RJ_PrAu = (encnt_='RJ' and rjct_grp=2); 
  RJ_NtCv = (encnt_='RJ' and rjct_grp=3); 
  RJ_PlLm = (encnt_='RJ' and rjct_grp=4); 
  RJ_NotForm = (encnt_='RJ' and rjct_grp=5); 

run;

%mend yearly;
%yearly(year=24); /* 8299618 obs, with 50 variables */
%yearly(year=23); /* 6273028 obs */
%yearly(year=22); /* 3287046 obs */
%yearly(year=21); /* 2189023 obs */
%yearly(year=20); /* 1754725 obs */
%yearly(year=19); /* 1453451 obs */
%yearly(year=18); /* 1176157 obs */
%yearly(year=17); /* 854405 obs */


/*============================================================*
 | 3) Merge plan; classify plan_type and numeric pln_typ (N= 1,061,808)
 *============================================================*/
%macro yearly(year=);
proc sql;
  create table input.rx_&year._glp1 as
  select a.*, b.model_type, b.plan_name
  from input.rx_&year._glp1 a
  inner join biosim.plan b
    on a.plan_id=b.plan_id;
quit;

data input.rx_&year._glp1;
  set input.rx_&year._glp1;
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

%mend yearly;
%yearly(year=24); /* 8299618 -> 8299345 obs, with 53 variables */
%yearly(year=23); /* 6273028 -> 6273028 obs */
%yearly(year=22); /* 3287046 -> 3287046 obs */
%yearly(year=21); /* 2189023 obs - same */
%yearly(year=20); /* 1754725 obs */
%yearly(year=19); /* 1453451 obs */
%yearly(year=18); /* 1176157 obs */
%yearly(year=17);

* align with the data type of daw_cd; 
%macro yearly(year=);
data input.rx_&year._glp1;
    set input.rx_&year._glp1;
    length daw_cd_num 8;
    if vtype(daw_cd) = 'C' then
        daw_cd_num = input(strip(daw_cd), ?? best32.);
    else
        daw_cd_num = daw_cd;
    drop daw_cd;
    rename daw_cd_num = daw_cd;
run;

%mend yearly;
%yearly(year=24);
%yearly(year=23); 
%yearly(year=22);
%yearly(year=21);
%yearly(year=20); 
%yearly(year=19); 
%yearly(year=18);
%yearly(year=17);

data input.rx_17_glp1; set input.rx_17_glp1; year = year(svc_dt); run;

/* merge all dataset */
data input.rx18_24_glp1_long_v00; set input.rx_24_glp1 input.rx_23_glp1 input.rx_22_glp1 input.rx_21_glp1 input.rx_20_glp1 input.rx_19_glp1 input.rx_18_glp1 input.rx_17_glp1; run;
proc sort data=input.rx18_24_glp1_long_v00; by patient_id svc_dt; run;

* distinct number of patients (N= 1,079,177);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v00;
quit;

/*============================================================*
 | 4) exclude "LIXISENATIDE", "ALBIGLUTIDE" and invalid data in molecule_name 
 *============================================================*/
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if molecule_name not in ("LIXISENATIDE", "ALBIGLUTIDE"); run; /* - 16929 */

* distinct number of patients (N= 1078969);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v00;
quit;

* check ndc codes for glp1;
proc contents data=input.rx18_24_glp1_long_v00; run;
data ndc; set input.rx18_24_glp1_long_v00; keep molecule_name ndc; run;
proc sort data=ndc nodupkey; by _all_; run; 
proc sort data=ndc; by molecule_name; run;


/*============================================================*
 | 5) merge with age file  
 *============================================================*/
* clean the patient_birth_year;
proc sql;
    create table id_age as
    select distinct patient_id, max(patient_birth_year) as patient_birth_year
    from biosim.patient
    group by patient_id;
quit; /* 12170856 obs */

proc sql;
    select count(distinct patient_id) as id_count
    from id_age;
quit; /* 12170856 obs */

* merge with the dataset without duplication;
proc sql; 
	create table input.rx18_24_glp1_long_v00 as
 	select a.*, b.patient_birth_year
    from input.rx18_24_glp1_long_v00 as a
	left join id_age as b
 	on a.patient_id = b.patient_id;
 quit; /* 25,287,180 */

* calculate age at initiation and make invalid data null;
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00;  age_at_claim = year - patient_birth_year; run;
proc means data=input.rx18_24_glp1_long_v00 n nmiss min max mean std median q1 q3; var age_at_claim; run;

/*============================================================*
 | 5) exclude invalid data in molecule_name 
 *============================================================*/
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if not missing(molecule_name); run; /* - 39 */


 /*============================================================*
 | 6) exclude claims with age < 18
 *============================================================*/
 * adults: 18 <= age_at_claim < 120;
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if 18 <= age_at_claim; run;
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if age_at_claim < 120; run;

/* 25,047,990 obs*/

* distinct number of adult patients before excluding reversed and rejected claims (N= 1066899);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v00;
quit;


/*============================================================*
 | 7) 180 days wash out period (from patient level dataset: exclude individual whose first claim was in between Jan 2017 and May 2017)
 *============================================================*/

/* go and get patient_v0 file*/
proc sort data=input.rx18_24_glp1_long_v00;  by patient_id svc_dt; run;
proc sort data=input.rx18_24_glp1_long_v00 out=rx_sorted;
    by patient_id svc_dt;
run;

data patients_duration; 
    set input.rx18_24_glp1_long_v00;
    by patient_id;
    retain first_date;
    format first_date yymmdd10.;    
    if first.patient_id then first_date = svc_dt;   /* earliest svc_dt */
    if last.patient_id then output;                /* one row per patient */
run; 

proc print data=patients_duration (obs=10); run;

/* remain if patient's first_date > "30JUN2017"d */
proc sql;
	create table input.rx18_24_glp1_long_v00 as
	select *
	from input.rx18_24_glp1_long_v00 as a
	where a.patient_id in (
		select patient_id
		from patients_duration
		where first_date > "30JUN2017"d
	);
quit; /* 21,595,225 obs */

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v00;
quit;  /* 984,398 individuals */

/*============================================================*
 | 8) exclude not-final claim per unit prescription (- 10,595,606 | cohort 1 = 1-,999,619 at transaction level)
 *============================================================*/
proc freq data=input.rx18_24_glp1_long_v00; table final_claim_ind; run;
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if final_claim_ind = 'Y'; run;
 
/*============================================================*
 | 9) add glp1 indication based on molecule_name & molecule
 *============================================================*/

data input.rx18_24_glp1_long_v00;
    set input.rx18_24_glp1_long_v00;
    length indication $20.;
    
    if upcase(molecule_name) in (
        "LIRAGLUTIDE (WEIGHT MANAGEMENT)",
        "SEMAGLUTIDE (WEIGHT MANAGEMENT)",
        "TIRZEPATIDE (WEIGHT MANAGEMENT)"
    ) then indication = "obesity"; 
    else indication = "diabetes"; 
run;

data input.rx18_24_glp1_long_v00;
    set input.rx18_24_glp1_long_v00;
    length molecule $50;

    select (upcase(molecule_name));
        when ("LIRAGLUTIDE (WEIGHT MANAGEMENT)", "LIRAGLUTIDE") molecule = "LIRAGLUTIDE";
        when ("TIRZEPATIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE") molecule = "TIRZEPATIDE";
        when ("SEMAGLUTIDE (WEIGHT MANAGEMENT)", "SEMAGLUTIDE") molecule = "SEMAGLUTIDE";
        otherwise molecule = molecule_name;  /* keep original */
    end;
run;


/*****************************
*  10) add States & region based on zip codes
*****************************/

data input.rx18_24_glp1_long_v00;
    set input.rx18_24_glp1_long_v00;

    length state $2 region $10;
    zip = put(provider_zip, z5.);
    state = zipstate(zip);

    /* Map state to region */
    select (state);
      when ('ME','NH','VT','MA','RI','CT','NY','NJ','PA') region='Northeast';
      when ('OH','IN','IL','MI','WI','MN','IA','MO','ND','SD','NE','KS') region='Midwest';
      when ('DE','MD','DC','VA','WV','NC','SC','GA','FL','KY','TN','AL','MS','AR','LA','OK','TX') region='South';
      when ('MT','ID','WY','CO','NM','AZ','UT','NV','WA','OR','CA','AK','HI') region='West';
      otherwise region='Unknown';
    end;
run; /* 10,999,619 obs */

/*****************************
*  11) add patients gender
*****************************/
/* 1) make patient - gender table without any duplication */
* clean the data;
data gender; set biosim.patient; keep patient_id patient_gender; run;
proc sort data=gender nodupkey; by patient_id; run; /* 12170856 obs */

* see the duplicated patient_id rows;
proc sql;
    create table gender_conflict as
    select patient_id,
           /* has_f = 1 if any F; has_m = 1 if any M */
           (sum(upcase(coalesce(patient_gender, '')) = 'F') > 0) as has_f,
           (sum(upcase(coalesce(patient_gender, '')) = 'M') > 0) as has_m
    from gender
    group by patient_id
    ;
quit;

data gender_conflict;
    set gender_conflict;
    invalid_gender = (has_f = 1 and has_m = 1);
    keep patient_id invalid_gender;
run;

proc sql;
    create table gender as
    select a.*,
           case when b.invalid_gender = 1 then 'invalid'
                else a.patient_gender
           end as patient_gender_clean
    from gender as a
    left join gender_conflict as b
      on a.patient_id = b.patient_id
    ;
quit; 
proc sort data=gender nodupkey; by patient_id; run;
data gender; set gender (drop=patient_gender); rename patient_gender_clean = patient_gender; run; /* 12170856 obs */

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from gender;
quit; 

/* 2) merge with our dataset */
proc sql; 
	create table input.rx18_24_glp1_long_v00 as
 	select distinct a.*, b.patient_gender
    from input.rx18_24_glp1_long_v00 as a
	left join gender as b
 	on a.patient_id = b.patient_id;
quit; /* 10,999,619 obs*/

/*============================================================*
 | 12) **** update payer_type ****
 *============================================================*/
* merge with plan file;
proc sql;
    create table input.rx18_24_glp1_long_v00 as
    select a.*, b.model_type_name
    from input.rx18_24_glp1_long_v00 as a
    left join biosim.plan as b
      on a.plan_id = b.plan_id
    ;
quit;
data check; set input.rx18_24_glp1_long_v00; if missing(plan_id); run; /* 1443 obs */

* categorize - payer_payer; 
data input.rx18_24_glp1_long_v00; 
    set input.rx18_24_glp1_long_v00; 
    length payer_type payer_type_indicator $100.;
    payer_type = "";
    payer_type_indicator = "";

    select (upcase(model_type_name));
        when ("MEDICARE D UNSPECIFIED", 
              "EMPLOYER-SPONSORED PBM RETIREE PRESCRIPTION DRUG PROGRAM",
              "GENERAL MEDICARE D SPECIAL NEEDS PLAN",
              "MEDICARE D SPECIAL NEEDS PLAN",
              "DUAL ELIGIBLE MEDICARE MEDICAID PLAN",
              "MEDICARE")
              do; payer_type = "Medicare D: Unspec"; payer_type_indicator = "dominant_payer"; end;

        when ("GENERAL MEDICARE D PRESCRIPTION DRUG PROGRAM",
              "MEDICARE D PRESCRIPTION DRUG PROGRAM - PLAN SPECIFIC")
              do; payer_type = "Medicare D: TM"; payer_type_indicator = "dominant_payer"; end;

        when ("GENERAL MEDICARE D ADVANTAGE",
              "MEDICARE D ADVANTAGE - PLAN SPECIFIC")
              do; payer_type = "Medicare D: ADV"; payer_type_indicator = "dominant_payer"; end;

        when ("MANAGED MEDICAID/MEDICARE SUPPLEMENT/MEDIGAP/STATE ASSISTANCE",
              "WORKER'S COMPENSATION",
              "STATE ASSISTANCE PROGRAM",
              "CHILDRENS HEALTH INSURANCE PROGRAM")
              do; payer_type = "Medicaid: Unspec"; payer_type_indicator = "dominant_payer"; end;

        when ("FEE FOR SERVICE MEDICAID") 
              do; payer_type = "Medicaid: FFS"; payer_type_indicator = "dominant_payer"; end;

        when ("MANAGED MEDICAID") 
              do; payer_type = "Medicaid: MCO"; payer_type_indicator = "dominant_payer"; end;

        when ("Employer","EMPLOYER","STATE EMPLOYEES","FEDERAL EMPLOYEE",
              "EMPLOYER-SPONSORED CMS RETIREE PRESCRIPTION DRUG PROGRAM")
              do; payer_type = "Commercial"; payer_type_indicator = "dominant_payer"; end;

        when ("EXCHANGE","HEALTH INSURANCE EXCHANGE EPO GENERAL",
              "HEALTH INSURANCE EXCHANGE GENERAL","HEALTH INSURANCE EXCHANGE HMO",
              "HEALTH INSURANCE EXCHANGE POS GENERAL",
              "HEALTH INSURANCE EXCHANGE PPO GENERAL")
              do; payer_type = "Exchange"; payer_type_indicator = "dominant_payer"; end;

        when ("CASH") do; payer_type = "Cash"; payer_type_indicator = "secondary_payer"; end;
        when ("COUPON/VOUCHER PROGRAM") do; payer_type = "Coupon"; payer_type_indicator = "secondary_payer"; end;
		when ("UNSPECIFIED PLAN") do; payer_type = "Unspec"; payer_type_indicator = "secondary_payer"; end;
		when ("MEDICARE B") do; payer_type = "Part B"; payer_type_indicator = "secondary_payer"; end;

        when ("PHARMACY BENEFIT MANAGER", 
              "PBM BOOK OF BUSINESS - UNIDENTIFIED PLANS")
              do; payer_type = "PBM"; payer_type_indicator = "secondary_payer"; end;

        when ("DISCOUNT CARD PROGRAM") 
              do; payer_type = "Discount Card"; payer_type_indicator = "secondary_payer"; end;
			  
		when ("HMO",
			  "PREFERRED PROVIDER ORGANIZATION",
			  "EXCLUSIVE PROVIDER ORGANIZATION",
			  "HMO - COMBINATION MODEL",
			  "HMO - GROUP PRACTICE MODEL",
			  "HMO - INDEPENDENT PRACTICE ASSOCIATION MODEL",
			  "HMO - NETWORK MODEL",
			  "HMO - STAFF MODEL")
              do; payer_type = "PPO/HMO"; payer_type_indicator = "secondary_payer"; end;
			  
		when ("HEALTH INSURANCE EXCHANGE HMO GENERAL",
		      "BEHAVIORAL HEALTH",
			  "CONSUMER DIRECTED HEALTH PLAN",
			  "THIRD PARTY ADMINISTRATOR",
			  "CLAIMS PROCESSOR",
			  "THIRD PARTY",
			  "FEDERAL ASSISTANCE PROGRAM",
			  "NON-HMO",
			  "POINT OF SERVICE",
			  "UNKNOWN THIRD PARTY")
              do; payer_type = "PPO/HMO"; payer_type_indicator = "secondary_payer"; end;
			  
        otherwise do; payer_type = "missing"; payer_type_indicator = "missing"; end;
    end;
run;

 
/*============================================================*
 | 13) only remain paitents who have at least one paid claims (N= 768,646 individuals, 20,496,809 obs)
 *============================================================*/

* identify; 
proc sql; 
  create table disposition as
  select
    	 patient_id,
         sum(case when encnt_outcm_cd = "PD" then 1 else 0 end) as count_PD, 
		 sum(case when encnt_outcm_cd = "RV" then 1 else 0 end) as count_RV, 
		 sum(case when encnt_outcm_cd = "RJ" then 1 else 0 end) as count_RJ
  
  from input.rx18_24_glp1_long_v00
  group by patient_id;
quit;

data input.disposition; set disposition; if count_PD = 0 then no_PD_ever = 1; else no_PD_ever = 0; run;
data input.disposition; set input.disposition; if count_PD = 0 and count_RV = 0 then no_PD_only_RJ = 1; else no_PD_only_RJ = 0; run;
proc print data=input.disposition (obs=30); run;

proc sql; 
    select count(distinct patient_id) as total_patient_number
    from input.disposition;
quit; /* 984,398 individuals */

proc sql; 
    select count(distinct patient_id) as no_PD_ever
    from input.disposition
	where no_PD_ever =1;
quit; /* 215,752 individuals */

proc sql; 
    select count(distinct patient_id) as no_PD_only_RJ 
    from input.disposition
	where no_PD_only_RJ =1;
quit;  /* 112,592 individuals */



* excluded them from cohort;
proc sql;
    create table input.rx18_24_glp1_long_v01 as
    select *
    from input.rx18_24_glp1_long_v00 as a
    where a.patient_id in (
        select distinct patient_id
        from input.disposition
        where no_PD_ever = 0
    );
quit; /* 10,617,368 obs */

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v01;
quit;  /* 768,646 individuals */

* check row data;
proc print data=input.rx18_24_glp1_long_v00 (obs=30); where patient_id = 568700; var patient_id svc_dt encnt_outcm_cd plan_type plan_id; run;
