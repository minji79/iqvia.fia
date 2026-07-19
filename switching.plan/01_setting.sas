00
00

proc print data=input.id_index (obs=5); var patient_id index_svc_dt RJ_reason_adj dominant_payer payer_name payer_id plan_name plan_id; run;
proc contents data=input.id_index; run;

proc print data=input.joe_plan_mapping (obs=5); run;
proc print data=biosim.insurance_patient_year25 (obs=5); run;

/* 1. cleaned dominant payer file */
data dominant_1724; set input.joe_plan_mapping; keep patient_id year dominant_payer plan_id plan_name; run;
data dominant_25; set biosim.insurance_patient_year25; keep patient_id year dominant_payer plan_id plan_name; run;
data input.dominant_payer_cleaned; set dominant_1724 dominant_25; run;

/* 2. make the index year */
data switching; set input.id_index; index_year = year(index_svc_dt); run;
proc print data=switching (obs=5); var patient_id index_svc_dt index_year RJ_reason_adj dominant_payer payer_name payer_id plan_name plan_id; run;

/* 3. merge with the dominant year files */
proc sql;
  create table input.switching as
  select distinct a.*, b.plan_id as dominant_plan_id
  from switching as a
  left join input.dominant_payer_cleaned as b
	on a.patient_id = b.patient_id and a.index_year=b.year;
quit; /* 926970 individuals */

/* drop 2025 users */
data input.switching; set input.switching; if year < 2025; run; /* 926970 -> 812022 */

proc sql;
  create table input.switching as
  select distinct a.*, b.plan_id as next_dominant_plan_id
  from input.switching as a
  left join input.dominant_payer_cleaned as b
	on a.patient_id = b.patient_id and a.index_year + 1 =b.year;
quit; 

proc print data=input.switching (obs=5); var patient_id index_svc_dt index_year RJ_reason_adj dominant_payer plan_id plan_name dominant_plan_id next_dominant_plan_id; run;

/* 4. indicate switching plan_id */
data input.switching; set input.switching; drop switching; run;
data input.switching; 
    set input.switching; 
    if missing(dominant_plan_id) or missing(next_dominant_plan_id) then switching = .;
    else if next_dominant_plan_id = dominant_plan_id then switching = 0; 
    else switching = 1; 
run;
proc print data=input.switching (obs=20); var patient_id index_svc_dt index_year RJ_reason_adj dominant_payer plan_id plan_name dominant_plan_id next_dominant_plan_id switching; run;

/* 5. what if remove cash users */
data input.switching_rmcash; set input.switching; if plan_name = "CASH" then delete; run; /* 812022 -> 808257 individuals */
proc print data=input.switching_rmcash (obs=20); var patient_id index_svc_dt index_year RJ_reason_adj dominant_payer plan_id plan_name dominant_plan_id next_dominant_plan_id switching; run;

proc print data=input.switching_rmcash (obs=10); where not missing(dominant_plan_id) and missing(next_dominant_plan_id); var patient_id index_svc_dt index_year RJ_reason_adj dominant_payer plan_id plan_name dominant_plan_id next_dominant_plan_id switching; run;
proc print data=input.switching_rmcash (obs=10); where missing(dominant_plan_id) and not missing(next_dominant_plan_id); var patient_id index_svc_dt index_year RJ_reason_adj dominant_payer plan_id plan_name dominant_plan_id next_dominant_plan_id switching; run;

/* 6. probability of switching */
proc freq data=input.switching; table switching*RJ_reason_adj /norow nopercent; run;
proc freq data=input.switching_rmcash; table switching*RJ_reason_adj /norow nopercent; run;

proc print data=input.switching_rmcash (obs=10); where RJ_reason_adj in ("RJ_Non-formarly","RJ_NtCv","RJ_UM (PA/Step)"); var patient_id index_svc_dt index_year RJ_reason_adj dominant_payer plan_id plan_name dominant_plan_id next_dominant_plan_id switching; run;



/* 7. line graph - yearly change in pro*/
proc sql;
    create table figure_wide as
    select year,
       sum(case when switching=1 and RJ_reason_adj in ("Approved - paid","Approved - reversed") then 1 else 0 end) as n_switching_approved,
       sum(case when switching=0 and RJ_reason_adj in ("Approved - paid","Approved - reversed") then 1 else 0 end) as n_not_switching_approved,

       sum(case when switching=1 and RJ_reason_adj in ("RJ_Non-formarly","RJ_NtCv","RJ_UM (PA/Step)") then 1 else 0 end) as n_switching_rejected,
       sum(case when switching=0 and RJ_reason_adj in ("RJ_Non-formarly","RJ_NtCv","RJ_UM (PA/Step)") then 1 else 0 end) as n_not_switching_rejected,
      
       count(patient_id) as n_total
       
    from input.switching
    group by year;
quit;

data figure_wide; set figure_wide;
	pct_switching_approved = n_switching_approved / n_total *100; 
  pct_switching_rejected = n_switching_rejected / n_total *100; 
run;

proc print data=figure_wide; run;

proc sgplot data=figure_wide;
    title "Switching Rate(%) among GLP-1 RA Attempters";
    
    /* VBARBASIC is the 'friendly' version that allows overlays */
    vbarbasic year / response=n_total 
        fillattrs=(color=grey) 
        legendlabel="The number of total attempters (N)"
        name="bar";

    /* First Line: Solid Red */
    series x=year y=pct_switching_rejected / 
        lineattrs=(color=red thickness=3 pattern=solid) 
		y2axis
        markerattrs=(symbol=trianglefilled size=10 color=red)
        legendlabel="pct_switching_rejected (%)"
        name="line1";
	
    /* Second Line: Dotted/Dashed Blue */
    series x=year y=pct_switching_approved / 
        lineattrs=(color=blue thickness=3 pattern=shortdash) /* pattern=2 or pattern=dot also work */
		y2axis
        markerattrs=(symbol=trianglefilled size=10 color=blue)
        legendlabel="pct_switching_approved (%)"
        name="line2";
		

    xaxis label="Yearly" grid valuesrotate=diagonal;
    yaxis label="Number of Patients (Counts)" grid;
    y2axis label="Switching Rate (%)" min=0 max=12 grid;
    
    keylegend "bar" "line1" "line2" / location=outside position=bottom;
run;
