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


/* merge all dataset */
data input.rx18_24_glp1_long_v00; set input.rx_24_glp1 input.rx_23_glp1 input.rx_22_glp1 input.rx_21_glp1 input.rx_20_glp1 input.rx_19_glp1 input.rx_18_glp1 input.rx_17_glp1; run;
proc sort data=input.rx18_24_glp1_long_v00; by patient_id svc_dt; run;

proc print data=input.rx_17_glp1 (obs=20); run;


* distinct number of patients (N= 1,061,808);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v00;
quit;


/*============================================================*
 | 4) merge with age file  
 *============================================================*/
* clean the patient_birth_year;
proc sql;
    create table id_age as
    select distinct patient_id, max(patient_birth_year) as patient_birth_year
    from biosim.patient
    group by patient_id;
quit; /* 12170856 obs */
proc means data=id_age n nmiss min max mean std median q1 q3; var patient_birth_year; run;

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
 quit; /* 24,432,775 */

* calculate age at initiation and make invalid data null;
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00;  age_at_claim = year - patient_birth_year; run;
/* proc means data=input.rx18_24_glp1_long_v00 n nmiss min max mean std median q1 q3; var age_at_claim; run; */


/*============================================================*
 | 5) exclude invalid data in plan_id OR molecule_name 
 *============================================================*/
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if not missing(plan_id); run; /* - 1926 */
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if not missing(molecule_name); run; /* - 39 */

 /*============================================================*
 | 6) exclude claims with age < 18
 *============================================================*/
 * adults: 18 <= age_at_claim < 120;
 data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if 18 <= age_at_claim < 120; run; /* 24432775 -> 24,396,384 (18 under) -> 24,222,502 (invalid information)*/

/* 24,220,537 obs*/

/*============================================================*
 | 7) only leave paitents who have at least one approved claims (N= 940,621)
 *============================================================*/
proc sql;
    create table input.rx18_24_glp1_long_v01 as
    select *
    from input.rx18_24_glp1_long_v00 as a
    where a.patient_id in (
        select distinct patient_id
        from input.rx18_24_glp1_long_v00
        where rjct_grp=0
    );
quit; /* 24,220,537 -> 23,709,951 obs */

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v01;
quit;  /* 940,621 individuals */

/*============================================================*
 | 7) only leave paitents who have at least one paid claims (N= 817,897)
 *============================================================*/
proc sql;
    create table input.rx18_24_glp1_long_v01 as
    select *
    from input.rx18_24_glp1_long_v01 as a
    where a.patient_id in (
        select distinct patient_id
        from input.rx18_24_glp1_long_v00
        where encnt_outcm_cd = "PD"
    );
quit; /* 23,709,951 -> 23,117,173 obs*/

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v01;
quit;  /* 817,897 individuals */


/*============================================================*
 | 8) add glp1 indication based on molecule_name & molecule
 *============================================================*/

data input.rx18_24_glp1_long_v01;
    set input.rx18_24_glp1_long_v01;
    length indication $20.;
    
    if upcase(molecule_name) in (
        "LIRAGLUTIDE (WEIGHT MANAGEMENT)",
        "SEMAGLUTIDE (WEIGHT MANAGEMENT)",
        "TIRZEPATIDE (WEIGHT MANAGEMENT)"
    ) then indication = "obesity"; 
    else indication = "non-obesity"; 
run;

data input.rx18_24_glp1_long_v01;
    set input.rx18_24_glp1_long_v01;
    length molecule $50;

    select (upcase(molecule_name));
        when ("LIRAGLUTIDE (WEIGHT MANAGEMENT)", "LIRAGLUTIDE") molecule = "LIRAGLUTIDE";
        when ("TIRZEPATIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE") molecule = "TIRZEPATIDE";
        when ("SEMAGLUTIDE (WEIGHT MANAGEMENT)", "SEMAGLUTIDE") molecule = "SEMAGLUTIDE";
        otherwise molecule = molecule_name;  /* keep original */
    end;
run;


