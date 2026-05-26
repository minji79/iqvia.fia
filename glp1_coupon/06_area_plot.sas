
/*============================================================*
 | 1) area plot with primary coupons vs. secondary coupons
 *============================================================*/
proc print data=coupon.monthly_aggregated_oop_long (obs=20); run;
proc print data=coupon.monthly_patient_counts (obs=20); run;

/* among coupon users */
data coupon_users; set coupon.monthly_aggregated_oop_long; if coupon_user =1; run;

proc sql;
  create table monthly_patient_counts as
  select
      month,
      count(distinct patient_id) as n_patients,
      count(distinct case when coupon_1_count>0 then patient_id end) as n_1_coupon_users,
      count(distinct case when coupon_2_count>0 then patient_id end) as n_2_coupon_users
  from coupon_users
  group by month
  order by month;
quit;
proc print data=monthly_patient_counts (obs=20); run;

data monthly_patient_counts; set monthly_patient_counts; 
  pct_1_coupon = n_1_coupon_users / n_patients * 100;
  pct_2_coupon = n_2_coupon_users / n_patients * 100;
run;
data monthly_patient_counts; set monthly_patient_counts; 
  pct_non_users = 100 - pct_1_coupon - pct_2_coupon;
run;
proc print data=monthly_patient_counts (obs=20); run;



data monthly_patient_counts; set monthly_patient_counts; 
    level1 = pct_1_coupon;
    level2 = pct_1_coupon + pct_2_coupon;
    level3 = 100;
run;


proc sgplot data=monthly_patient_counts noautolegend;
    title "Component of Coupon Use During Treatment Episode";

    /* Create the stacks using BAND statements */
    /* Stack 1: Bottom (1 Coupon Users) */
    band x=month lower=0 upper=level1 / fillattrs=(color=CX2c7bb6) 
         legendlabel="Free Trials Coupon Users" name="Free Trials";
         
    /* Stack 2: Middle (2+ Coupon Users) */
    band x=month lower=level1 upper=level2 / fillattrs=(color=CXabd9e9) 
         legendlabel="Copay Coupons Users" name="Copay Coupons";
         
    /* Stack 3: Top (Non-Users) */
    band x=month lower=level2 upper=level3 / fillattrs=(color=lightgrey) 
         legendlabel="None" name="None";

    xaxis label="Month since initiation" grid values=(1 to 18 by 1);
    yaxis label="Percentage of Total Coupon Users (%)" grid min=0 max=100;
    
    keylegend "Free Trials" "Copay Coupons" "None" / title="" location=outside position=bottom;
run;  


/*============================================================*
 | 2) coupon availability over calender time - quarterly
 *============================================================*/
proc print data=coupon.cohort_patient_year_v01 (obs=10); var patient_id year claim_count coupon_count coupon_user; run;
proc print data=coupon.cohort_patient_year_v01 (obs=10); run;

/* Create quarter indicator */
data quarterly_patient_base;
    set coupon.cohort_long_v00;

    if not missing(svc_dt) then 
        qtr_indicator = intnx('quarter', svc_dt, 0, 'beginning');

    format qtr_indicator yyq6.;
run;

/* Count total patients and coupon users by quarter */
proc sql;
    create table quarterly_patient_counts as
    select
        qtr_indicator,
        count(distinct patient_id) as n_patients,
        count(distinct case 
            when coupon = 1 then patient_id 
        end) as n_coupon_users
    from quarterly_patient_base
    where not missing(qtr_indicator)
    group by qtr_indicator
    order by qtr_indicator;
quit;

/* Calculate percentages */
data quarterly_patient_counts;
    set quarterly_patient_counts;

    if n_patients > 0 then do;
        pct_coupon = n_coupon_users / n_patients * 100;
        pct_non_users = 100 - pct_coupon;
    end;

    format pct_coupon pct_non_users 6.1;
run;

proc print data=quarterly_patient_counts; run;



/*============================================================*
 | 2) coupon availability over calender time - yearly
 *============================================================*/

proc sort data=coupon.cohort_long_v01;
  by patient_id year svc_dt;
run;

data yearly_patient_counts;
  set coupon.cohort_long_v01;    
  by patient_id year;

  if first.year then do;
    claim_count = 0;
    primary_coupon_count = 0;
    secondary_coupon_count = 0;
    primary_coupon_count_dm = 0;
    secondary_coupon_count_dm = 0;
    primary_coupon_count_ob = 0;
    secondary_coupon_count_ob = 0;
  end;
  
  claim_count + 1;
  
  if primary_coupon = 1 then primary_coupon_count + 1;
  if secondary_coupon = 1 then secondary_coupon_count + 1;
  
  if primary_coupon = 1 and molecule_name in ("DULAGLUTIDE", "EXENATIDE", "LIRAGLUTIDE", "LIXISENATIDE", "SEMAGLUTIDE", "TIRZEPATIDE") then primary_coupon_count_dm + 1;
  if secondary_coupon = 1 and molecule_name in ("DULAGLUTIDE", "EXENATIDE", "LIRAGLUTIDE", "LIXISENATIDE", "SEMAGLUTIDE", "TIRZEPATIDE") then secondary_coupon_count_dm + 1;

  if primary_coupon = 1 and molecule_name in ("LIRAGLUTIDE (WEIGHT MANAGEMENT)", "SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE (WEIGHT MANAGEMENT)") then primary_coupon_count_ob + 1;
  if secondary_coupon = 1 and molecule_name in ("LIRAGLUTIDE (WEIGHT MANAGEMENT)", "SEMAGLUTIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE (WEIGHT MANAGEMENT)") then secondary_coupon_count_ob + 1;
  
  if last.year then do;
    output;
  end;
run;
proc print data=yearly_patient_counts (obs=20); var patient_id year claim_count primary_coupon_count secondary_coupon_count primary_coupon_count_dm secondary_coupon_count_dm primary_coupon_count_ob secondary_coupon_count_ob; run;

data yearly_patient_counts; set yearly_patient_counts; 
 coupon_count = primary_coupon_count + secondary_coupon_count; 
 coupon_count_dm = primary_coupon_count_dm + secondary_coupon_count_dm; 
 coupon_count_ob = primary_coupon_count_ob + secondary_coupon_count_ob; 
run;


proc sql;
  create table yearly_patient_summary as
  select
      year,
      count(distinct patient_id) as n_patients,
      count(distinct case when coupon_count ne 0 then patient_id end) as n_coupon_users,
      count(distinct case when coupon_count_dm ne 0 then patient_id end) as n_coupon_dm_users,
      count(distinct case when coupon_count_ob ne 0 then patient_id end) as n_coupon_ob_users,
      count(distinct case when primary_coupon_count ne 0 then patient_id end) as n_primary_coupon_users,
      count(distinct case when secondary_coupon_count ne 0 then patient_id end) as n_secondary_coupon_users
  from yearly_patient_counts
  group by year
  order by year;
quit;

data yearly_patient_summary; set yearly_patient_summary;
  pct_coupon = n_coupon_users / n_patients * 100;  
  pct_primary_coupon = n_primary_coupon_users / n_patients * 100;  
  pct_secondary_coupon = n_secondary_coupon_users / n_patients * 100; 
  pct_coupon_dm = n_coupon_dm_users / n_patients * 100; 
  pct_coupon_ob = n_coupon_ob_users / n_patients * 100; 
run;

data yearly_patient_summary; set yearly_patient_summary;
  pct_non_users = 100 - pct_coupon;  
run;
proc print data=yearly_patient_summary (obs=20); run;



/* overall */
data coupon_plot_data;
    set yearly_patient_summary;
    pct_coupon = pct_coupon;
    p = pct_coupon / 100;
    n = n_patients;
    
    /* Calculate Standard Error */
    stderr = sqrt((p * (1 - p)) / n);
    
    /* Calculate 95% CI Lower and Upper bounds */
    lower_ci = max(0, (p - 1.96 * stderr) * 100);
    upper_ci = min(100, (p + 1.96 * stderr) * 100);
run;
proc print data=coupon_plot_data (obs=20); run;

proc sgplot data=coupon_plot_data;
    title "Percentage of Coupon Users with 95% Confidence Intervals (2018-2024)";
    
    /* Add shaded confidence interval band */
    band x=year lower=lower_ci upper=upper_ci / 
         fillattrs=(color=lightblue transparency=0.4) 
         legendlabel="95% CI" name="band";
         
    /* Add the main line graph */
    series x=year y=pct_coupon / 
           lineattrs=(color=blue thickness=2) 
           markers markerattrs=(symbol=circlefilled) 
           legendlabel="Coupon Users among GLP-1 users (%)" name="line";
           
    /* Formatting axes */
    xaxis label="Year" values=(2018 to 2024 by 1);
    yaxis label="Coupon Users (%)" min=0 max=15;
    
    keylegend "line" "band" / location=outside position=bottom;
run;



/* by primary & secondary */
data coupon_plot_data;
    set yearly_patient_summary;
    pct_primary_coupon = pct_primary_coupon;
    p1 = pct_primary_coupon / 100;
    pct_secondary_coupon = pct_secondary_coupon;
    p2 = pct_secondary_coupon / 100;
    n = n_patients;
    
    /* Calculate Standard Error */
    stderr_1 = sqrt((p1 * (1 - p1)) / n);
    stderr_2 = sqrt((p2 * (1 - p2)) / n);
    
    /* Calculate 95% CI Lower and Upper bounds */
    lower_ci_1 = max(0, (p1 - 1.96 * stderr_1) * 100);
    upper_ci_1 = min(100, (p1 + 1.96 * stderr_1) * 100);
    lower_ci_2 = max(0, (p2 - 1.96 * stderr_2) * 100);
    upper_ci_2 = min(100, (p2 + 1.96 * stderr_2) * 100);
run;
proc print data=coupon_plot_data (obs=20); run;

data coupon_plot_long;
    length coupon_type $30;
    set coupon_plot_data;

    coupon_type = "Free Trial Coupon";
    pct = pct_primary_coupon;
    output;

    coupon_type = "Copay Coupon";
    pct = pct_secondary_coupon;
    output;
run;

proc sgplot data=coupon_plot_long;
    title "Coupon Users Among GLP-1 Users";
    styleattrs datacontrastcolors=(blue red);

    series x=year y=pct /
        group=coupon_type
        markers
        lineattrs=(thickness=2)
        markerattrs=(size=8);

    xaxis
        label="Year"
        values=(2018 to 2024 by 1);

    yaxis
        label="Coupon Users (%)"
        min=0
        max=15;

    keylegend / title=""  location=outside position=bottom;
run;


/* by indications */
data coupon_plot_data;
    set yearly_patient_summary;
    pct_coupon_dm = pct_coupon_dm;
    p1 = pct_coupon_dm / 100;
    pct_coupon_ob = pct_coupon_ob;
    p2 = pct_coupon_ob / 100;
    n = n_patients;
    
    /* Calculate Standard Error */
    stderr_1 = sqrt((p1 * (1 - p1)) / n);
    stderr_2 = sqrt((p2 * (1 - p2)) / n);
    
    /* Calculate 95% CI Lower and Upper bounds */
    lower_ci_1 = max(0, (p1 - 1.96 * stderr_1) * 100);
    upper_ci_1 = min(100, (p1 + 1.96 * stderr_1) * 100);
    lower_ci_2 = max(0, (p2 - 1.96 * stderr_2) * 100);
    upper_ci_2 = min(100, (p2 + 1.96 * stderr_2) * 100);
run;
proc print data=coupon_plot_data (obs=20); run;

data coupon_plot_long;
    length coupon_type $30;
    set coupon_plot_data;

    coupon_type = "Coupon use for diabete-labeled GLP-1s";
    pct = pct_coupon_dm;
    output;

    coupon_type = "Coupon use for obesity-labeled GLP-1s";
    pct = pct_coupon_ob;
    output;
run;

proc sgplot data=coupon_plot_long;
    title "Coupon Users Among GLP-1 Users";
     styleattrs datacontrastcolors=(orange green);

    series x=year y=pct /
        group=coupon_type
        markers
        lineattrs=(thickness=2)
        markerattrs=(size=8);

    xaxis
        label="Year"
        values=(2018 to 2024 by 1);

    yaxis
        label="Coupon Users (%)"
        min=0
        max=15;

    keylegend / title=""  location=outside position=bottom;
run;



