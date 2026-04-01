
proc freq data=input.id_index; table cohort3; run;

/*============================================================*
 | 1. Table 1
 *============================================================*/

*  distribution by plan_type;
data input.id_index; set input.id_index; length dominant_payer_adj $100.; 
  if dominant_payer in ("Medicaid: FFS","Medicaid: MCO","Medicaid: Unspec") then dominant_payer_adj = "Medicaid";
	else if dominant_payer in ("Medicare D: ADV","Medicare D: TM","Medicare D: Unspec") then dominant_payer_adj = "Medicare D";
  else dominant_payer_adj = dominant_payer; 
run;

* cohort 4;
data input.id_index; set input.id_index; length cohort4 $100.; 
if cohort3 in ("filled after RJ in 90days","filled after RV in 90days") then cohort4 = "filled after RV/RJ in 90days";
else cohort4=cohort3;
run;

* RJ_reason_adj;
data input.id_index; set input.id_index; length RJ_reason_adj $100.; 
if RJ_reason in ("RJ_PrAu","RJ_Step") then RJ_reason_adj = "RJ_UM (PA/Step)";
else if RJ_reason in ("RJ_Others_NotForm","RJ_QtyLimit") then RJ_reason_adj = "RJ_Non-formarly";
else RJ_reason_adj = RJ_reason;
run;

* OOP for 30days;
data input.id_index; set input.id_index; oop_30days = final_opc_amt / days_supply_cnt *30; run;

* time_to_fill <- gap;
data input.id_index; set input.id_index; if cohort2 in ("filled after RJ in 90days","filled after RV in 90days") then time_to_fill = gap; else time_to_fill=.; run;

* switching glp1 & payers;
data input.id_index; set input.id_index; 
  if not missing(first_filled_molecule) and first_filled_molecule ne molecule_name then switching_glp1=1; 
  else if not missing(first_filled_molecule) and first_filled_molecule = molecule_name then switching_glp1=0; 
  else switching_glp1=.; 
run;
proc freq data=input.id_index; table switching_glp1; run;

data input.id_index; set input.id_index; 
  if not missing(first_filled_payer) and first_filled_payer ne dominant_payer then switching_payer=1; 
  else if not missing(first_filled_payer) and first_filled_payer = dominant_payer then switching_payer=0; 
  else switching_payer=.; 
run;
proc freq data=input.id_index; table switching_payer; run;

* switching which glp1;
data input.id_index; set input.id_index; length switching_glp1_detail $100.;
if switching_glp1=1 and molecule_name in ("SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)") and first_filled_molecule in ("TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)") then switching_glp1_detail ="sema -> tirz"; 
else if switching_glp1=1 and molecule_name in ("TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)") and first_filled_molecule in ("SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)") then switching_glp1_detail ="tirz - sema";
else switching_glp1_detail =""; 
run;


/*============================================================*
 | 2. Table 1 | Patient and plan characteristics at the index claim by primary adherence outcome
 *============================================================*/

* age at the index;
proc means data=input.id_index n nmiss median q1 q3 min max; var age_at_claim; run;
proc means data=input.id_index n nmiss median q1 q3 min max;
    class cohort4;
    var age_at_claim;
run;

* patient_gender;
proc freq data=input.id_index; table patient_gender; run;
proc freq data=input.id_index; table patient_gender*cohort4 /nocol nopercent; run;

* region;
proc freq data=input.id_index; table region; run;
proc freq data=input.id_index; table region*cohort4 /nocol nopercent; run;

* dominant_payer_adj;
proc freq data=input.id_index; table dominant_payer_adj; run;
proc freq data=input.id_index; table dominant_payer_adj*cohort4 /nocol nopercent; run;

* RJ_reason_adj at index claim;
proc freq data=input.id_index; table RJ_reason_adj; run;
proc freq data=input.id_index; table RJ_reason_adj*cohort4 /nocol nopercent; run;

* oop_30days;
data sample; set input.id_index; if encnt_outcm_cd = "RV"; run;
data sample; set input.id_index; if encnt_outcm_cd = "PD"; run;

proc means data=sample n nmiss median q1 q3 min max; var oop_30days; run;
proc means data=sample n nmiss median q1 q3 min max;
    class cohort4;
    var oop_30days;
run;

* Non-insurance payment types : coupon / discount card / cash;
proc freq data=input.id_index; table cash; run;
proc freq data=input.id_index; table cash*cohort4 /nocol nopercent; run;

proc freq data=input.id_index; table coupon; run;
proc freq data=input.id_index; table coupon*cohort4 /nocol nopercent; run;
proc freq data=input.id_index; table primary_coupon; run;
proc freq data=input.id_index; table primary_coupon*cohort4 /nocol nopercent; run;
proc freq data=input.id_index; table secondary_coupon; run;
proc freq data=input.id_index; table secondary_coupon*cohort4 /nocol nopercent; run;

proc freq data=input.id_index; table discount_card; run;
proc freq data=input.id_index; table discount_card*cohort4 /nocol nopercent; run;

* molecule_name at index claim;
proc freq data=input.id_index; table molecule_name; run;
proc freq data=input.id_index; table molecule_name*cohort4 /nocol nopercent; run;


/*============================================================*
 | 3. Table 2. Post-Rejection Outcomes within 90 days (N=239290)
 *============================================================*/
proc freq data=input.id_index; table cohort; run;
data table2; set input.id_index; if cohort ="rejected at index date"; run;
proc freq data=table2; table cohort3; run;

* RJ_reason_adj at index claim;
proc freq data=table2; table RJ_reason_adj; run;
proc freq data=table2; table RJ_reason_adj*cohort4 /nocol nopercent; run;

proc means data=table2 n nmiss median q1 q3 min max; var time_to_fill; run;
proc means data=table2 n nmiss median q1 q3 min max;
    class RJ_reason_adj;
    var time_to_fill;
run;

* dominant_payer_adj at index date;
proc freq data=table2; table dominant_payer_adj; run;
proc freq data=table2; table dominant_payer_adj*cohort4 /nocol nopercent; run;

proc means data=table2 n nmiss median q1 q3 min max;
    class dominant_payer_adj;
    var time_to_fill;
run;

* Non-insurance payment types : coupon / discount card / cash;
proc freq data=table2; table first_filled_cash*cohort4 /norow nopercent; run;
proc freq data=table2; table first_filled_coupon*cohort4 /norow nopercent; run;
proc freq data=table2; table first_filled_discount_card*cohort4 /norow nopercent; run;

* first_filled_molecule;
data sample_table2; set table2; if cohort4 ="filled after RV/RJ in 90days"; run;
proc freq data=sample_table2; table first_filled_molecule; run;
proc freq data=sample_table2; table switching_glp1; run;
proc freq data=sample_table2; table switching_payer; run;
proc freq data=sample_table2; table switching_glp1_detail; run;

/*============================================================*
 | 4. Table 3. Post-Reverse Outcomes within 90 days (N=161478)
 *============================================================*/
data table3; set input.id_index; if cohort = "reversed at index date"; run;
proc freq data=table3; table cohort3; run;

* dominant_payer_adj at index date;
proc freq data=table3; table dominant_payer_adj; run;
proc freq data=table3; table dominant_payer_adj*cohort4 /nocol nopercent; run;

proc means data=table3 n nmiss median q1 q3 min max; var time_to_fill; run;
proc means data=table3 n nmiss median q1 q3 min max;
    class dominant_payer_adj;
    var time_to_fill;
run;

* first_filled_oop_30days; 
data sample_table3; set table3; if cohort4 ="filled after RV/RJ in 90days"; run;
proc means data=sample_table3 n nmiss median q1 q3 min max; var first_filled_oop_30days; run;

proc freq data=sample_table3; table first_filled_cash; run;
proc freq data=sample_table3; table first_filled_coupon; run;
proc freq data=sample_table3; table first_filled_discount_card; run;

proc freq data=sample_table3; table first_filled_molecule; run;
proc freq data=sample_table3; table switching_glp1; run;
proc freq data=sample_table3; table switching_glp1_detail; run;
proc freq data=sample_table3; table switching_payer; run;


/*============================================================*
 | 5. Figure 1 - Waterfall plot
 *============================================================*/

* 1. overall;
proc freq data=input.id_index; table cohort4; run;
proc freq data=input.id_index; table RJ_reason_adj; run;

data sample; set input.id_index; if cohort4 ="filled after RV/RJ in 90days"; run;
proc freq data=sample; table first_filled_cash; run;
proc freq data=sample; table first_filled_coupon; run;
proc freq data=sample; table first_filled_discount_card; run;


* 2. semaglutide at index;
data sample; set input.id_index; if molecule_name in ("SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)"); run;
proc freq data=sample; table cohort4; run;
proc freq data=sample; table RJ_reason_adj; run;

data sample; set sample; if cohort4 ="filled after RV/RJ in 90days"; run;
proc freq data=sample; table first_filled_cash; run;
proc freq data=sample; table first_filled_coupon; run;
proc freq data=sample; table first_filled_discount_card; run;


* 3. tirzepatide at index;
data sample; set input.id_index; if molecule_name in ("TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)"); run;
proc freq data=sample; table cohort4; run;
proc freq data=sample; table RJ_reason_adj; run;

data sample; set sample; if cohort4 ="filled after RV/RJ in 90days"; run;
proc freq data=sample; table first_filled_cash; run;
proc freq data=sample; table first_filled_coupon; run;
proc freq data=sample; table first_filled_discount_card; run;


* 4. commercial at index;
data sample; set input.id_index; if dominant_payer_adj ="Commercial"; run;
proc freq data=sample; table cohort4; run;
proc freq data=sample; table RJ_reason_adj; run;

data sample; set sample; if cohort4 ="filled after RV/RJ in 90days"; run;
proc freq data=sample; table first_filled_cash; run;
proc freq data=sample; table first_filled_coupon; run;
proc freq data=sample; table first_filled_discount_card; run;


* 5. Exchange at index;
data sample; set input.id_index; if dominant_payer_adj ="Exchange"; run;
proc freq data=sample; table cohort4; run;
proc freq data=sample; table RJ_reason_adj; run;

data sample; set sample; if cohort4 ="filled after RV/RJ in 90days"; run;
proc freq data=sample; table first_filled_cash; run;
proc freq data=sample; table first_filled_coupon; run;
proc freq data=sample; table first_filled_discount_card; run;


* 6. Medicaid at index;
data sample; set input.id_index; if dominant_payer_adj ="Medicaid"; run;
proc freq data=sample; table cohort4; run;
proc freq data=sample; table RJ_reason_adj; run;

data sample; set sample; if cohort4 ="filled after RV/RJ in 90days"; run;
proc freq data=sample; table first_filled_cash; run;
proc freq data=sample; table first_filled_coupon; run;
proc freq data=sample; table first_filled_discount_card; run;


* 7. Medicare D at index;
data sample; set input.id_index; if dominant_payer_adj ="Medicare D"; run;
proc freq data=sample; table cohort4; run;
proc freq data=sample; table RJ_reason_adj; run;

data sample; set sample; if cohort4 ="filled after RV/RJ in 90days"; run;
proc freq data=sample; table first_filled_cash; run;
proc freq data=sample; table first_filled_coupon; run;
proc freq data=sample; table first_filled_discount_card; run;






