
/*============================================================*
 | 1. Check validity: rx_written_dt - index_date
 *============================================================*/
proc contents data=input.id_index; run;
proc contents data=biosim.rxfact2025; run;

* identify rx_written_dt for the index claim ; 
data df_25; set input.id_index; if year = 2025; run;
data df_24; set input.id_index; if year = 2024; run;
data df_23; set input.id_index; if year = 2023; run;
data df_22; set input.id_index; if year = 2022; run;
data df_21; set input.id_index; if year = 2021; run;
data df_20; set input.id_index; if year = 2020; run;
data df_19; set input.id_index; if year = 2019; run;
data df_18; set input.id_index; if year = 2018; run;
data df_17; set input.id_index; if year = 2017; run;


%macro yearly(year=, ref=);
proc sql;
	create table df_&year as
	select distinct a.*, b.rx_written_dt
	from df_&year as a
	left join &ref as b
	on a.claim_id = b.claim_id and a.patient_id = b.patient_id;
quit;

%mend yearly;
%yearly(year=25, ref=biosim.rxfact2025);
%yearly(year=24, ref=biosim.rxfact2024); 
%yearly(year=23, ref=biosim.rxfact2023);
%yearly(year=22, ref=biosim.rxfact2022);
%yearly(year=21, ref=biosim.rxfact2021); 
%yearly(year=20, ref=biosim.rxfact2020); 
%yearly(year=19, ref=biosim.rxfact2019); 
%yearly(year=18, ref=biosim.rxfact2018); 
%yearly(year=17, ref=biosim.rxfact2017);

data input.id_index; set df_25 df_24 df_23 df_22 df_21 df_20 df_19 df_18 df_17; run; /* it should be 925,056 */
proc contents data=input.id_index; run;

* rx_to_index_days = index_date - rx_written_dt ;
data df; set input.id_index; rx_to_index_days = index_date - rx_written_dt; run;
data df; set df; format index_date mmddyy10.; run;
proc print data=df (obs=10); var patient_id rx_written_dt index_date rx_to_index_days; where cohort4="filled at index date"; run;

proc freq data=input.id_index; table cohort4; run;

data df2; set df; if cohort4="filled after RV/RJ in 90days"; run;
*data df2; set df; if cohort4="filled at index date"; run;
proc means data=df2 n nmiss median q1 q3 min max; var rx_to_index_days; run;

/* how many people are in the certain boundaries */
proc sql;
    select 
        sum(case when rx_to_index_days <= 6 then 1 else 0 end) as filled_in_6days,
        sum(case when rx_to_index_days between 7 and 30 then 1 else 0 end) as filled_in_7_to_30days,
        sum(case when rx_to_index_days > 30 then 1 else 0 end) as filled_after_30days
    from (select distinct patient_id, rx_to_index_days from df2);
quit;

/* histogram of this variable */
proc univariate data=df2;
    var rx_to_index_days;
    histogram rx_to_index_days / vscale=count;
run;

/* how many ppl have initial rejections */
* set the ;
data raw_long; set input.rx_25_glp1 input.rx_24_glp1 input.rx_23_glp1 input.rx_22_glp1 input.rx_21_glp1 input.rx_20_glp1 input.rx_19_glp1 input.rx_18_glp1 input.rx_17_glp1; run;
proc sql;
	create table input.df_long_test as
	select *
	from raw_long as a
	where a.patient_id in (
		select patient_id
		from df2
		where rx_to_index_days > 7
	);
quit;

proc sql;
	create table input.df_long_test as
    select distinct a.*, b.index_date
    from input.df_long_test as a
    left join input.id_index as b
    on a.patient_id = b.patient_id;
run; /* 424108 obs from 77298 individuals */

proc print data=input.df_long_test (obs=10); run;
data df_long_test; set input.df_long_test; if svc_dt < index_date; run; /* 95796 obs from 77298 individuals */
proc sort data=df_long_test; by patient_id rx_written_dt svc_dt; run;
proc print data=df_long_test (obs=20); var patient_id rx_written_dt svc_dt molecule_name encnt_outcm_cd; run;

proc sort data=biosim.rxfact2025; by patient_id rx_written_dt svc_dt; run;
proc print data=biosim.rxfact2025 (obs=20); var patient_id claim_id rx_written_dt svc_dt plan_id; run;



/*============================================================*
 | 2. Main analysis - outcome = Filled at index attempts
 *============================================================*/

proc contents data=input.id_index; run;
proc freq data=input.id_index; table RJ_reason_adj; run;

* outcome = primary non-adherance (non_ad_event=1);
data df; set input.id_index; if cohort2 ="filled at the index attempt" then non_ad_event=0; else non_ad_event=1; run;

* age ; 
data df; set df; 
if 18 <= age_at_claim and age_at_claim < 35 then age_cat = 1; 
else if 35 <= age_at_claim and age_at_claim < 50 then age_cat = 2; 
else if 50 <= age_at_claim and age_at_claim < 65 then age_cat = 3; 
else if 65 <= age_at_claim then age_cat = 4; 
else age_cat =.;
run;
proc freq data=df; table age_cat; run;


/* model 1 - perfectly fit with the rejection reason */
proc logistic data=df;
    class patient_gender(ref='M') age_cat (ref='4') region (ref='Midwest') dominant_payer_adj (ref='Commercial') diabetes_history (ref='1') year(ref='2018')
          molecule_name (ref='SEMAGLUTIDE') / param=glm order=internal;
    model non_ad_event(event='1') = age_cat patient_gender dominant_payer_adj diabetes_history molecule_name year;
run;




/*============================================================*
 | 3. Main analysis - outcome = B.	Filled within 90days
 *============================================================*/

proc contents data=input.id_index; run;
proc freq data=input.id_index; table cohort2; run;

* outcome = primary non-adherance (non_ad_event=1);
data df; set input.id_index; if cohort2 ="never filled or filled after 90 days" then non_ad_event=1; else non_ad_event=0; run;

* age ; 
data df; set df; 
if 18 <= age_at_claim and age_at_claim < 35 then age_cat = 1; 
else if 35 <= age_at_claim and age_at_claim < 50 then age_cat = 2; 
else if 50 <= age_at_claim and age_at_claim < 65 then age_cat = 3; 
else if 65 <= age_at_claim then age_cat = 4; 
else age_cat =.;
run;
proc freq data=df; table age_cat; run;


/* model 1 - perfectly fit with the rejection reason */
proc logistic data=df;
    class patient_gender(ref='M') age_cat (ref='4') region (ref='Midwest') dominant_payer_adj (ref='Commercial') diabetes_history (ref='1') year(ref='2018')
          molecule_name (ref='SEMAGLUTIDE') / param=glm order=internal;
    model non_ad_event(event='1') = age_cat patient_gender dominant_payer_adj diabetes_history molecule_name year;
run;



