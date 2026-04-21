
proc freq data=input.id_index; table cohort2; run;

/*============================================================*
 | 1. Table 1
 *============================================================*/

*  distribution by plan_type;
data input.id_index; set input.id_index; length dominant_payer_adj $100.; 
  if dominant_payer in ("Medicaid: FFS","Medicaid: MCO","Medicaid: Unspec") then dominant_payer_adj = "Medicaid";
	else if dominant_payer in ("Medicare D: ADV","Medicare D: TM","Medicare D: Unspec") then dominant_payer_adj = "Medicare D";
  else dominant_payer_adj = dominant_payer; 
run;


* RJ_reason_adj;
data input.id_index; set input.id_index; length RJ_reason_adj $100.; 
if RJ_reason in ("RJ_PrAu","RJ_Step") then RJ_reason_adj = "RJ_UM (PA/Step)";
else if RJ_reason in ("RJ_Others_NotForm","RJ_QtyLimit") then RJ_reason_adj = "RJ_Non-formarly";
else RJ_reason_adj = RJ_reason;
run;

* OOP for 30days;
data input.id_index; set input.id_index; oop_30days = final_opc_amt / days_supply_cnt *30; run;

* time_to_fill =first_filled_date - index_rx_dt;
data input.id_index; set input.id_index; if cohort2 ne "never filled or filled after 90 days" then time_to_fill = first_filled_date - index_rx_dt; else time_to_fill=.; run;


* switching glp1 (within 470,325 individuals);
proc print data=input.id_index (obs=10); var patient_id index_rx_dt index_svc_dt index_decision first_filled_date dominant_payer plan_name plan_type molecule_name; run;

data input.id_index; set input.id_index; drop switching_glp1; run;
data input.id_index; set input.id_index; length switching_glp1 $100.;
if molecule_name in ("SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)") and first_filled_molecule in ("TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)") then switching_glp1 ="sema -> tirz"; 
else if molecule_name in ("TIRZEPATIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)") and first_filled_molecule in ("SEMAGLUTIDE", "SEMAGLUTIDE (WEIGHT MANAGEMENT)") then switching_glp1 ="tirz - sema";
else switching_glp1 =""; 
run;
proc freq data=input.id_index; table switching_glp1; run;


* switching indication (within 470,325 individuals);
data input.id_index; set input.id_index; length indication_index $100.;
	if molecule_name in ("SEMAGLUTIDE", "TIRZEPATIDE") then indication_index = "diabetes"; 
	else if molecule_name in ("SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE (WEIGHT MANAGEMENT)") then indication_index = "obesity"; 
	else indication_index = .;
run;
proc freq data=input.id_index; table indication_index; run;

data input.id_index; set input.id_index; length indication_firstfill $100.;
	if not missing(first_filled_molecule) and first_filled_molecule in ("SEMAGLUTIDE", "TIRZEPATIDE") then indication_firstfill = "diabetes"; 
	else if not missing(first_filled_molecule) and first_filled_molecule in ("SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE (WEIGHT MANAGEMENT)") then indication_firstfill = "obesity"; 
	else indication_firstfill = .;
run;
proc freq data=input.id_index; table indication_firstfill; run;

data input.id_index; set input.id_index; drop switching_indication; run;
data input.id_index; set input.id_index; length switching_indication $100.;
  if not missing(first_filled_molecule) and molecule_name in ("SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE (WEIGHT MANAGEMENT)") and first_filled_molecule in ("SEMAGLUTIDE", "TIRZEPATIDE") then switching_indication="dm -> obesity"; 
  else if not missing(first_filled_molecule) and molecule_name in ("SEMAGLUTIDE", "TIRZEPATIDE") and first_filled_molecule in ("SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE (WEIGHT MANAGEMENT)") then switching_indication="obesity -> dm"; 
  else if not missing(first_filled_molecule) and indication_index = indication_firstfill then switching_indication="keep"; 
  else switching_indication=""; 
run;
proc freq data=input.id_index; table switching_indication; run;


* switching plan (plan_id level) (within 470,325 individuals);
data input.id_index; set input.id_index; 
  if not missing(first_filled_plan_id) and plan_id ne first_filled_plan_id then switching_plan=1; 
  else if not missing(first_filled_plan_id) and plan_id = first_filled_plan_id then switching_plan=0; 
  else switching_plan=.; 
run;
proc freq data=input.id_index; table switching_plan; run;



/*============================================================*
 | 2. Table 1 | Patient and plan characteristics at the index claim by primary adherence outcome
 *============================================================*/

* age at the index;
proc means data=input.id_index n nmiss median q1 q3 min max; var age_at_claim; run;
proc means data=input.id_index n nmiss median q1 q3 min max;
    class cohort2;
    var age_at_claim;
run;

* patient_gender;
proc freq data=input.id_index; table patient_gender; run;
proc freq data=input.id_index; table patient_gender*cohort2 /norow nopercent; run;

* region;
proc freq data=input.id_index; table region; run;
proc freq data=input.id_index; table region*cohort2 /nocol nopercent; run;

* dominant_payer_adj;
proc freq data=input.id_index; table dominant_payer_adj; run;
proc freq data=input.id_index; table dominant_payer_adj*cohort2 /nocol nopercent; run;

* RJ_reason_adj at index claim;
proc freq data=input.id_index; table RJ_reason_adj; run;
proc freq data=input.id_index; table RJ_reason_adj*cohort2 /nocol nopercent; run;

* Paid type at index claim;
proc freq data=input.id_index; table index_decision; run;
data sample; set input.id_index; if index_decision = "PD"; run;

* PD without ;
proc sql; 
    select count(distinct patient_id) as count
    from sample
	where cash=0 and coupon=0 and discount_card=0;
quit;

proc sql; 
    select count(distinct patient_id) as count
    from sample
	where primary_coupon=1 and not missing(sec_payer_id);
quit; /* 268 */
proc sql; 
    select count(distinct patient_id) as count
    from sample
	where secondary_coupon=1 and not missing(payer_id);
quit; /* 1233 */


proc sql; 
    select count(distinct patient_id) as count
    from sample
	where discount_card=1 and not missing(payer_id);
quit; /* 1573 */
proc sql; 
    select count(distinct patient_id) as count
    from sample
	where discount_card=1 and not missing(sec_payer_id);
quit; /* 419 */

proc sql; 
    select count(distinct patient_id) as count
    from sample
	where cash=1 and not missing(payer_id);
quit;
proc sql; 
    select count(distinct patient_id) as count
    from sample
	where cash=1 and not missing(sec_payer_id);
quit;


proc print data=sample (obs=10); where cash=1 and not missing(sec_payer_id); run;

proc freq data=sample; table cash; run;
proc freq data=sample; table coupon; run;
proc freq data=sample; table primary_coupon; run;
proc freq data=sample; table secondary_coupon; run;
proc freq data=sample; table discount_card; run;

* oop_30days;
data sample; set input.id_index; if index_decision = "PD"; run;
data sample; set input.id_index; if index_decision = "RV"; run;

proc means data=sample n nmiss median q1 q3 min max; var oop_30days; run;
proc means data=sample n nmiss median q1 q3 min max;
    class cohort2;
    var oop_30days;
run;


/*
* Non-insurance payment types : coupon / discount card / cash;
proc freq data=input.id_index; table cash; run;
proc freq data=input.id_index; table cash*cohort4 /nocol nopercent; run;

proc freq data=input.id_index; table coupon; run;
proc freq data=input.id_index; table coupon*cohort4 /nocol nopercent; run;
*/


/* coupon users were never rejected? */
data df2; set input.id_index; if coupon=1; run;
proc freq data=df2; table encnt_outcm_cd; run;

proc freq data=input.id_index; table primary_coupon; run;
proc freq data=input.id_index; table primary_coupon*cohort4 /nocol nopercent; run;
proc freq data=input.id_index; table secondary_coupon; run;
proc freq data=input.id_index; table secondary_coupon*cohort4 /nocol nopercent; run;

proc freq data=input.id_index; table discount_card; run;
proc freq data=input.id_index; table discount_card*cohort4 /nocol nopercent; run;

* molecule_name at index claim;
proc freq data=input.id_index; table molecule_name; run;
proc freq data=input.id_index; table molecule_name*cohort2 /nocol nopercent; run;

* diabetes_history;
proc freq data=input.id_index; table diabetes_history; run;
proc freq data=input.id_index; table diabetes_history*cohort2 /nocol nopercent; run;

proc freq data=input.id_index; table diabetes_history_nonglp1; run;
proc freq data=input.id_index; table diabetes_history_nonglp1*cohort2 /nocol nopercent; run;

proc freq data=input.id_index; table diabetes_history_glp1; run;
proc freq data=input.id_index; table diabetes_history_glp1*cohort2 /nocol nopercent; run;




/*============================================================*
 | 3. Table 2. Post-Rejection Outcomes within 90 days (N=239290)
 *============================================================*/
data table2; set input.id_index; if index_decision ="RJ"; run;
proc freq data=table2; table cohort2; run;

* RJ_reason_adj at index claim;
proc freq data=table2; table RJ_reason_adj; run;
proc freq data=table2; table RJ_reason_adj*cohort2 /nocol nopercent; run;

* dominant_payer_adj at index date;
proc freq data=table2; table dominant_payer_adj; run;
proc freq data=table2; table dominant_payer_adj*cohort2 /nocol nopercent; run;

* Non-insurance payment types : coupon / discount card / cash;
proc freq data=table2; table first_filled_cash*cohort2 /norow nopercent; run;
proc freq data=table2; table first_filled_coupon*cohort2 /norow nopercent; run;
proc freq data=table2; table first_filled_discount_card*cohort2 /norow nopercent; run;

*;
proc freq data=table2; table indication_index; run;


* time_to_fill & first_filled_molecule;
data sample_table2; set table2; if cohort2 ="filled after RJ/RV in 90days"; run;

proc means data=sample_table2 n nmiss median q1 q3 min max; var time_to_fill; run;
proc means data=sample_table2 n nmiss median q1 q3 min max;
    class RJ_reason_adj;
    var time_to_fill;
run;

proc means data=sample_table2 n nmiss median q1 q3 min max;
    class dominant_payer_adj;
    var time_to_fill;
run;

proc means data=sample_table2 n nmiss median q1 q3 min max;
    class first_filled_cash;
    var time_to_fill;
run;

proc means data=sample_table2 n nmiss median q1 q3 min max;
    class first_filled_coupon;
    var time_to_fill;
run;

proc means data=sample_table2 n nmiss median q1 q3 min max;
    class first_filled_discount_card;
    var time_to_fill;
run;

proc freq data=sample_table2; table first_filled_molecule; run;
proc freq data=sample_table2; table switching_glp1; run;
proc freq data=sample_table2; table switching_indication; run;
proc freq data=sample_table2; table indication_index; run;

proc freq data=sample_table2; table switching_plan; run;
proc freq data=sample_table2; table switching_plan*RJ_reason_adj /norow nopercent; run;


proc means data=sample_table2 n nmiss median q1 q3 min max;
    class first_filled_molecule;
    var time_to_fill;
run;

proc means data=sample_table2 n nmiss median q1 q3 min max;
    class switching_glp1;
    var time_to_fill;
run;

proc means data=sample_table2 n nmiss median q1 q3 min max;
    class switching_indication;
    var time_to_fill;
run;


proc means data=sample_table2 n nmiss median q1 q3 min max;
    class switching_plan;
    var time_to_fill;
run;

* # at the same date of rejection ;
proc sql; 
    select count(distinct patient_id) as count_filled_at_samedate
    from sample_table2
	where first_filled_cash =1 and time_to_fill=0;
quit;

proc sql; 
    select count(distinct patient_id) as count_filled_at_samedate
    from sample_table2
	where first_filled_coupon =1 and time_to_fill=0;
quit;

proc sql; 
    select count(distinct patient_id) as count_filled_at_samedate
    from sample_table2
	where first_filled_discount_card =1 and time_to_fill=0;
quit;

/*============================================================*
 | 4. Table 3. Post-Reverse Outcomes within 90 days (N=161478)
 *============================================================*/
data table3; set input.id_index; if index_decision ="RV"; run;
proc freq data=table3; table cohort2; run;

* dominant_payer_adj at index date;
proc freq data=table3; table dominant_payer_adj; run;
proc freq data=table3; table dominant_payer_adj*cohort2 /nocol nopercent; run;

proc freq data=table3; table indication_index; run;

* time_to_fill & first_filled_oop_30days; 
data sample_table3; set table3; if cohort2 ="filled after RJ/RV in 90days"; run;
proc means data=sample_table3 n nmiss median q1 q3 min max; var first_filled_oop_30days; run;

proc freq data=sample_table3; table first_filled_cash; run;
proc freq data=sample_table3; table first_filled_coupon; run;
proc freq data=sample_table3; table first_filled_discount_card; run;

proc freq data=sample_table3; table first_filled_molecule; run;
proc freq data=sample_table3; table switching_glp1; run;
proc freq data=sample_table3; table switching_indication; run;
proc freq data=sample_table3; table indication_index; run;

proc freq data=sample_table3; table switching_plan; run;

proc means data=table3 n nmiss median q1 q3 min max; var time_to_fill; run;
proc means data=table3 n nmiss median q1 q3 min max;
    class dominant_payer_adj;
    var time_to_fill;
run;

proc means data=sample_table3 n nmiss median q1 q3 min max;
    class first_filled_cash;
    var time_to_fill;
run;

proc means data=sample_table3 n nmiss median q1 q3 min max;
    class first_filled_coupon;
    var time_to_fill;
run;

proc means data=sample_table3 n nmiss median q1 q3 min max;
    class first_filled_discount_card;
    var time_to_fill;
run;

proc means data=sample_table3 n nmiss median q1 q3 min max;
    class first_filled_molecule;
    var time_to_fill;
run;

proc means data=sample_table3 n nmiss median q1 q3 min max;
    class switching_glp1;
    var time_to_fill;
run;

proc means data=sample_table3 n nmiss median q1 q3 min max;
    class switching_indication;
    var time_to_fill;
run;

proc means data=sample_table3 n nmiss median q1 q3 min max;
    class switching_plan;
    var time_to_fill;
run;


* # at the same date of rejection ;
proc sql; 
    select count(distinct patient_id) as count_filled_at_samedate
    from sample_table3
	where first_filled_cash =1 and time_to_fill=0;
quit;

proc sql; 
    select count(distinct patient_id) as count_filled_at_samedate
    from sample_table3
	where first_filled_coupon =1 and time_to_fill=0;
quit;

proc sql; 
    select count(distinct patient_id) as count_filled_at_samedate
    from sample_table3
	where first_filled_discount_card =1 and time_to_fill=0;
quit;


/*============================================================*
 | 5. Figure 1 - Waterfall plot
 *============================================================*/

* 1. overall;
proc freq data=input.id_index; table cohort2; run;
proc freq data=input.id_index; table RJ_reason_adj; run;
proc sql; 
    select count(distinct patient_id) as count_filled_with_coupons
    from input.id_index
	where cohort2 ="filled at the index attempt" and cash=0 and coupon=0 and discount_card=0;
quit;

data sample; set input.id_index; if cohort2 ="filled after RJ/RV in 90days"; run;
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


/*============================================================*
 | 6. Figure 2 - % of filler / attempter by quarterly
 *============================================================*/
/* total */
*quarter indicator;
data figure2; set input.id_index; 
    qtr_indicator = intnx('quarter', index_rx_dt, 0, 'beginning');
	attempter =1;
    format qtr_indicator yyq6.;
run;

proc sort data=figure2; by qtr_indicator; run;
proc sql;
    create table figure2_wide as
    select qtr_indicator,
           
           sum(case when dominant_payer_adj = 'Commercial' then 1 else 0 end) as n_attempter_commercial,
		   sum(case when dominant_payer_adj = 'Medicare D' then 1 else 0 end) as n_attempter_medicare,
		   sum(case when dominant_payer_adj = 'Medicaid' then 1 else 0 end) as n_attempter_medicaid,
           sum(case when dominant_payer_adj = 'Exchange' then 1 else 0 end) as n_attempter_exchange,
           sum(case when dominant_payer_adj = 'Unclear Insurance' then 1 else 0 end) as n_attempter_unclear,
           
           /* Total for the quarter */
           count(patient_id) as n_attempter_total
    from figure2
    group by qtr_indicator;
quit;
proc print data= figure2_wide; run;


* filler; 
data filler; set input.id_index; if not missing(first_filled_date); run;
data filler; set filler; 
	qtr_indicator = intnx('quarter', first_filled_date, 0, 'beginning');
	filler =1; 
	format qtr_indicator yyq6.;
run;

proc sort data=filler; by qtr_indicator; run;
proc sql;
    create table filler_wide as
    select qtr_indicator,
           sum(case when dominant_payer_adj = 'Commercial'        then 1 else 0 end) as n_filler_commercial,
           sum(case when dominant_payer_adj = 'Medicare D'        then 1 else 0 end) as n_filler_medicare,
           sum(case when dominant_payer_adj = 'Medicaid'          then 1 else 0 end) as n_filler_medicaid,
           sum(case when dominant_payer_adj = 'Exchange'          then 1 else 0 end) as n_filler_exchange,
           sum(case when dominant_payer_adj = 'Unclear Insurance' then 1 else 0 end) as n_filler_unclear,
           
           /* Total successful fillers in that quarter */
           count(*) as n_filler_total
    from filler 
    group by qtr_indicator;
quit;

proc print data=filler_wide; run;


*merge; 
proc sql;
 	create table figure2_total as
	select distinct a.*, b.n_filler_commercial, b.n_filler_medicare, b.n_filler_medicaid, b.n_filler_exchange, b.n_filler_unclear, b.n_filler_total
	from figure2_wide as a
	left join filler_wide as b
	on a.qtr_indicator =b.qtr_indicator; 
quit;
data figure2_total; set figure2_total; 
	pct_filler_total = n_filler_total / n_attempter_total *100; 
	pct_filler_commercial = n_filler_commercial / n_attempter_commercial *100; 
	pct_filler_medicare = n_filler_medicare / n_attempter_medicare *100; 
	pct_filler_medicaid = n_filler_medicaid / n_attempter_medicaid *100; 
	pct_filler_exchange = n_filler_exchange / n_attempter_exchange *100; 
	pct_filler_unclear = n_filler_unclear / n_attempter_unclear *100; 
run;
proc print data= figure2_total; run;

* remove 2025 Q3;
data figure2_total;
    set figure2_total;
    if qtr_indicator = yyq(2025, 3) then delete;
run;

/* figure for total */
proc sgplot data=figure2_total;
    title "Filled Rate(%) among GLP-1 RA Attempters";
    
    /* VBARBASIC is the 'friendly' version that allows overlays */
    vbarbasic qtr_indicator / response=n_attempter_total 
        fillattrs=(color=grey) 
        legendlabel="Total Attempters"
        name="bar";

    /* Series line now works because VBARBASIC uses a compatible axis */
    series x=qtr_indicator y=pct_filler_total / 
        y2axis 
        lineattrs=(color=red thickness=3) 
        markerattrs=(symbol=trianglefilled size=10 color=red)
        legendlabel="Filled Rate (%)"
        name="line";

    xaxis label="Quarter" grid valuesrotate=diagonal;
    yaxis label="Number of Patients (Counts)" grid;
    y2axis label="Filled Rate (%)" min=0 max=100 grid;
    
    keylegend "bar" "line" / location=outside position=bottom;
run;


/* Figure for by payer */
proc sgplot data=figure2_total;
    title "Filled Rate(%) among GLP-1 RA Attempters by Payer";
	
    series x=qtr_indicator y=pct_filler_medicare / legendlabel="Medicare D" lineattrs=(color=blue);
    series x=qtr_indicator y=pct_filler_medicaid / legendlabel="Medicaid"  lineattrs=(color=green);
    series x=qtr_indicator y=pct_filler_commercial / legendlabel="Commercial" lineattrs=(color=red);
	series x=qtr_indicator y=pct_filler_exchange / legendlabel="Exchange" lineattrs=(color=orange);
	*series x=qtr_indicator y=pct_filler_unclear / legendlabel="Unclear" lineattrs=(color=black);
                                                  

    xaxis label="Quarter" grid;
    yaxis label="Filled Rate (%)" grid;
run;


