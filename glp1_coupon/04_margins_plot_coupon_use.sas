
/*============================================================*
 |      margins plot with prob of coupon (event = coupon use) at claim level
 *============================================================*/

proc contents data=coupon.cohort_long_v01; run;

* with year - continuous variable; 
proc logistic data=coupon.cohort_long_v01;
    class diabetes_history (ref='0') patient_gender(ref='M') molecule (ref='SEMAGLUTIDE') / param=glm order=internal;
    model coupon(event='1') = year diabetes_history molecule patient_gender age_at_claim;
    store logit_model_all; 
run;

proc plm restore=logit_model_all;
    effectplot fit(x=year) / clm;
    ods output FITPLOT=pred_plot_all;
run;

proc sgplot data=pred_plot_all;
    band x=_XCONT1 lower=_LCLM upper=_UCLM / transparency=0.3;
    series x=_XCONT1 y=_PREDICTED / lineattrs=(thickness=2 color=blue);   
    yaxis values=(0 to 0.005 by 0.001) valuesformat=percent8.1 label="Predicted Probability of Coupon Use (%)";
    xaxis label="Year";
    title "Margins Plot for probability of coupon use over time (at claim level)";
run;

/*============================================================*
 |      margins plot with prob of coupon (event = coupon use) at patient level
 *============================================================*/
 
proc sort data=coupon.cohort_long_v01; by patient_id year; run;

data coupon.cohort_patient_year_v01;
  set coupon.cohort_long_v01;
  by patient_id year;

  if first.year then do;
    claim_count  = 0;
    coupon_count = 0;
  end;

  claim_count + 1;
  if coupon = 1 then coupon_count + 1;

  if last.year then do;
    last_date = svc_dt;
    output;
  end;
run;
data coupon.cohort_patient_year_v01; set coupon.cohort_patient_year_v01; if coupon_count > 0 then coupon_user = 1; else coupon_user = 0; run;
proc print data=coupon.cohort_patient_year_v01 (obs=10); var patient_id year claim_count coupon_count coupon_user; run;


/* logistic model */
proc logistic data=coupon.cohort_patient_year_v01;
    class diabetes_history (ref='0') patient_gender(ref='M') molecule (ref='SEMAGLUTIDE') / param=glm order=internal;
    model coupon_user(event='1') = year diabetes_history molecule patient_gender age_at_claim;
    store logit_model_patient; 
run;

proc plm restore=logit_model_patient; 
    effectplot fit(x=year) / clm;
    ods output FITPLOT=pred_plot_patient;
run;

proc sgplot data=pred_plot_patient;
    band x=_XCONT1 lower=_LCLM upper=_UCLM / transparency=0.3;
    series x=_XCONT1 y=_PREDICTED / lineattrs=(thickness=2 color=blue);   
    yaxis values=(0 to 0.07 by 0.01) valuesformat=percent8.1 label="Predicted Probability of Coupon Use (%)";
    xaxis label="Year";
    title "Margins Plot for probability of coupon use over time (at patient level)";
run;



data margins_year;
  set pred_plot_patient;
  year = floor(_XCONT1);
run;

proc sort data=margins_year;
  by year _XCONT1;
run;

data yearly_estimates;
  set margins_year;
  by year;
  if first.year;   /* January */
  pred_pct = _PREDICTED * 100;
  keep year _PREDICTED pred_pct _LCLM _UCLM;
run;

proc print data=yearly_estimates noobs;
  format pred_pct 6.2;
run;


