/************************************************************************************
| Project name : Biosimilar 
| Program name : 01_Cohort_dertivation
| Date (update): June 2024
| Task Purpose : 
|      1. 00
| Main dataset : (1) procedure, (2) tx.patient, (3) tx.patient_cohort & tx.genomic (but not merged)
| Final dataset : min.bs_user_all_v07 (with distinct indiv)
************************************************************************************/

/************************************************************************************
	1. NDCs for Adalimumab 
************************************************************************************/
/* 
%macro yearly(data=, refer=);

data &data;
  set &refer;
  if index(upcase(molecule_name),'ADALIMUMAB')>0;
run;

%mend yearly;
%yearly(data=input.adalimumab_24_v00, refer=input.RxFact2024);
%yearly(data=input.adalimumab_22_v00, refer=input.RxFact2022);
%yearly(data=input.adalimumab_20_v00, refer=input.RxFact2020);
%yearly(data=input.adalimumab_18_v00, refer=input.RxFact2018);
*/

* use pre-identified files;
proc import datafile="/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r/data/ADALIMUMAB_NDCs.dta" out=input.ADALIMUMAB_NDCs dbms=dta replace; run;

proc contents data=input.ADALIMUMAB_NDCs; run;
proc print data=input.ADALIMUMAB_NDCs (obs=20); run;


/************************************************************************************
	2. Categorize at NDC level
************************************************************************************/

* 0. make indicators;
data input.ADALIMUMAB_NDCs; set input.ADALIMUMAB_NDCs; length category $50; run;

/*
category
 1. reference_biologics
 2. co_branded_biologics
 3. co_branded_biologics_not_cordavis
 4. private_label_biosimilar
 5. biosimilar 
 6. biosimilar_ADAZ
 7. biosimilar_ADBM
 8. biosimilar_RYVK
*/

* 1. molecule_name=ADALIMUMAB | Original OR co-branded;
proc sort data=input.ADALIMUMAB_NDCs; by category drug_labeler_corp_name; run;
proc print data=input.ADALIMUMAB_NDCs; where molecule_name = "ADALIMUMAB"; title "molecule_name=ADALIMUMAB | Original and co-branded"; run;

data input.ADALIMUMAB_NDCs; set input.ADALIMUMAB_NDCs; 
	if molecule_name = "ADALIMUMAB" and drug_labeler_corp_name in ("ABBVIE", "ABBVIE US LLC", "ABBOTT") then category = "reference_biologics"; 
	else if molecule_name = "ADALIMUMAB" and drug_labeler_corp_name in ("CORDAVIS LIMITED") then category = "co_branded_biologics"; 
    else if molecule_name = "ADALIMUMAB" and drug_labeler_corp_name in ("PHYSICIANS TOTAL CARE", "A-S MEDICATION SOLUTIONS", "CLINICAL SOLUTIONS WHOLESALE") then category = "co_branded_biologics_not_cordavis"; 
run;


* 2. molecule_name=ADALIMUMAB-ADAZ | private_label_biosimilar OR biosimilar ;
proc print data=input.ADALIMUMAB_NDCs; where molecule_name = "ADALIMUMAB-ADAZ"; title "molecule_name=ADALIMUMAB-ADAZ | private_label_biosimilar OR biosimilar"; run;
proc sort data=input.ADALIMUMAB_NDCs; by category; run;

data input.ADALIMUMAB_NDCs; set input.ADALIMUMAB_NDCs;
    if molecule_name = "ADALIMUMAB-ADAZ" and drug_labeler_corp_name = "NOVARTIS" then category = "biosimilar_ADAZ";
    else if molecule_name = "ADALIMUMAB-ADAZ" and drug_labeler_corp_name = "CORDAVIS LIMITED" then category = "private_label_biosimilar";
run;

* 3. molecule_name=ADALIMUMAB-ADBM | private_label_biosimilar OR biosimilar ;
proc print data=input.ADALIMUMAB_NDCs; where molecule_name = "ADALIMUMAB-ADBM"; title "molecule_name=ADALIMUMAB-ADBM | private_label_biosimilar OR biosimilar"; run;
proc sort data=input.ADALIMUMAB_NDCs; by category drug_labeler_corp_name; run;

data input.ADALIMUMAB_NDCs; set input.ADALIMUMAB_NDCs;
    if molecule_name = "ADALIMUMAB-ADBM" and drug_labeler_corp_name = "BOEHRINGER INGELHEIM" and product_ndc in (597037082, 597037516, 597037523, 597037597, 597040089, 597040580, 597049550) then category = "biosimilar_ADBM";
    else if molecule_name = "ADALIMUMAB-ADBM" and drug_labeler_corp_name = "BOEHRINGER INGELHEIM" and product_ndc not in (597037082, 597037516, 597037523, 597037597, 597040089, 597040580, 597049550) then category = "biosimilar_ADBM";
	else if molecule_name = "ADALIMUMAB-ADBM" and drug_labeler_corp_name = "QUALLENT" then category = "private_label_biosimilar";
run;

* 4. molecule_name=ADALIMUMAB-RYVK | private_label_biosimilar OR biosimilar ;
proc print data=input.ADALIMUMAB_NDCs; where molecule_name = "ADALIMUMAB-RYVK"; title "molecule_name=ADALIMUMAB-RYVK | private_label_biosimilar OR biosimilar"; run;
proc sort data=input.ADALIMUMAB_NDCs; by category drug_labeler_corp_name; run;

data input.ADALIMUMAB_NDCs; set input.ADALIMUMAB_NDCs;
    if molecule_name = "ADALIMUMAB-RYVK" and drug_labeler_corp_name = "QUALLENT" then category = "private_label_biosimilar";
    else if molecule_name = "ADALIMUMAB-RYVK" and drug_labeler_corp_name = "TEVA PHARMACEUTICALS USA" then category = "biosimilar_RYVK";
run;

* 5. molecule_name=others | biosimilar ;
proc print data=input.ADALIMUMAB_NDCs; where molecule_name = "ADALIMUMAB-FKJP"; title "molecule_name=ADALIMUMAB-FKJP | biosimilar"; run;

data input.ADALIMUMAB_NDCs; set input.ADALIMUMAB_NDCs;
    if molecule_name in ("ADALIMUMAB-AACF", "ADALIMUMAB-AATY", "ADALIMUMAB-AFZB", "ADALIMUMAB-AQVH", "ADALIMUMAB-ATTO", "ADALIMUMAB-BWWD", "ADALIMUMAB-FKJP") then category = "biosimilar";
run;










