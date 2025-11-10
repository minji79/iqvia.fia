coupon.cohort_long_v01
coupon.monthly_aggregated_oop_long

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
    sum(primary_coupon_offset) as accumulated_coupon_1_offset,
    sum(secondary_coupon_offset) as accumulated_coupon_2_offset
    
  from coupon.cohort_long_v01 b
  where svc_dt >= index_date and svc_dt <= index_date +30
  group by b.patient_id;
quit;
proc print data=oop_after_m2 (obs=10); run;


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
    sum(primary_coupon_offset) as accumulated_coupon_1_offset,
    sum(secondary_coupon_offset) as accumulated_coupon_2_offset
    
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



/*============================================================*
 | 3) eFigure 4. Histogram monthly coupon & claim count
 *============================================================*/
proc sgplot data=coupon.monthly_aggregated_oop_long;
    /* Grouped bars: claim_count vs coupon_count */
    vbar month / response=claim_count datalabel categoryorder=respdesc 
        groupdisplay=cluster barwidth=0.5 fillattrs=(color=cx1F77B4) 
        transparency=0.1 legendlabel="Claim Count";

    vbar month / response=coupon_count datalabel 
        groupdisplay=cluster barwidth=0.4 fillattrs=(color=cxFF7F0E) 
        transparency=0.1 legendlabel="Coupon Count";

    xaxis label="Month since initiation" integer;
    yaxis label="Count";
    keylegend / position=topright across=1 title="Counts";
    title "Monthly Claim vs Coupon Count";
run;


/*============================================================*
 | 4) Figure 1. Line graph for OOP trajectory
 *============================================================*/
* aggregated by month; 
proc sort data=coupon.monthly_aggregated_oop_long out=monthly; by month; run;
data monthly ; set monthly; by month; coupon_offset_pct_adj = mean(coupon_offset_pct); run;
proc print data=monthly; run;


* with dollars; 
proc sgplot data=coupon.monthly_aggregated_oop_long;
    series x=month y=accumulated_drug_cost_30day /
        lineattrs=(color=cx1F77B4 thickness=2)
        markerattrs=(symbol=circlefilled color=cx1F77B4 size=6)
        legendlabel="Accumulated Drug Cost (30-day)";

    series x=month y=accumulated_oop_30day /
        lineattrs=(color=cxFF7F0E thickness=2 pattern=solid)
        markerattrs=(symbol=squarefilled color=cxFF7F0E size=6)
        legendlabel="Accumulated OOP (30-day)";

    series x=month y=accumulated_coupon_offset /
        lineattrs=(color=cx2CA02C thickness=2 pattern=dash)
        markerattrs=(symbol=trianglefilled color=cx2CA02C size=6)
        legendlabel="Accumulated Coupon Offset";

    xaxis label="Month since initiation" integer;
    yaxis label="Dollars ($)" grid;
    keylegend / position=topright across=1 title="Cost Components";
    title "Monthly Trends in Drug Cost, Out-of-Pocket, and Coupon Offset";
run;

* with percentage (%); 
proc sgplot data=coupon.monthly_aggregated_oop_long;
    series x=month y=coupon_offset_pct /
        lineattrs=(color=cx2CA02C thickness=2)
        markerattrs=(symbol=circlefilled color=cx2CA02C size=7)
        datalabel
        legendlabel="Coupon Offset (%)";

    xaxis label="Month since initiation" integer;
    yaxis label="Coupon Offset (%)" grid;
    title "Monthly Coupon Offset Percentage";
run;


