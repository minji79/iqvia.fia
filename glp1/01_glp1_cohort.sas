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


/* check identical */
proc contents data=input.rx_24_glp; run;
proc contents data=mydata2; run;


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

/* merge with from LevyPDRJRV */
proc import 
    datafile="/dcs07/hpm/data/iqvia_fia/full_raw/LevyPDRJRV.dta"
    out=input.LevyPDRJRV
    dbms=dta 
    replace;

proc contents data=input.LevyPDRJRV; run;


%macro yearly(year=);
proc sql; 
  create table rx_&year._glp1 as
  select distinct a.*, b.
  from input.rx_&year._glp1 as a 
  left join input.LevyPDRJRV as b
  on a.claim_id = b.claim_id;
quit;

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

proc print data=input.rx18_24_glp1_long_v00 (obs=30); run;

* distinct number of patients (N= 1,061,808);
proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v00;
quit;

/*============================================================*
 | 4) only leave paitents who have at least one paid claims (N= 951,434)
 *============================================================*/

proc sql;
    create table input.rx18_24_glp1_long_v01 as
    select *
    from input.rx18_24_glp1_long_v00 as a
    where a.patient_id in (
        select distinct patient_id
        from input.rx18_24_glp1_long_v00
        where rjct_grp = 0
    );
quit;

proc sql; 
    select count(distinct patient_id) as count_patient_all
    from input.rx18_24_glp1_long_v01;
quit; 


/*============================================================*
 | 5) first claim characteristics 
 *============================================================*/
* trial 1 | first_claim - remain only one of the first claim. if patients have multiple claims, only included paid one;

data first_claim;
    set input.rx18_24_glp1_long_v01;        
    paid_priority = (rjct_grp = 0 and );   /* 0 if rjct_grp=0, else 1 */
run;

/* 2) Sort by patient → earliest svc_dt → prefer paid on that date */
proc sort data=first_claim; by patient_id svc_dt paid_priority; run;

/* 3) Keep the first record per patient (earliest date; paid preferred if tie) */
data first_claim;
    set first_claim;
    by patient_id;
    if first.patient_id then output;
    drop paid_priority;
run; /* 1,061,808 obs */

data input.first_claim; set first_claim; run;
proc freq data=input.first_claim; table rjct_grp; run;
proc freq data=input.first_claim; table plan_type; run;
proc freq data=input.first_claim; table molecule_name; run;

data first_claim_all; set input.rx18_24_glp1_long_v00; if first.patient_id and first.svc_dt; run; 


/*============================================================*
 | 5) First drug day per (patient, molecule); collapse sums
 *============================================================*/
proc sql;
  create table work.first_day as
  select patient_id, molecule_name, min(svc_dt) as first_drug_day format=date9.
  from work.claims2
  group by patient_id, molecule_name;
quit;

proc sql;
  create table work.index_only as
  select a.*
  from work.claims2 a
  inner join work.first_day b
    on a.patient_id=b.patient_id and a.molecule_name=b.molecule_name
   and a.svc_dt=b.first_drug_day;
quit;

/* collapse sums by patient, molecule, branded_generic, usc_5, svc_dt, pln_typ */
proc summary data=work.index_only nway;
  class patient_id molecule_name branded_generic usc_5 svc_dt pln_typ;
  var PD RV RJ_Step RJ_PrAu RJ_NtCv RJ_PlLm RJ_NotForm;
  output out=work.collapsed(drop=_type_ _freq_) sum=;
run;

/* Create sequence within day for “reshape wide” */
proc sort data=work.collapsed;
  by patient_id molecule_name svc_dt pln_typ;
run;

data work.coll_seq;
  set work.collapsed;
  by patient_id molecule_name svc_dt;
  if first.svc_dt then count=1; else count+1;
run;

proc sort data=work.coll_seq;
  by patient_id molecule_name branded_generic usc_5 svc_dt count;
run;

/* Reshape wide to 7 columns (PD1..PD7 etc.) */
data work.wide;
  set work.coll_seq;
  by patient_id molecule_name branded_generic usc_5 svc_dt;

  array PDv[7]        PD1-PD7;
  array RVv[7]        RV1-RV7;
  array RJ_Stepv[7]   RJ_Step1-RJ_Step7;
  array RJ_PrAuv[7]   RJ_PrAu1-RJ_PrAu7;
  array RJ_NtCvv[7]   RJ_NtCv1-RJ_NtCv7;
  array RJ_PlLmv[7]   RJ_PlLm1-RJ_PlLm7;
  array RJ_NFv[7]     RJ_NotForm1-RJ_NotForm7;
  array PTv[7]        pln_typ1-pln_typ7;

  retain PD1-PD7 RV1-RV7 RJ_Step1-RJ_Step7 RJ_PrAu1-RJ_PrAu7
         RJ_NtCv1-RJ_NtCv7 RJ_PlLm1-RJ_PlLm7 RJ_NotForm1-RJ_NotForm7
         pln_typ1-pln_typ7;

  if first.svc_dt then do i=1 to 7;
    PDv[i]=.; RVv[i]=.; RJ_Stepv[i]=.; RJ_PrAuv[i]=.;
    RJ_NtCvv[i]=.; RJ_PlLmv[i]=.; RJ_NFv[i]=.; PTv[i]=.;
  end;

  if 1<=count<=7 then do;
    PDv[count]=PD; RVv[count]=RV; RJ_Stepv[count]=RJ_Step; RJ_PrAuv[count]=RJ_PrAu;
    RJ_NtCvv[count]=RJ_NtCv; RJ_PlLmv[count]=RJ_PlLm; RJ_NFv[count]=RJ_NotForm;
    PTv[count]=pln_typ;
  end;

  if last.svc_dt then output;
  drop PD RJ_: RV pln_typ i count;
run;

/* row_count = number of nonmissing plan slots */
data work.wide2;
  set work.wide;
  array PT[7] pln_typ1-pln_typ7;
  row_count=0; do i=1 to 7; if not missing(PT[i]) then row_count+1; end; drop i;
run;

/* any_paid flags */
data work.wide2;
  set work.wide2;
  array PT[7] pln_typ1-pln_typ7;
  array PDv[7] PD1-PD7;
  any_paid_cash=0; any_paid_voucher=0; any_paid_disccard=0;
  do k=1 to 7;
    if PT[k]=1 and PDv[k]>0 then any_paid_cash=1;
    if PT[k]=2 and PDv[k]>0 then any_paid_voucher=1;
    if PT[k]=3 and PDv[k]>0 then any_paid_disccard=1;
  end;
run;

/* Drop rows with 3+ payers (as in Stata) */
data work.wide2; set work.wide2; if row_count>=3 then delete; run;

/* If first payer is cash/discount/voucher, copy slot 2 into slot 1, then reassign plan */
data work.wide2;
  set work.wide2;

  if pln_typ1 in (1,2,3) then do;
    PD1=PD2; RJ_Step1=RJ_Step2; RJ_PrAu1=RJ_PrAu2; RJ_NtCv1=RJ_NtCv2;
    RJ_PlLm1=RJ_PlLm2; RV1=RV2; RJ_NotForm1=RJ_NotForm2;
  end;

  if pln_typ1 in (1,2,3) and not missing(pln_typ2) then pln_typ1=pln_typ2;

  /* Drop remaining cash/discount/voucher as payer of record */
  if pln_typ1 in (1,2,3) then delete;

  length final_payer $20;
  final_payer=put(pln_typ1, plntyp_fmt.);
run;

/* final_day */
data work.index_final;
  set work.wide2;
  length final_day $24;
  if PD1>0 then final_day='Fill';
  if PD1=0 and sum(RJ_Step1,RJ_PrAu1,RJ_NtCv1,RJ_PlLm1)>0 then final_day='FormularyReject';
  if PD1>0 and sum(RJ_Step1,RJ_PrAu1,RJ_NtCv1,RJ_PlLm1)>0 then final_day='FormularyReject+Fill';
  if RV1>0 and PD1=0 and sum(RJ_Step1,RJ_PrAu1,RJ_NtCv1,RJ_PlLm1)=0 then final_day='SoleReversal';
  if RJ_NotForm1>0 and final_day='' then final_day='SoleNonFormRej';

  year=year(svc_dt);
run;

/* Molecule-year brand/generic/TS counts */
proc sql;
  create table work.by_moly as
  select molecule_name, year,
         sum(branded_generic='G') as count_generics,
         sum(branded_generic='B') as count_brands,
         sum(branded_generic='T') as count_ts
  from work.index_final
  group by molecule_name, year;
quit;

proc sql;
  create table work.index_final2 as
  select a.*, b.count_generics, b.count_brands, b.count_ts
  from work.index_final a
  left join work.by_moly b
    on a.molecule_name=b.molecule_name and a.year=b.year;
quit;

/* Keep molecules with no generic that year */
data "&WP2";
  set work.index_final2;
  if count_generics=0;
run;

/*============================================================*
 | 5) Restrict & 0–90-day follow-up
 *============================================================*/
data work.rj_only;
  set "&WP2";
  if final_day in ('FormularyReject','FormularyReject+Fill','SoleReversal');
  i_svc_dt = svc_dt;
  i_molecule_name = molecule_name;
  i_branded_generic = branded_generic;
  day0=i_svc_dt; day90=intnx('day',i_svc_dt,90);
  format day0 day90 date9.;
  /* drop higher suffixes as in Stata */
  drop pln_typ3-pln_typ7 RJ_NotForm2-RJ_NotForm7 RJ_Step2-RJ_Step7
       RJ_PrAu2-RJ_PrAu7 RJ_NtCv2-RJ_NtCv7 RJ_PlLm2-RJ_PlLm7
       PD2-PD7 RV2-RV7;
run;

data "&WP3"; set work.rj_only; run;

/* Join back to WP1 on patient_id & usc_5; keep 0–90 days */
proc sql;
  create table work.post90 as
  select a.*,
         b.svc_dt as svc_dt2 format=date9.,
         (b.svc_dt - a.i_svc_dt) as days_from_index
  from work.rj_only a
  inner join "&WP1"n b
    on a.patient_id=b.patient_id and a.usc_5=b.usc_5
  where calculated days_from_index between 0 and 90;
quit;

data "&WP4"; set work.post90; run;

/*============================================================*
 | 6) Final analytic filters & save
 *============================================================*/
data work.final;
  set "&WP4";
  if year=2017 then delete;
  if upcase(molecule_name)='NIRMATRELVIR-RITONAVIR' then delete;
  if usc_5=82250 then delete;            /* covid */
  if final_payer='Other' then delete;
  if missing(final_payer) then delete;
run;

/* Drop molecules with <=1000 obs */
proc sql;
  create table work.mol_ct as
  select molecule_name, count(*) as molecule_count
  from work.final
  group by molecule_name;
quit;

proc sql;
  create table "&WP5" as
  select a.*
  from work.final a
  inner join work.mol_ct b
    on a.molecule_name=b.molecule_name
  where b.molecule_count>1000;
quit;

/* month variable like Stata mofd() + %tm */
data "&WP5";
  set "&WP5";
  month=intnx('month', svc_dt, 0, 'b');
  format month yymmn6.;
run;

/*============================================================*
 | (Optional) Ravi’s analysis sketch in SAS
 *============================================================*/
/*
data work.wp2_med;
  set "&WP2";
  if index(upcase(final_payer),'MEDICARE')>0;
run;

data work.top10;
  set work.wp2_med;
  length top10 3; top10=0;
  if find(molecule_name,'APIXABAN','i') or find(molecule_name,'EMPAGLIFLOZIN','i') or
     find(molecule_name,'SITAGLIPTIN','i') or find(molecule_name,'DAPAGLIFLOZIN','i') or
     find(molecule_name,'RIVAROXABAN','i') or find(molecule_name,'ETANERCEPT','i') or
     find(molecule_name,'USTEKINUMAB','i') or find(molecule_name,'SACUBITRIL','i') or
     find(molecule_name,'IBRUTINIB','i') or find(molecule_name,'INSULIN ASPART','i') then top10=1;
  if top10=1;
run;

/* then repeat the 0–90-day block on work.top10 similarly */
*/
