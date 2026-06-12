/*============================================================*
 | Adapted from glp1_rejection/05.analysis.sas (validity check on
 | time-to-fill). Keeps the rx_to_index_days derivation, the PROC
 | MEANS summary, the PROC SQL CASE day-window bucketing, and the
 | PROC UNIVARIATE histogram exactly as authored; data is the small
 | bundled id_index sample.
 *============================================================*/

* rx_to_index_days = index_date - rx_written_dt ;
data df; set input.id_index; rx_to_index_days = index_date - rx_written_dt; run;
data df; set df; format index_date mmddyy10.; run;
proc print data=df (obs=10); var patient_id rx_written_dt index_date rx_to_index_days; where cohort4="filled at index date"; run;

proc freq data=input.id_index; table cohort4; run;

data df2; set df; if cohort4="filled after RV/RJ in 90days"; run;
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
