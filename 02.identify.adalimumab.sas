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
	1. molecule	     N = 99,350
************************************************************************************/

%macro yearly(data=, refer=);

data &data;
  set &refer;
  if index(upcase(molecule_name),'ADALIMUMAB')>0;
run;

%mend yearly;
%yearly(data=glp1users_v00, refer=pde20.pde_file_2020);
%yearly(data=glp1users_v01, refer=pde19.pde_file_2019);
%yearly(data=glp1users_v02, refer=pde18.pde_file_2018);
%yearly(data=glp1users_v03, refer=pde17.pde_file_2017);
