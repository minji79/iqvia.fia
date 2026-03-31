
/************************************************************************************
	0.   Library Setting
************************************************************************************/

directory: cd /dcs07/hpm/data/iqvia_fia

/* run sas */
rm ~/.config/chromium/Singleton*
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* set library */
libname input "/dcs07/hpm/data/iqvia_fia/glp1_disc";   /* my own directory */
libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */
libname glp1 "/dcs04/hpm/data/iqvia_fia/glp1_paper/data";
libname biosim "/dcs07/hpm/data/iqvia_fia/biosim";   /* for reference files */
libname fast "/fastscratch/myscratch/mkim";   /* my fastbarch with 1 TB memory */



/*============================================================*
 | 1. clean 25 datasets
 *============================================================*/
* add 25 dataset;
proc contents data=input.rx_24_glp1; run;
proc contents data=input.rx_25_glp1; run;

* find glp1 users in 2025;
data input.rx_25_glp1; set biosim.RxFact2025_clean; if molecule_name in ("DULAGLUTIDE", "EXENATIDE", "LIRAGLUTIDE", "LIRAGLUTIDE (WEIGHT MANAGEMENT)", "LIXISENATIDE",
"SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)"); run; /* 619613 claims */

* provider zip;
proc contents data=biosim.provider; run;
proc sort data=biosim.provider(keep=national_provider_id provider_zip_code) 
          out=provider_clean nodupkey;
    by national_provider_id;
run;

proc sort data=input.rx_25_glp1; by npi; run;
data input.rx_25_glp1;
    merge input.rx_25_glp1 (in=a)
          provider_clean (in=b rename=(national_provider_id=npi provider_zip_code=provider_zip));
    by npi;
    if a; /* Keeps only records that existed in your original RX table */
run;


/*============================================================*
 | 2. identify dominant payer
 *============================================================*/
* 2025 ;
* convert dominant payer file for 2025 and merge with data;
proc import datafile="/dcs07/hpm/data/iqvia_fia/parquet/data/insurance_patient_year25.dta" out=biosim.insurance_patient_year25 dbms=dta replace; run;
proc sql;
	create table input.rx_25_glp1 as
	select distinct a.*, b.dominant_payer
	from input.rx_25_glp1 as a
	left join biosim.insurance_patient_year25 as b
	on a.patient_id = b.patient_id;
quit;

data input.rx_25_glp1;
    set input.rx_25_glp1(rename=(dominant_payer=dominant_payer_draft));
    length dominant_payer $100.;

    if missing(dominant_payer_draft) 
       or dominant_payer_draft in ("PPO/HMO","State/Fed Employee") 
    then dominant_payer = "Unclear Insurance";
	*else if dominant_payer_draft in ("Medicaid: FFS","Medicaid: MCO","Medicaid: Unspec") then dominant_payer = "Medicaid";
	*else if dominant_payer_draft in ("Medicare D: ADV","Medicare D: TM","Medicare D: Unspec") then dominant_payer = "Medicare D";
    else dominant_payer = dominant_payer_draft;
run;
proc freq data=input.rx_25_glp1; table dominant_payer; run;


* 2017-2024 ;
%macro yearly(year=);
proc sql;
	create table input.rx_&year._glp1 as
	select distinct a.*, b.dominant_payer
	from input.rx_&year._glp1 as a
	left join input.joe_plan_mapping as b
	on a.patient_id = b.patient_id and a.year = b.year;
quit;

data input.rx_&year._glp1; set input.rx_&year._glp1 (rename=(dominant_payer=dominant_payer_draft));
	length dominant_payer $100.;

    if missing(dominant_payer_draft) or dominant_payer_draft = "Unclear Insurance" then dominant_payer = "Unclear Insurance";
    else dominant_payer = dominant_payer_draft;
run; 

%mend yearly;
%yearly(year=24); /* 8299345 claims */
%yearly(year=23); /* 6273028 claims */
%yearly(year=22); /* 3287046 claims */
%yearly(year=21); /* 2189023 claims */
%yearly(year=20); /* 1754725 claims */
%yearly(year=19); /* 1453451 claims */
%yearly(year=18); /* 1176157 claims */
%yearly(year=17); /* 854405 claims */


/*============================================================*
 | 3. drop un-used variable from 2017-2024 dataset & 2025
 *============================================================*/
* from 2025 :
data input.rx_25_glp1; set input.rx_25_glp1; drop adjudicating_pbm_plan_name branded_generic dominant_payer_draft otc_indicator usc_3 usc_5 usc_3_description usc_5_description; run;	

* from 2017-2024 :
%macro yearly(year=);
data input.rx_&year._glp1; set input.rx_&year._glp1;
    drop auth_rfll_nbr dominant_payer_draft _merge daw_cd ama_do_not_contact_ind ama_pdrp_ind cob_ind dspnsd_qty form_name month_id week_id package_size rx_orig_cd rx_typ_cd rx_written_dt sob_desc sob_value strength;
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



/*============================================================*
 | 4. merge long dataset from 2017 - 2025 (Sep)
 *============================================================*/
data input.rx17_25_glp1_long; set input.rx_25_glp1 input.rx_24_glp1 input.rx_23_glp1 input.rx_22_glp1 input.rx_21_glp1 input.rx_20_glp1 input.rx_19_glp1 input.rx_18_glp1 input.rx_17_glp1; run;

/*============================================================*
 | 5. remain only "final_claim_ind" only
 *============================================================*/
proc freq data=input.rx_25_glp1; table final_claim_ind*encnt_outcm_cd; run;
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long; if final_claim_ind ="Y"; run;

/*============================================================*
 | 6. re-categorize rejection reasons with new category
 *============================================================*/
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long; drop rj_grp; run;
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long;
    length rj_grp $100.;
    rj_grp = "";

  if rjct_cd in ('','00','000') then rj_grp="approved";
  else if rjct_cd in ('88','608','088','0608') then rj_grp="rj_step";
  else if rjct_cd in ('3N','3P','3S','3T','3W','03N','03P','03S','03T','03W',
                      '3X','3Y','64','6Q','75','03X','03Y','064','06Q','075',
                      '80','EU','EV','MV','PA','080','0EU','0EV','0MV','0PA')  then rj_grp="rj_pa";
  else if rjct_cd in ('76','7X','AG','RN','076','07X','0AG','0RN') then rj_grp="rj_qty_limit";
      
  else if rjct_cd in ('60','61','63','060','061','063',
                      '7Y','8A','8H','9R','9T','9Y','BB',
                      '07Y','08A','08H','09R','09T','09Y','0BB','MR','0MR','70','070','9Q','09Q') then rj_grp="rj_not_covered";
  else rj_grp="rj_non_formulary_reason";
run;

data input.rx17_25_glp1_long; set input.rx17_25_glp1_long; drop RJ_reason; run;
data input.rx17_25_glp1_long; set input.rx17_25_glp1_long;
 length RJ_reason $100.;
 RJ_reason = "";
 if encnt_outcm_cd = "PD" then RJ_reason = 'Approved - paid';
 else if encnt_outcm_cd = "RV" then RJ_reason = 'Approved - reversed';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_step" then RJ_reason = 'RJ_Step';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_pa" then RJ_reason = 'RJ_PrAu';
 else if encnt_outcm_cd = 'RJ' and rj_grp in ("rj_not_covered", "rj_ndc_block") then RJ_reason = 'RJ_NtCv';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_qty_limit" then RJ_reason = 'RJ_QtyLimit';
 else if encnt_outcm_cd = 'RJ' and rj_grp="rj_non_formulary_reason" then RJ_reason = 'RJ_Others_NotForm';
 else RJ_reason = 'NA';
run;
proc freq data=input.rx17_25_glp1_long; table RJ_reason; run;

