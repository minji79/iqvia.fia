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


/* merge all dataset */
data input.rx18_24_glp1_long_v00; set input.rx_24_glp1 input.rx_23_glp1 input.rx_22_glp1 input.rx_21_glp1 input.rx_20_glp1 input.rx_19_glp1 input.rx_18_glp1; run;
proc sort data=input.rx18_24_glp1_long_v00; by patient_id svc_dt; run;


* distinct number of patients (N= 1,061,808);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v00;
quit;


/*============================================================*
 | 4) only leave paitents who have at least one paid claims (N= 827,123 )
 *============================================================*/

proc sql;
    create table input.rx18_24_glp1_long_v01 as
    select *
    from input.rx18_24_glp1_long_v00 as a
    where a.patient_id in (
        select distinct patient_id
        from input.rx18_24_glp1_long_v00
        where encnt_outcm_cd = "PD"
    );
quit; /* 23,318,756 obs */

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v01;
quit; 


/*============================================================*
 | 5) first claim characteristics | first_claim (N= 951,434)
 *============================================================*/
* trial 1 | first_claim - remain only one of the first claim. if patients have multiple claims, only included paid one;

data first_claim;
    set input.rx18_24_glp1_long_v01;        
    if encnt_outcm_cd = "PD" then paid_priority = 1;  
    else paid_priority = 0;
run;

/* 2) Sort by patient → earliest svc_dt → prefer paid on that date */
proc sort data=first_claim; by patient_id svc_dt descending paid_priority; run;

/* 3) Keep the first record per patient (earliest date; paid preferred if tie) */
data input.first_claim;
    set first_claim;
    by patient_id svc_dt;
    if first.patient_id then output;
    drop paid_priority;
run; /* 827,123 obs */


/*****************************
*  retail channel
*****************************/
proc freq data=input.first_claim; table chnl_cd; run;
proc freq data=input.first_claim; table chnl_cd*plan_type /norow nopercent; run;

/*****************************
*  GLP1 types, indication
*****************************/
data input.first_claim; 
    length indication $20.;
    set input.first_claim;
    if upcase(molecule_name) in (
        "LIRAGLUTIDE (WEIGHT MANAGEMENT)",
        "SEMAGLUTIDE (WEIGHT MANAGEMENT)",
        "TIRZEPATIDE (WEIGHT MANAGEMENT)"
    ) then indication = "obesity"; 
    else indication = "non-obesity"; 
run;
data input.first_claim; 
    length molecule $50;   /* safer length */
    set input.first_claim;

    select (upcase(molecule_name));
        when ("LIRAGLUTIDE (WEIGHT MANAGEMENT)", "LIRAGLUTIDE") molecule = "LIRAGLUTIDE";
        when ("TIRZEPATIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE") molecule = "TIRZEPATIDE";
        when ("SEMAGLUTIDE (WEIGHT MANAGEMENT)", "SEMAGLUTIDE") molecule = "SEMAGLUTIDE";
        otherwise molecule = molecule_name;  /* keep original */
    end;
run;

proc freq data=first_claim; table molecule; run;
proc freq data=first_claim; table molecule*plan_type /norow nopercent; run;

/*****************************
*  OOP at index
*****************************/
*only remain valid rows for calculating OOP;
data oop;
    set input.first_claim;
    if final_opc_amt ne 0 and not missing(final_opc_amt) and encnt_outcm_cd = "RV" ;
run;
proc means data=oop n nmiss median q1 q3 min max; var final_opc_amt; run;
proc means data=oop n nmiss median q1 q3 min max;
    class plan_type;
    var final_opc_amt;
run;

/*****************************
*  reason of rejections
*****************************/
proc freq data=input.rx18_24_glp1_long_v01; table encnt_outcm_cd; run; /* all claim number */
proc freq data=input.rx18_24_glp1_long_v01; table encnt_outcm_cd*plan_type  /norow nopercent; run;

proc freq data=input.first_claim; table rjct_grp; run;
proc freq data=input.first_claim; table rjct_grp*plan_type  /norow nopercent; run;

proc freq data=input.first_claim; table encnt_outcm_cd; run;
proc freq data=input.first_claim; table encnt_outcm_cd*plan_type  /norow nopercent; run;



* among rejection;
data rejection; set input.first_claim; if rjct_grp ne 0; run;
proc freq data=rejection; table rjct_grp; run;
proc freq data=rejection; table rjct_grp*group  /norow nopercent;; run;

proc freq data=input.first_claim; table plan_type; run;
proc freq data=input.first_claim; table molecule_name; run;
proc freq data=input.first_claim; table molecule_name*plan_type; run;




/*============================================================*
 | 6) What happen on the first date of initiation? | first_claim_all
 *============================================================*/
data first_claim_all; set input.rx18_24_glp1_long_v00; if first.patient_id and first.svc_dt; run; 

* how many claims people have at the first date of dispense?;



/*============================================================*
 | Median days from first rejection to first approved fill (IQR)
 *============================================================*/
data rx18_24_glp1_long_v01;
    set input.rx18_24_glp1_long_v01;
    if encnt_outcm_cd = "PD" then fill = 1;
    else fill = 0;
run;

proc sort data=rx18_24_glp1_long_v01; by patient_id svc_dt; run;
data rx18_24_glp1_long_v02;
    set rx18_24_glp1_long_v01;
    by patient_id svc_dt;

    retain first0_date first1_date gap first_fill;
    format first0_date first1_date yymmdd10.;

    if first.patient_id then do;
        first0_date  = .;
        first1_date  = .;
        gap          = .;
        first_fill   = fill;   /* record the very first fill value */
    end;

    /* Only process patients whose first fill=0 */
    if first_fill = 0 then do;
        if fill=0 and missing(first0_date) then first0_date = svc_dt;  /* capture first date with fill=0 */        
        if fill=1 and missing(first1_date) then first1_date = svc_dt;  /* capture first date with fill=1 */
        if last.patient_id then do;
            if not missing(first0_date) and not missing(first1_date) then
                gap = first1_date - first0_date;
            else gap = .;
            output;
        end;

    end;
run; /* 331129 obs */

proc print data=rx18_24_glp1_long_v02 (obs=20); run;

*test;
proc means data=rx18_24_glp1_long_v02 n nmiss median q1 q3 min max; class group; var gap; run;

* if gap > 30, we con; 







/*============================================================*
 | 7) long data clean - one svc_dt can have only one row - paid priority
 *============================================================*/
 
data first_claim;
    set input.rx18_24_glp1_long_v01;        
    if rjct_grp = 0 then paid_priority = 1;   /* 1 if rjct_grp=0, else 0 */
    else paid_priority = 0;
run;

/* 2) Sort by patient → earliest svc_dt → prefer paid on that date */
proc sort data=first_claim; by patient_id svc_dt descending paid_priority; run;

/* 3) Keep the first record per patient (earliest date; paid preferred if tie) */
data first_claim;
    set first_claim;
    by patient_id svc_dt;
    if first.svc_dt then output;
    drop paid_priority;
run; /* 1,061,808 obs */

 
