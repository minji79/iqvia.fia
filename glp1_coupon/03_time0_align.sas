coupon.cohort_long_v01
proc contents data=coupon.cohort_long_v01; run;
proc print data=coupon.cohort_long_v01 (obs=10); run;

coupon.monthly_aggregated_oop_long
proc print data=coupon.monthly_aggregated_oop_long (obs=10); run;

oop_bf_coupon_30day_per_claim
 

/*============================================================*
 | 1) eFigure 3. Area plot for stacked by coupon with month_id in calender month
 *============================================================*/

/* 1) Aggregate counts by month & category */
proc sql;
    create table counts as
    select month_id,
           coupon,
           count(*) as count
    from coupon.cohort_long_v01
    group by month_id, coupon
    order by month_id, calculated count desc;
quit;

/* 2) Convert YYYYMM month_id to SAS date (first day of month) */
data counts_d;
  set counts;
  length month_dt 8;
  /* Works for numeric or character month_id */
  if vtype(month_id)='N' then month_dt = input(put(month_id, 6.), yymmn6.);
  else                       month_dt = input(month_id, yymmn6.);
  format month_dt monyy7.; /* Displays as MONYYYY */
run;

/* 3) Sort for stacking */
proc sort data=counts_d; 
    by month_dt coupon; 
run;

/* 4) Build cumulative lower/upper bounds for stacking */
data cum;
  set counts_d;
  by month_dt;
  retain lower 0;
  if first.month_dt then lower=0;
  upper = lower + count;
  output;
  lower = upper;
run;

/* 5) Stacked area plot using BAND */
proc sgplot data=cum;
  band x=month_dt lower=lower upper=upper / group=coupon transparency=0.1;
  xaxis type=time interval=month valuesformat=monyy7.;
  yaxis label="Count";
run;



/*============================================================*
 | 2) time 0 (index_date) ~ 
 *============================================================*/
 proc print data=coupon.cohort_wide_v00 (obs=10); var patient_id svc_dt index_date; run;

* merge with index_date;
proc sql;
   create table coupon.cohort_long_v01 as
   select distinct a.*, b.index_date
   from coupon.cohort_long_v01 as a
   left join coupon.cohort_wide_v00 as b
   on a.patient_id = b.patient_id;
quit;

proc sql;
  create table oop_after_m1 as
  select distinct
    b.patient_id,
    b.coupon_user,
    b.diabetes_history,
    b.molecule_name,
    b.index_date,
    1 as month,
    count(*) as claim_count,
    sum(coupon=1) as coupon_count,
    sum(primary_coupon=1) as coupon_1_count,
    sum(secondary_coupon=1) as coupon_2_count,
    sum(drug_cost) as accumulated_drug_cost,
    sum(drug_cost_30day) as accumulated_drug_cost_30day,
    sum(oop_30day) as accumulated_oop_30day,
    sum(final_opc_amt) as accumulated_oop_act,
    sum(oop_bf_coupon_30day) as accumulated_oop_bf_coupon_30day,
    sum(oop_bf_coupon) as accumulated_oop_bf_coupon_act,
    sum(primary_coupon_offset) as accumulated_coupon_1_offset,
    sum(secondary_coupon_offset) as accumulated_coupon_2_offset,
    sum(payer_cost) as accumulated_payer_cost
    
  from coupon.cohort_long_v01 b
  where svc_dt >= index_date and svc_dt <= index_date +30
  group by b.patient_id;
quit;


%macro monthly (data= , time=, month=);
proc sql;
  create table &data as
  select distinct
    b.patient_id,
    b.coupon_user,
    b.diabetes_history,
    b.molecule_name,
    b.index_date,
    &month as month,
    count(*) as claim_count,
    sum(coupon=1) as coupon_count,
    sum(primary_coupon=1) as coupon_1_count,
    sum(secondary_coupon=1) as coupon_2_count,
    sum(drug_cost) as accumulated_drug_cost,
    sum(drug_cost_30day) as accumulated_drug_cost_30day,
    sum(oop_30day) as accumulated_oop_30day,
    sum(final_opc_amt) as accumulated_oop_act,
    sum(oop_bf_coupon_30day) as accumulated_oop_bf_coupon_30day,
    sum(oop_bf_coupon) as accumulated_oop_bf_coupon_act,
    sum(primary_coupon_offset) as accumulated_coupon_1_offset,
    sum(secondary_coupon_offset) as accumulated_coupon_2_offset,
    sum(payer_cost) as accumulated_payer_cost
    
  from coupon.cohort_long_v01 b
  where svc_dt >= &time and svc_dt <= &time +30
  group by b.patient_id;
quit;

%mend monthly;
%monthly (data=oop_after_m2, time=index_date+30*1, month=2);
%monthly (data=oop_after_m3, time=index_date+30*2, month=3);
%monthly (data=oop_after_m4, time=index_date+30*3, month=4);
%monthly (data=oop_after_m5, time=index_date+30*4, month=5);
%monthly (data=oop_after_m6, time=index_date+30*5, month=6);
%monthly (data=oop_after_m7, time=index_date+30*6, month=7);
%monthly (data=oop_after_m8, time=index_date+30*7, month=8);
%monthly (data=oop_after_m9, time=index_date+30*8, month=9);
%monthly (data=oop_after_m10, time=index_date+30*9, month=10);
%monthly (data=oop_after_m11, time=index_date+30*10, month=11);
%monthly (data=oop_after_m12, time=index_date+30*11, month=12);
%monthly (data=oop_after_m13, time=index_date+30*12, month=13);
%monthly (data=oop_after_m14, time=index_date+30*13, month=14);
%monthly (data=oop_after_m15, time=index_date+30*14, month=15);
%monthly (data=oop_after_m16, time=index_date+30*15, month=16);
%monthly (data=oop_after_m17, time=index_date+30*16, month=17);
%monthly (data=oop_after_m18, time=index_date+30*17, month=18);
%monthly (data=oop_after_m19, time=index_date+30*18, month=19);
%monthly (data=oop_after_m20, time=index_date+30*19, month=20);
%monthly (data=oop_after_m21, time=index_date+30*20, month=21);
%monthly (data=oop_after_m22, time=index_date+30*21, month=22);
%monthly (data=oop_after_m23, time=index_date+30*22, month=23);
%monthly (data=oop_after_m24, time=index_date+30*23, month=24);

data coupon.monthly_aggregated_oop_long;
  set oop_after_m1 oop_after_m2 oop_after_m3 oop_after_m4 oop_after_m5
      oop_after_m6 oop_after_m7 oop_after_m8 oop_after_m9 oop_after_m10
      oop_after_m11 oop_after_m12 oop_after_m13 oop_after_m14 oop_after_m15
      oop_after_m16 oop_after_m17 oop_after_m18 oop_after_m19 oop_after_m20
      oop_after_m21 oop_after_m22 oop_after_m23 oop_after_m24;
run;

proc sort data=coupon.monthly_aggregated_oop_long; by patient_id month; run;
data coupon.monthly_aggregated_oop_long; set coupon.monthly_aggregated_oop_long; accumulated_coupon_offset = sum(accumulated_coupon_1_offset, accumulated_coupon_2_offset); run;

* proportion of coupon in count and $;
data coupon.monthly_aggregated_oop_long; set coupon.monthly_aggregated_oop_long; drop  coupon_count_pct coupon_offset_pct; run;
data coupon.monthly_aggregated_oop_long; set coupon.monthly_aggregated_oop_long; 
  if claim_count > 0 then coupon_count_pct = (coupon_count / claim_count) * 100;
  else coupon_count_pct = .;
  
  if coupon_count > 0 and accumulated_drug_cost > 0 then 
    coupon_offset_pct = (accumulated_coupon_offset / accumulated_drug_cost) * 100;
  else coupon_offset_pct = .;

  format coupon_count_pct coupon_offset_pct 8.2;
run;
proc print data=coupon.monthly_aggregated_oop_long (obs=20); run;

* indication;
data coupon.monthly_aggregated_oop_long; set coupon.monthly_aggregated_oop_long; 
length indication $100.; if molecule_name in ("LIRAGLUTIDE (WEIGHT MANAGEMENT)","SEMAGLUTIDE (WEIGHT MANAGEMENT)","TIRZEPATIDE (WEIGHT MANAGEMENT)") then indication = "obesity"; else indication = "diabetes"; run;
proc freq data=coupon.monthly_aggregated_oop_long; table indication; run;


/*============================================================*
 | 3) eFigure 4. Histogram monthly coupon & claim count - patient level
 *============================================================*/
/* among coupon users */
data coupon_users; set coupon.monthly_aggregated_oop_long; if coupon_user =1; run;

proc sql;
  create table coupon.monthly_patient_counts as
  select
      month,
      count(distinct patient_id) as n_patients,
      count(distinct case when coupon_count>0 then patient_id end) as n_coupon_users
  from coupon_users
  group by month
  order by month;
quit;


proc sgplot data=coupon.monthly_patient_counts;
  vbar month / response=n_patients
      groupdisplay=cluster barwidth=0.55
      fillattrs=(color=cx1F77B4) transparency=0.1
      legendlabel="Total Patients (N)";

  vbar month / response=n_coupon_users
      groupdisplay=cluster barwidth=0.40
      fillattrs=(color=cxFF7F0E) transparency=0.1
      legendlabel="Coupon Users (N)";

  xaxis label="Month since initiation" integer;
  yaxis label="Number of Patients" grid;
  keylegend / position=topright across=1 title="Patient Counts";
  title "Monthly Total Patients vs Coupon Users";
run;

* % ; 
data coupon.monthly_patient_counts2;
  set coupon.monthly_patient_counts;
  pct_coupon_users = n_coupon_users / n_patients;
  pct_label = cats(put(pct_coupon_users, percent6.1));
run;
proc print data=coupon.monthly_patient_counts2; run;



/*============================================================*
 | 4) Figure 1-1. (among coupon users) Line graph for mean OOP trajectory with 95%ci - payer_cost, coupon offset, oop
 *============================================================*/
* among only coupon users;
data sample; set coupon.monthly_aggregated_oop_long; if coupon_user =1; run;

* among free-trial coupon: accumulated_coupon_offset -> accumulated_coupon_1_offset; 
* among free-trial coupon: accumulated_coupon_offset -> accumulated_coupon_2_offset; 

proc means data=sample noprint;
    class month;
    var accumulated_payer_cost accumulated_oop_act accumulated_coupon_offset;
    output out=monthly_summarized2
        mean=mean_payer_cost mean_oop_act mean_coupon_offset
        std =sd_payer_cost  sd_oop_act  sd_coupon_offset
        n   =n_payer_cost   n_oop_act   n_coupon_offset;
run;


/* keep only summary rows */
data monthly_summarized2;
    set monthly_summarized2;
    if _TYPE_=1;
run;


data monthly_summarized2;
    set monthly_summarized2;

    /* Standard Error */
    se_payer     = sd_payer_cost / sqrt(n_payer_cost);
    se_oop      = sd_oop_act / sqrt(n_oop_act);
    se_coupon   = sd_coupon_offset / sqrt(n_coupon_offset);

    /* 95% CI */
    lower_payer  = mean_payer_cost     - 1.96*se_payer;
    upper_payer  = mean_payer_cost     + 1.96*se_payer;

    lower_oop   = mean_oop_act       - 1.96*se_oop;
    upper_oop   = mean_oop_act       + 1.96*se_oop;

    lower_coupon = mean_coupon_offset - 1.96*se_coupon;
    upper_coupon = mean_coupon_offset + 1.96*se_coupon;

run;

data monthly_long2;
    set monthly_summarized2;
    length measure $40 value lower upper 8;

    /* Drug spending */
    measure="Payer's Spending";
    value  =mean_payer_cost;
    lower  =lower_payer;
    upper  =upper_payer;
    output;

    /* OOP actual */
    measure="Out-of-Pocket costs";
    value  =mean_oop_act;
    lower  =lower_oop;
    upper  =upper_oop;
    output;

    /* Coupon offset */
    measure="Coupon Offset (manufacturers' cost)";
    value  =mean_coupon_offset;
    lower  =lower_coupon;
    upper  =upper_coupon;
    output;
run;

proc sgplot data=monthly_long2;
    styleattrs datacontrastcolors=(cx1f77b4 cxff7f0e cx2ca02c cxb565a7);

    /* CI bands */
    band x=month lower=lower upper=upper / 
         group=measure transparency=0.75
         name="bands" legendlabel=" ";

    /* Mean lines with markers */
    series x=month y=value /
           group=measure 
           lineattrs=(thickness=2)
           markers markerattrs=(symbol=circlefilled size=6)
           name="lines";

    /* Legend WITHOUT dots */
    keylegend "lines" / type=line position=topright across=1;

    xaxis label="Month Since Initiation" integer;
    yaxis label="Dollars ($)" grid;
    title "Monthly Mean of Out-of-Pocket costs, Coupon Offset, and Payer's spending (Among Coupon Users)";
run;

/* monthly average savings per patient = Coupon Offset (manufacturers' cost) */
data coupon_offset; set monthly_long2; if measure = "Coupon Offset (manufacturers' cost)"; keep month value lower upper; run;
proc print data=coupon_offset; title "Coupon Offset (manufacturers' cost)"; run;

proc means data=coupon_offset n mean lclm uclm;
    where month in (2,3,4,5,6,7,8);
    var value;
run;

/* Payer's Spending */
data coupon_offset; set monthly_long2; if measure = "Payer's Spending"; keep month value lower upper; run;
proc print data=coupon_offset; title "Payer's Spending"; run;

proc means data=coupon_offset n mean lclm uclm;
    where month in (1,2,3);
    var value;
run;

proc means data=coupon_offset n mean lclm uclm;
    where month in (9,10,11,12);
    var value;
run;

/* Out-of-Pocket costs */
data coupon_offset; set monthly_long2; if measure = "Out-of-Pocket costs"; keep month value lower upper; run;
proc print data=coupon_offset; title "Out-of-Pocket costs"; run;

proc means data=coupon_offset n mean lclm uclm std;
    var value;
run;

/*============================================================*
 | 4) Figure 1-1'. (among coupon users) Line graph for mean OOP trajectory with 95%ci - payer_cost, coupon offset, oop
 *============================================================*/

* among only coupon users;
data sample; set coupon.monthly_aggregated_oop_long; if coupon_user =1; run;

proc sql;
  create table riskset_month as
  select
      month,
      count(distinct patient_id) as n_patients
  from sample
  group by month
  order by month;
quit;

proc means data=sample noprint;
    class month;
    var accumulated_payer_cost accumulated_oop_act accumulated_coupon_offset;
    output out=monthly_summarized
        mean=mean_payer_cost mean_oop_act mean_coupon_offset
        std =sd_payer_cost  sd_oop_act  sd_coupon_offset
        n   =n_payer_cost   n_oop_act   n_coupon_offset;
run;

/* keep only summary rows */
data monthly_summarized; set monthly_summarized; if _TYPE_=1; run;

/* keep only up to 18 month */
data monthly_summarized; set monthly_summarized; if 0 <= month and month <= 18; run;
data riskset_month; set riskset_month; if 0 <= month and month <= 18; run;


data monthly_summarized;
    set monthly_summarized;

    /* Standard Error */
    se_payer     = sd_payer_cost / sqrt(n_payer_cost);
    se_oop      = sd_oop_act / sqrt(n_oop_act);
    se_coupon   = sd_coupon_offset / sqrt(n_coupon_offset);

    /* 95% CI */
    lower_payer  = mean_payer_cost     - 1.96*se_payer;
    upper_payer  = mean_payer_cost     + 1.96*se_payer;

    lower_oop   = mean_oop_act       - 1.96*se_oop;
    upper_oop   = mean_oop_act       + 1.96*se_oop;

    lower_coupon = mean_coupon_offset - 1.96*se_coupon;
    upper_coupon = mean_coupon_offset + 1.96*se_coupon;

run;

data monthly_long;
    set monthly_summarized;
    length measure $40 value lower upper 8;

    /* Drug spending */
    measure="Payer's Spending";
    value  =mean_payer_cost;
    lower  =lower_payer;
    upper  =upper_payer;
    output;

    /* OOP actual */
    measure="Out-of-Pocket costs";
    value  =mean_oop_act;
    lower  =lower_oop;
    upper  =upper_oop;
    output;

    /* Coupon offset */
    measure="Coupon Offset (manufacturers' cost)";
    value  =mean_coupon_offset;
    lower  =lower_coupon;
    upper  =upper_coupon;
    output;
run;

/* Ensure sorted */
proc sort data=riskset_month; by month; run;
proc sort data=monthly_long;  by month measure; run;

data plotdata;
  merge monthly_long(in=b) riskset_month(in=a);
  by month;
  if b;                  /* keep line rows (so measures plot correctly) */
run;

/* 1) Make LOW/HIGH variables for the bar, only on one measure row */
data plotdata2;
  set plotdata;
  low_pat  = .;
  high_pat = .;

  /* draw the bar only once per month (pick one measure row) */
  if measure = "Payer's Spending" then do;
    low_pat  = 0;
    high_pat = n_patients;
  end;
run;

proc sgplot data=plotdata2 noautolegend;
  styleattrs datacontrastcolors=(cx1f77b4 cxff7f0e cx2ca02c cxb565a7);

  /* Bars: risk set (LEFT axis) */
  highlow x=month low=low_pat high=high_pat /
    type=bar
    barwidth=0.9
    fillattrs=(color=cxA6A6A6)
    lineattrs=(color=cxA6A6A6)
    transparency=0.80
    y2axis
    name="bars";

  /* CI ribbons: costs (RIGHT axis) */
  band x=month lower=lower upper=upper /
    group=measure
    transparency=0.75
    name="bands";

  /* Mean cost lines: costs (RIGHT axis) */
  series x=month y=value /
    group=measure
    lineattrs=(thickness=2)
    markers
    markerattrs=(symbol=circlefilled size=6)
    name="lines";

  keylegend "lines" / type=line position=topright across=1;

  xaxis label="Month Since Initiation" integer values=(1 to 18 by 1);
  yaxis label="Dollars ($)" grid values=(0 to 1200 by 200);
  y2axis label="Number of Patients (Risk set)" grid values=(0 to 24000 by 4000);

  title "Monthly Mean OOP, Coupon Offset, and Payer Spending (Among All Coupon Users)";
run;


/*============================================================*
 | 4) Figure 1-2'. (among obesity indication | diabetes indication) Line graph for mean OOP trajectory with 95%ci - payer_cost, coupon offset, oop
 *============================================================*/

* among only coupon users;
data sample; set coupon.monthly_aggregated_oop_long; if coupon_user =1; run;
data sample; set sample; if indication = "obesity"; run;

proc sql;
  create table riskset_month as
  select
      month,
      count(distinct patient_id) as n_patients
  from sample
  group by month
  order by month;
quit;

proc means data=sample noprint;
    class month;
    var accumulated_payer_cost accumulated_oop_act accumulated_coupon_offset;
    output out=monthly_summarized
        mean=mean_payer_cost mean_oop_act mean_coupon_offset
        std =sd_payer_cost  sd_oop_act  sd_coupon_offset
        n   =n_payer_cost   n_oop_act   n_coupon_offset;
run;

/* keep only summary rows */
data monthly_summarized; set monthly_summarized; if _TYPE_=1; run;

/* keep only up to 18 month */
data monthly_summarized; set monthly_summarized; if 0 <= month and month <= 18; run;
data riskset_month; set riskset_month; if 0 <= month and month <= 18; run;


data monthly_summarized;
    set monthly_summarized;

    /* Standard Error */
    se_payer     = sd_payer_cost / sqrt(n_payer_cost);
    se_oop      = sd_oop_act / sqrt(n_oop_act);
    se_coupon   = sd_coupon_offset / sqrt(n_coupon_offset);

    /* 95% CI */
    lower_payer  = mean_payer_cost     - 1.96*se_payer;
    upper_payer  = mean_payer_cost     + 1.96*se_payer;

    lower_oop   = mean_oop_act       - 1.96*se_oop;
    upper_oop   = mean_oop_act       + 1.96*se_oop;

    lower_coupon = mean_coupon_offset - 1.96*se_coupon;
    upper_coupon = mean_coupon_offset + 1.96*se_coupon;

run;

data monthly_long;
    set monthly_summarized;
    length measure $40 value lower upper 8;

    /* Drug spending */
    measure="Payer's Spending";
    value  =mean_payer_cost;
    lower  =lower_payer;
    upper  =upper_payer;
    output;

    /* OOP actual */
    measure="Out-of-Pocket costs";
    value  =mean_oop_act;
    lower  =lower_oop;
    upper  =upper_oop;
    output;

    /* Coupon offset */
    measure="Coupon Offset (manufacturers' cost)";
    value  =mean_coupon_offset;
    lower  =lower_coupon;
    upper  =upper_coupon;
    output;
run;

/* Ensure sorted */
proc sort data=riskset_month; by month; run;
proc sort data=monthly_long;  by month measure; run;

data plotdata;
  merge monthly_long(in=b) riskset_month(in=a);
  by month;
  if b;                  /* keep line rows (so measures plot correctly) */
run;

/* 1) Make LOW/HIGH variables for the bar, only on one measure row */
data plotdata2;
  set plotdata;
  low_pat  = .;
  high_pat = .;

  /* draw the bar only once per month (pick one measure row) */
  if measure = "Payer's Spending" then do;
    low_pat  = 0;
    high_pat = n_patients;
  end;
run;

proc sgplot data=plotdata2 noautolegend;
  styleattrs datacontrastcolors=(cx1f77b4 cxff7f0e cx2ca02c cxb565a7);

  /* Bars: risk set (LEFT axis) */
  highlow x=month low=low_pat high=high_pat /
    type=bar
    barwidth=0.9
    fillattrs=(color=cxA6A6A6)
    lineattrs=(color=cxA6A6A6)
    transparency=0.80
    y2axis
    name="bars";

  /* CI ribbons: costs (RIGHT axis) */
  band x=month lower=lower upper=upper /
    group=measure
    transparency=0.75
    name="bands";

  /* Mean cost lines: costs (RIGHT axis) */
  series x=month y=value /
    group=measure
    lineattrs=(thickness=2)
    markers
    markerattrs=(symbol=circlefilled size=6)
    name="lines";

  keylegend "lines" / type=line position=topright across=1;

  xaxis label="Month Since Initiation" integer values=(1 to 18 by 1);
  yaxis label="Dollars ($)" grid values=(0 to 1200 by 200);
  y2axis label="Number of Patients (Risk set)" grid values=(0 to 24000 by 4000);

  title "Monthly Mean OOP, Coupon Offset, and Payer Spending (Among Coupon Users for obesity-indicated GLP-1 RAs)";
run;


 
/*============================================================*
 | 5) Figure 1-4. (among non-users) Line graph for mean OOP trajectory with 95%ci - payer_cost, coupon offset, oop
 *============================================================*/
* among non-coupon users;
data sample; set coupon.monthly_aggregated_oop_long; if coupon_user =0; run;

proc means data=sample noprint;
    class month;
    var accumulated_payer_cost accumulated_oop_act accumulated_coupon_offset;
    output out=monthly_summarized2
        mean=mean_payer_cost mean_oop_act mean_coupon_offset
        std =sd_payer_cost  sd_oop_act  sd_coupon_offset
        n   =n_payer_cost   n_oop_act   n_coupon_offset;
run;


/* keep only summary rows */
data monthly_summarized2;
    set monthly_summarized2;
    if _TYPE_=1;
run;


data monthly_summarized2;
    set monthly_summarized2;

    /* Standard Error */
    se_payer     = sd_payer_cost / sqrt(n_payer_cost);
    se_oop      = sd_oop_act / sqrt(n_oop_act);
    se_coupon   = sd_coupon_offset / sqrt(n_coupon_offset);

    /* 95% CI */
    lower_payer  = mean_payer_cost     - 1.96*se_payer;
    upper_payer  = mean_payer_cost     + 1.96*se_payer;

    lower_oop   = mean_oop_act       - 1.96*se_oop;
    upper_oop   = mean_oop_act       + 1.96*se_oop;

    lower_coupon = mean_coupon_offset - 1.96*se_coupon;
    upper_coupon = mean_coupon_offset + 1.96*se_coupon;

run;

data monthly_long2;
    set monthly_summarized2;
    length measure $40 value lower upper 8;

    /* Drug spending */
    measure="Payer's Spending";
    value  =mean_payer_cost;
    lower  =lower_payer;
    upper  =upper_payer;
    output;

    /* OOP actual */
    measure="Out-of-Pocket costs";
    value  =mean_oop_act;
    lower  =lower_oop;
    upper  =upper_oop;
    output;
    
run;

proc sgplot data=monthly_long2;
    styleattrs datacontrastcolors=(cx1f77b4 cxff7f0e cx2ca02c cxb565a7);

    /* CI bands */
    band x=month lower=lower upper=upper / 
         group=measure transparency=0.75
         name="bands" legendlabel=" ";

    /* Mean lines with markers */
    series x=month y=value /
           group=measure 
           lineattrs=(thickness=2)
           markers markerattrs=(symbol=circlefilled size=6)
           name="lines";

    /* Legend WITHOUT dots */
    keylegend "lines" / type=line position=topright across=1;

    xaxis label="Month Since Initiation" integer;
    yaxis label="Dollars ($)" grid;
    title "Monthly Mean of Out-of-Pocket costs and Payer's spending (Among Non-Users)";
run;



* among only coupon users;
data sample; set coupon.monthly_aggregated_oop_long; if coupon_user =0; run;

proc sql;
  create table riskset_month as
  select
      month,
      count(distinct patient_id) as n_patients
  from sample
  group by month
  order by month;
quit;

proc means data=sample noprint;
    class month;
    var accumulated_payer_cost accumulated_oop_act accumulated_coupon_offset;
    output out=monthly_summarized2
        mean=mean_payer_cost mean_oop_act mean_coupon_offset
        std =sd_payer_cost  sd_oop_act  sd_coupon_offset
        n   =n_payer_cost   n_oop_act   n_coupon_offset;
run;

/* keep only summary rows */
data monthly_summarized; set monthly_summarized; if _TYPE_=1; run;

/* keep only up to 18 month */
data monthly_summarized; set monthly_summarized; if 0 <= month and month <= 18; run;
data riskset_month; set riskset_month; if 0 <= month and month <= 18; run;


data monthly_summarized;
    set monthly_summarized;

    /* Standard Error */
    se_payer     = sd_payer_cost / sqrt(n_payer_cost);
    se_oop      = sd_oop_act / sqrt(n_oop_act);
    se_coupon   = sd_coupon_offset / sqrt(n_coupon_offset);

    /* 95% CI */
    lower_payer  = mean_payer_cost     - 1.96*se_payer;
    upper_payer  = mean_payer_cost     + 1.96*se_payer;

    lower_oop   = mean_oop_act       - 1.96*se_oop;
    upper_oop   = mean_oop_act       + 1.96*se_oop;

    lower_coupon = mean_coupon_offset - 1.96*se_coupon;
    upper_coupon = mean_coupon_offset + 1.96*se_coupon;

run;

data monthly_long;
    set monthly_summarized;
    length measure $40 value lower upper 8;
    
 /* Drug spending */
    measure="Payer's Spending";
    value  =mean_payer_cost;
    lower  =lower_payer;
    upper  =upper_payer;
    output;
    
    /* OOP actual */
    measure="Out-of-Pocket costs";
    value  =mean_oop_act;
    lower  =lower_oop;
    upper  =upper_oop;
    output;

run;

/* Ensure sorted */
proc sort data=riskset_month; by month; run;
proc sort data=monthly_long;  by month measure; run;

data plotdata;
  merge monthly_long(in=b) riskset_month(in=a);
  by month;
  if b;                  /* keep line rows (so measures plot correctly) */
run;

/* 1) Make LOW/HIGH variables for the bar, only on one measure row */
data plotdata2;
  set plotdata;
  low_pat  = .;
  high_pat = .;

  /* draw the bar only once per month (pick one measure row) */
  if measure = "Payer's Spending" then do;
    low_pat  = 0;
    high_pat = n_patients;
  end;
run;


proc sgplot data=plotdata2 noautolegend;
  styleattrs datacontrastcolors=(cxff7f0e cx2ca02c);
  
  /* Bars: risk set (LEFT axis) */
  highlow x=month low=low_pat high=high_pat /
    type=bar
    barwidth=0.9
    fillattrs=(color=cxA6A6A6)
    lineattrs=(color=cxA6A6A6)
    transparency=0.80
    y2axis
    name="bars";

  /* CI ribbons: costs (RIGHT axis) */
  band x=month lower=lower upper=upper /
    group=measure
    transparency=0.75
    name="bands";

  /* Mean cost lines: costs (RIGHT axis) */
  series x=month y=value /
    group=measure
    lineattrs=(thickness=2)
    markers
    markerattrs=(symbol=circlefilled size=6)
    name="lines";

  keylegend "lines" / type=line position=topright across=1;

  xaxis label="Month Since Initiation" integer values=(1 to 18 by 1);
  yaxis label="Dollars ($)" grid values=(0 to 1200 by 200);
  y2axis label="Number of Patients (Risk set)" grid values=(0 to 360000 by 60000);

  title "Monthly Mean OOP, Coupon Offset, and Payer Spending (Among Non-Users)";
run;






/*==============================*
  # of patients per month - risk set
 *==============================*/
 proc sql;
    create table patient_count_per_month as
    select month,
           count(distinct patient_id) as n_patients
    from coupon.monthly_aggregated_oop_long
    group by month
    order by month;
quit;

proc transpose data=patient_count_per_month
               out=monthly_n_transposed
               prefix=month_;
    id month;          /* month becomes column names */
    var n_patients;    /* values to transpose */
run;

proc print data=monthly_n_transposed; run;



/*============================================================*
 | 6) Figure 1-2. Line graph for mean OOP trajectory with 95%ci - payer_cost, coupon offset, oop
 *============================================================*/

proc print data=coupon.cohort_long_v01 (obs=10); run;

* long dataset| see only primary coupon users;
data id_primary; set coupon.cohort_long_v01; if primary_coupon =1; run;
data id_primary; set id_primary; keep patient_id; run;
proc sort data=id_primary nodupkey; by _ALL_; run; /* 17924 individuals who ever used primary coupons */


proc sql;
    create table primary_users as
    select distinct a.*
    from coupon.cohort_long_v01 as a
    left join id_primary as b
        on a.patient_id = b.patient_id
    where b.patient_id is not null;
quit;

proc sort data=primary_users; by patient_id svc_dt; run;
proc print data=primary_users (obs=30); var patient_id svc_dt primary_coupon secondary_coupon drug_cost primary_coupon_offset secondary_coupon_offset final_opc_amt; run;

* wide dataset| see only primary coupon users;
proc contents data=coupon.cohort_wide_v00; run;
data primary_users_wide; set coupon.cohort_wide_v00; if primary_coupon_count >0; run;

proc means data=primary_users_wide n median q1 q3 mean std min max; var primary_coupon_count; run;
proc means data=primary_users_wide n median q1 q3 mean std min max; var primary_coupon_offset; run;
proc means data=primary_users_wide n median q1 q3 mean std min max; var coupon_count; run;





