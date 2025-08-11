/************************************************************************************
| Project name : Thesis - BS and GLP1
| Program name : 01_Cohort_dertivation
| Date (update): June 2024
| Task Purpose : 
|      1. select all Bariatric Surgery(BS) users from 100% data (N = 99,350)
|      2. BS users (initial use date) between 2016 - 2020    (N = 45,761)
|      3. Merge "BS users 2016 - 2020" + demographic data (N = 45,761)
|      4. select Age >= 18 (N = 44,959)
|      5. exclude individuals without sex information (N = 42,535)
| Main dataset : (1) procedure, (2) tx.patient, (3) tx.patient_cohort & tx.genomic (but not merged)
| Final dataset : min.bs_user_all_v07 (with distinct indiv)
************************************************************************************/

* import 100% raw FIA dataset;
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% raw data */

/************************************************************************************
	STEP 1. All Bariatric Surgery(BS) users	     N = 99,350
************************************************************************************/
