
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
 | 2) coupon availability over calender time
 *============================================================*/
proc print data=coupon.cohort_patient_year_v01 (obs=10); var patient_id year claim_count coupon_count coupon_user; run;

proc sql;
  create table yearly_patient_counts as
  select
      year,
      count(distinct patient_id) as n_patients,
      count(distinct case when coupon_user=1 then patient_id end) as n_coupon_users
  from coupon.cohort_patient_year_v01
  group by year
  order by year;
quit;
proc print data=yearly_patient_counts (obs=20); run;

data yearly_patient_counts; set yearly_patient_counts; 
  pct_coupon = n_coupon_users / n_patients * 100;  
run;

data yearly_patient_counts; set yearly_patient_counts; 
  pct_non_users = 100 - pct_coupon;  
run;

data coupon_plot_data;
    set yearly_patient_counts;
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
           legendlabel="Coupon Users (%)" name="line";
           
    /* Formatting axes */
    xaxis label="Year" grid values=(2018 to 2024 by 1);
    yaxis label="Coupon Users (%)" grid min=0 max=15;
    
    keylegend "line" "band" / location=outside position=bottom;
run;

/* Optional: Reset graphics to default settings afterward */
ods graphics / reset;
