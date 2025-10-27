
/*============================================================*
 |      quaterly OOP with the primary cohort with only paid claims
 *============================================================*/
input.rx18_24_glp1_long_v00; 
* make quater indicator; 

data rx18_24_glp1_long_paid; set input.rx18_24_glp1_long_v00; if encnt_outcm_cd ="PD"; run; /* 8760132 obs */
proc sort data=rx18_24_glp1_long_paid; by patient_id svc_dt; run;


/*============================================================*
 |      quaterly OOP with the primary cohort with only paid claims
 *============================================================*/

 
/*==========================*
 |  oop clean first -> if multiple claims within the same date - need to sum up
 *==========================*/
data flag_gt2;
    set rx18_24_glp1_long_paid;
    by patient_id svc_dt;
    retain count;
    if first.svc_dt then count = 0;
    count + 1;
    if last.svc_dt then do;
        if count > 2 then output;
    end;
    keep patient_id svc_dt;
run;
proc sql;
    create table patients_gt2_all as
    select a.*
    from rx18_24_glp1_long_paid as a
    inner join flag_gt2 as b
    on a.patient_id = b.patient_id and a.svc_dt = b.svc_dt;
quit;

proc print data=patients_gt2_all (obs=10);run;

/* Step 1: Calculate oop_30day_v0 for each claim */
data rx18_24_glp1_long_paid_clean;
    set rx18_24_glp1_long_paid;
    oop_30day_v0 = final_opc_amt / days_supply_cnt * 30;
run;

/* Step 2: Sort before using BY statement */
proc sort data=rx18_24_glp1_long_paid_clean; by patient_id svc_dt; run;

/* Step 3: Aggregate to one row per patient_id + svc_dt */
data rx18_24_glp1_long_paid_clean;
    set rx18_24_glp1_long_paid_clean;
    by patient_id svc_dt;

    retain oop_sum count;
    if first.svc_dt then do;
        oop_sum = 0;
        count = 0;
    end;

    oop_sum + oop_30day_v0;
    count + 1;

    if last.svc_dt then do;
        oop_30day = oop_sum / count;
        output;
    end;

    keep patient_id svc_dt payer_type indication count oop_30day;
run;

proc print data=rx18_24_glp1_long_paid_clean (obs=10); where count >1;  run;
proc print data=rx18_24_glp1_long_paid (obs=10); where patient_id = 977415 and svc_dt = "18Sep2024"d;  run;


/*==========================*
 |  set the date - index, 3m, 6m
 *==========================*/
data rx18_24_glp1_long_paid_clean;
    set rx18_24_glp1_long_paid_clean;
    format start_date m3_after m6_after mmddyy10.;
    by patient_id;
    format start_date m3_after m6_after mmddyy10.;

    retain start_date m3_after m6_after;

    if first.patient_id then do;
        start_date = svc_dt;
        m3_after = start_date + 30*3;  /* Approx. 3 months */
        m6_after = start_date + 30*6;  /* Approx. 6 months */
    end;
run;

data rx18_24_glp1_long_paid_clean;
    set rx18_24_glp1_long_paid_clean;
    gap_from_m3 = abs(svc_dt - m3_after);
    gap_from_m6 = abs(svc_dt - m6_after);
run;

proc print data=rx18_24_glp1_long_paid_clean (obs=10);  run;

/*==========================*
 |  calculate OOP for eeach date
 *==========================*/
 /*--- Pick the closest claim to index (break ties by earliest date) ---*/
data index_candidates; set rx18_24_glp1_long_paid_clean; where svc_dt = start_date; run;
proc sort data=index_candidates; by patient_id svc_dt; run;

data index_best;
  set index_candidates;
  by patient_id svc_dt;
  format index_date mmddyy10.;
  if first.patient_id then do;
    index_date = svc_dt;
    oop_index     = oop_30day;
    output;
  end;
run;
proc print data=index_best (obs=10);  run;


 /*--- Pick the closest claim to 3 months (break ties by earliest date) ---*/
data m3_candidates; set rx18_24_glp1_long_paid_clean; where svc_dt < m3_after; run;
proc sort data=m3_candidates; by patient_id gap_from_m3 svc_dt; run;

data m3_best;
  set m3_candidates;
  by patient_id gap_from_m3 svc_dt;
  format svc_for_oop_m3 mmddyy10.;
  if first.patient_id then do;
    svc_for_oop_m3 = svc_dt;
    oop_m3      = oop_30day;
    output;
  end;
run;
proc print data=m3_best (obs=10);  run;

 /*--- Pick the closest claim to 6 months (break ties by earliest date) ---*/
data m6_candidates; set rx18_24_glp1_long_paid_clean; where svc_dt < m6_after; run;
proc sort data=m6_candidates; by patient_id gap_from_m6 svc_dt; run;

data m6_best;
  set m6_candidates;
  by patient_id gap_from_m6 svc_dt;
  format svc_for_oop_m6 mmddyy10.;
  if first.patient_id then do;
    svc_for_oop_m6 = svc_dt;
    oop_m6      = oop_30day;
    output;
  end;
run;
proc print data=m6_best (obs=10);  run;


/*==========================*
 |  /* Merge everything (index + 3M + 6M) */
 *==========================*/
proc sql;
    create table input.oop_summary as
    select distinct 
           i.patient_id,
           c.index_date, c.oop_index, c.payer_type as index_payer_type, c.indication as index_indication,
           a.svc_for_oop_m3, a.oop_m3, a.payer_type as m3_payer_type, a.indication as m3_indication,
           b.svc_for_oop_m6, b.oop_m6, b.payer_type as m6_payer_type, b.indication as m6_indication
    from input.patients_v0 as i
    left join index_best as c 
        on i.patient_id = c.patient_id
    left join m3_best as a 
        on i.patient_id = a.patient_id
    left join m6_best as b 
        on i.patient_id = b.patient_id;
quit;

proc print data=input.oop_summary (obs=10); run;

/*==========================*
 |  analysis
 *==========================*/
* index;
proc means data=input.oop_summary n nmiss median q1 q3 min max; var oop_index; run;
proc means data=input.oop_summary n nmiss median q1 q3 min max;
    class index_indication;
    var oop_index;
run;
proc means data=input.oop_summary n nmiss median q1 q3 min max;
    class index_payer_type;
    var oop_index;
run;

*share oop > $100 at index;
data input.oop_summary; set input.oop_summary; if oop_index > 100 then oop100_index = 1; else oop100_index =0; run;
proc freq data=input.oop_summary; table oop100_index; run;
proc freq data=input.oop_summary; table oop100_index*index_indication /norow nopercent; run;
proc freq data=input.oop_summary; table oop100_index*index_payer_type /norow nopercent; run;

* m3 after;
proc means data=input.oop_summary n nmiss median q1 q3 min max; var oop_m3; run;
proc means data=input.oop_summary n nmiss median q1 q3 min max;
    class m3_indication;
    var oop_m3;
run;
proc means data=input.oop_summary n nmiss median q1 q3 mean std min max;
    class m3_payer_type;
    var oop_m3;
run;

* m6 after;
proc means data=input.oop_summary n nmiss median q1 q3 min max; var oop_m6; run;
proc means data=input.oop_summary n nmiss median q1 q3 min max;
    class m6_indication;
    var oop_m6;
run;
proc means data=input.oop_summary n nmiss median q1 q3 min max;
    class m6_payer_type;
    var oop_m6;
run;

*share oop > $200 at m6;
data input.oop_summary; set input.oop_summary; if oop_m6 > 200 then oop200_m6 = 1; else oop200_m6 =0; run;
proc freq data=input.oop_summary; table oop200_m6; run;
proc freq data=input.oop_summary; table oop200_m6*m6_indication /norow nopercent; run;
proc freq data=input.oop_summary; table oop200_m6*m6_payer_type /norow nopercent; run;

* quantile based on oop at index;
proc univariate data=input.oop_summary noprint;
    var oop_index;
    output out=quantiles pctlpre=P_ pctlpts=25 50 75;
run;
proc print data=quantiles (obs=10); run;
data input.oop_summary; set input.oop_summary; 
 if oop_index <= 0 then oop_index_q = 1; 
 else if 0 < oop_index <= 19.995 then oop_index_q = 2; 
 else if 19.995 < oop_index <= 26.7857 then oop_index_q = 3; 
 else oop_index_q = 4; 
run;
proc freq data=input.oop_summary; table oop_index_q; run;

* oop_index_q = 1 ~ 4; 
data oop_summary; set input.oop_summary; if oop_index_q = 4;  run;
proc means data=oop_summary n nmiss median q1 q3 min max; var oop_index; run;
proc means data=oop_summary n nmiss median q1 q3 min max; var oop_m3; run;
proc means data=oop_summary n nmiss median q1 q3 min max; var oop_m6; run;
proc freq data=oop_summary; table oop100_index; run;
proc freq data=oop_summary; table oop200_m6; run;



/*============================================================*
 |      margins plot with prob of rejection (event = rejection)
 *============================================================*/
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; if encnt_outcm_cd = 'RJ' then reject = 1; else reject =0; run;
proc freq data=input.rx18_24_glp1_long_v00; table reject; run;

/*==========================*
 |  overall
 *==========================*/
* preprocessing for fitting;
proc logistic data=input.rx18_24_glp1_long_v00;
    class plan_type (ref='Commercial') indication (ref='diabetes') patient_gender(ref='M') molecule (ref='SEMAGLUTIDE') year (ref='2017') / param=glm order=internal;
    model reject(event='1') = year plan_type indication patient_gender age_at_claim;
    store logit_model_all; 
run;

proc plm restore=logit_model_all;
    lsmeans year / ilink cl;
    ods output lsmeans=pred_probs_all;
run;
data pred_probs_all_v1; set pred_probs_all; if year ne 2017; run;

proc sgplot data=pred_probs_all_v1; 
 series x=year y=Mu / lineattrs=(thickness=2) name="lines";
 scatter x=year y=Mu /  markerattrs=(symbol=circlefilled) legendlabel="" name = "dots";
 band x=year upper=UpperMu lower=LowerMu / 
        transparency=0.4 
        legendlabel="95% CI";
 xaxis type=discrete label ="Year";
 yaxis label = "Predicted Probability of Claim denial" min = 0 max=0.35;
 keylegend / position = bottom;
run;

* with year - continuous variable; 
proc logistic data=input.rx18_24_glp1_long_v00;
    class payer_type (ref='Commercial') indication (ref='diabetes') patient_gender(ref='M') molecule (ref='SEMAGLUTIDE') / param=glm order=internal;
    model reject(event='1') = year payer_type indication patient_gender age_at_claim;
    store logit_model_all; 
run;

proc plm restore=logit_model_all;
    effectplot fit(x=year) / clm;
    ods output FITPLOT=pred_plot_all;
run;

proc sgplot data=pred_plot_all;
    band x=_XCONT1 lower=_LCLM upper=_UCLM / transparency=0.3;
    series x=_XCONT1 y=_PREDICTED / lineattrs=(thickness=2 color=blue);
    yaxis label="Predicted Probability of Rejection" min=0 max=0.1;
    xaxis label="Year";
run;


/*==========================*
 |  by payer_type | https://communities.sas.com/t5/Statistical-Procedures/Editing-slicefit-type-of-effectplot-in-proc-plm-through-proc/td-p/902652
 *==========================*/
proc contents data=input.rx18_24_glp1_long_v00; run;

data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00;
    length dominant_payer_adj $100.; 
    if dominant_payer in ("Medicaid: FFS","Medicaid: MCO","Medicaid: Unspec") then dominant_payer_adj = "Medicaid"; 
    else if dominant_payer in ("Medicare D: ADV","Medicare D: TM","Medicare D: Unspec") then dominant_payer_adj = "Medicare"; 
    else dominant_payer_adj = dominant_payer; 
run;
data input.rx18_24_glp1_long_v00; set input.rx18_24_glp1_long_v00; oop_30day = final_opc_amt / days_supply_cnt * 30; run;
 

* preprocessing for fitting;
proc logistic data=input.rx18_24_glp1_long_v00;
    class dominant_payer_adj (ref='Commercial') diabetes_history (ref='1') patient_gender(ref='M') molecule (ref='SEMAGLUTIDE') / param=glm order=internal;
    model reject(event='1') = dominant_payer_adj diabetes_history patient_gender age_at_claim year*dominant_payer_adj;
    store logit_model; 
run;

proc plm restore=logit_model;
    effectplot slicefit(x=year sliceby=dominant_payer_adj)  / clm;
    ods output sliceFITPLOT=pred_plot_payer;
run;

PROC SGPLOT DATA=pred_plot_payer;
BAND UPPER = _UCLM LOWER = _LCLM X=_XCONT1/TRANSPARENCY=.3 group=_group;
SERIES Y = _PREDICTED X=_XCONT1/group=_group;
run;


/*==========================*
 |  by diabetes_history
 *==========================*/

proc logistic data=input.rx18_24_glp1_long_v00;
    class dominant_payer_adj (ref='Commercial') diabetes_history (ref='1') patient_gender(ref='M') molecule (ref='SEMAGLUTIDE') / param=glm order=internal;
    model reject(event='1') = dominant_payer_adj diabetes_history patient_gender age_at_claim year*diabetes_history;
    store logit_model; 
run;

proc plm restore=logit_model;
    effectplot slicefit(x=year sliceby=diabetes_history) / clm;
    ods output sliceFITPLOT=pred_plot_dm;
run;

PROC SGPLOT DATA=pred_plot_dm;
BAND UPPER = _UCLM LOWER = _LCLM X=_XCONT1/TRANSPARENCY=.3 group=_group;
SERIES Y = _PREDICTED X=_XCONT1/group=_group;
run;

