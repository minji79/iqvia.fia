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
	1. Adalimumab 
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

* use 
proc contents data=tutorial.adalimumab_24_v00; run;
