

/************************************************************************************
	quarterly indicator
************************************************************************************/

/************************************************************************************
	5. Area plot for stacked by category with month_id
************************************************************************************/

/* 1) Aggregate counts by month & category */
proc sql;
    create table counts as
    select month_id,
           category,
           count(*) as count
    from input.adalimumab_claim_v0
    group by month_id, category
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
    by month_dt category; 
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
  band x=month_dt lower=lower upper=upper / group=category transparency=0.1;
  xaxis type=time interval=month valuesformat=monyy7.;
  yaxis label="Count";
run;
