
/* run sas */
rm ~/.config/chromium/Singleton*
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* set library */
libname switch "/dcs07/hpm/data/iqvia_fia/glp1_disc/plan_switching";   /* my own directory */
libname input "/dcs07/hpm/data/iqvia_fia/glp1_disc";   /* my own directory */
libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */
libname glp1 "/dcs04/hpm/data/iqvia_fia/glp1_paper/data";
libname biosim "/dcs07/hpm/data/iqvia_fia/biosim";   /* for reference files */
libname fast "/fastscratch/myscratch/mkim";   /* my fastbarch with 1 TB memory */

/* convert the file into dta - in R */
srun --pty --x11 --partition sas bash
module load R
module load rstudio
rstudio

/dcs07/hpm/data/iqvia_fia/codex_levy/fia_knowledge_base/outputs/rejection_plan_switching/oracle/jama_published_cohort_2000347.parquet
/dcs07/hpm/data/iqvia_fia/codex_levy/fia_knowledge_base/outputs/rejection_plan_switching/exact_jama/jama_attempts_with_next_year_switching.parquet

install.packages(c("arrow", "haven"))
library(arrow)
library(haven)

df1 <- read_parquet("/dcs07/hpm/data/iqvia_fia/codex_levy/fia_knowledge_base/outputs/rejection_plan_switching/oracle/jama_published_cohort_2000347.parquet")
write_dta(df1, "/dcs07/hpm/data/iqvia_fia/glp1_disc/plan_switching/jama_published_cohort_2000347.dta")

df2 <- read_parquet("/dcs07/hpm/data/iqvia_fia/codex_levy/fia_knowledge_base/outputs/rejection_plan_switching/exact_jama/jama_attempts_with_next_year_switching.parquet")
write_sas(df2, "/dcs07/hpm/data/iqvia_fia/glp1_disc/plan_switching/jama_next_year_switching.sas7bdat")

library(arrow)
library(dplyr)

# 1. Define paths
input_parquet <- "/dcs07/hpm/data/iqvia_fia/codex_levy/fia_knowledge_base/outputs/rejection_plan_switching/oracle/jama_published_cohort_2000347.parquet"
output_csv   <- "/dcs07/hpm/data/iqvia_fia/glp1_disc/plan_switching/jama_published_cohort_2000347.csv"

# 2. Read the Parquet file
df <- read_parquet(input_parquet)

# 3. Explicitly convert patient_id (and any integer64 column) to character
# Using sprintf avoids scientific notation like "1.082e+12"
df <- df %>%
  mutate(patient_id = as.character(patient_id))

# 4. Write to CSV
write.csv(df, output_csv, row.names = FALSE)

cat("Successfully converted Parquet to CSV with patient_id as character string!\n")

# check
library(dplyr)
head(df1)

/* convert into sas file in SAS */
proc import datafile="/dcs07/hpm/data/iqvia_fia/glp1_disc/plan_switching/jama_published_cohort_2000347.dta" out=jama_published_cohort dbms=dta replace; run;
proc import datafile="/dcs07/hpm/data/iqvia_fia/glp1_disc/plan_switching/jama_next_year_switching.dta" out=jama_switching dbms=dta replace; run;

proc import datafile="/dcs07/hpm/data/iqvia_fia/glp1_disc/plan_switching/jama_published_cohort_2000347.csv"
    out=jama_published_cohort_2000347
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=10000; /* Scans 10,000 rows to determine proper column lengths */
run;

data switch.jama_published_cohort_2000347; set jama_published_cohort_2000347; patient_id = input(patient_id, best12.); run;

data switch.jama_published_cohort_2000347;
    set jama_published_cohort_2000347 (rename=(patient_id = patient_id_char));
    
    /* 'best16.' handles up to 16 digits safely, avoiding precision loss */
    /* '??' suppresses invalid data warnings in the log if any non-numeric strings exist */
    patient_id = input(patient_id_char, ?? best16.);
    
    /* 3. Drop the temporary character variable */
    drop patient_id_char;
run;
proc contents data=switch.jama_published_cohort_2000347; run;


proc sort data=switch.jama_published_cohort_2000347; by patient_id i_molecule_id year; run;
proc print data=switch.jama_published_cohort_2000347 (obs=20); run;
proc contents data=switch.jama_published_cohort_2000347; run;

proc print data=input.joe_plan_mapping (obs=10); run;
proc means data=switch.jama_published_cohort_2000347 n nmiss min max; var patient_id; run; /* 2018-2024 */

/* Merge with the dominant payer file */
proc freq data=switch.jama_published_cohort_2000347; table year; run; /* 2018-2024 */
proc means data=input.dominant_payer_cleaned n nmiss min max; var plan_id; run; /* 2018-2024 */

data switch.jama_published_cohort_2000347;
    /* 1. Rename the incoming character variable */
    set switch.jama_published_cohort_2000347(rename=(share_paid_claims_this_plan = share_paid_char));
    
    /* 2. Convert to numeric using best18. (use ?? to suppress warnings if non-numeric values exist) */
    share_paid_claims_this_plan = input(share_paid_char, ?? best18.);
    
    /* 3. Drop the temporary character column */
    drop share_paid_char;
run;
proc means data=switch.jama_published_cohort_2000347 n nmiss min max; var share_paid_claims_this_plan; run; /* 2018-2024 */

proc sql;
  create table switch.jama_published_cohort_cleaned as
  select distinct a.*, b.plan_id as dominant_plan_id
  from switch.jama_published_cohort_2000347 as a
  left join input.dominant_payer_cleaned as b
	on a.patient_id = b.patient_id and a.year=b.year;
quit; 
proc print data=switch.jama_published_cohort_cleaned(obs=10); var patient_id plan_id dominant_plan_id; run;

/* merge with the following year information */
proc sql;
  create table switch.jama_published_cohort_cleaned as
  select distinct a.*, b.plan_id as next_dominant_plan_id, b.plan_name as next_dominant_plan_name, b.dominant_payer as next_dominant_payer
  from switch.jama_published_cohort_cleaned as a
  left join input.dominant_payer_cleaned as b
	on a.patient_id = b.patient_id and a.year + 1 =b.year;
quit; 

/* indicate switching */
data switch.jama_published_cohort_cleaned;
    set switch.jama_published_cohort_cleaned;
    if missing(plan_id) or missing(next_dominant_plan_id) then switching = .;
    else if next_dominant_plan_id = plan_id then switching = 0; 
    else switching = 1; 
run;
proc print data=switch.jama_published_cohort_cleaned (obs=10); run;
proc print data=switch.jama_published_cohort_cleaned (obs=10); var patient_id i_molecule_id plan_id dominant_plan_id next_dominant_plan_id switching; where patient_id ne 0; run;

/* probability of switching */
proc freq data=switch.jama_published_cohort_cleaned; table switching*index_day_outcome /norow nopercent; run;

proc sql;
    create table figure_wide as
    select year,
       sum(case when switching=1 and index_day_outcome = "Paid" then 1 else 0 end) as n_switching_approved,
       sum(case when switching=0 and index_day_outcome = "Paid" then 1 else 0 end) as n_not_switching_approved,

       sum(case when switching=1 and index_day_outcome = "Reject" then 1 else 0 end) as n_switching_rejected,
       sum(case when switching=0 and index_day_outcome = "Reject" then 1 else 0 end) as n_not_switching_rejected,
      
       count(patient_id) as n_total
       
    from switch.jama_published_cohort_cleaned
    group by year;
quit;

data figure_wide; set figure_wide;
	pct_switching_approved = n_switching_approved / (n_switching_approved + n_not_switching_approved) *100; 
  pct_switching_rejected = n_switching_rejected / (n_switching_rejected + n_not_switching_rejected) *100; 
run;

proc print data=figure_wide; run;

proc sgplot data=figure_wide;
    title "Switching Rate(%) among Attempters";
    
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
    y2axis label="Switching Rate (%)" min=0 max=20 grid;
    
    keylegend "bar" "line1" "line2" / location=outside position=bottom;
run;

/* among Medicare */
proc freq data=switch.jama_published_cohort_cleaned; table switching*dominant_payer /norow nopercent; run;

data medicareTM; set switch.jama_published_cohort_cleaned; if dominant_payer = "Medicare D: TM" and switching =1; run;
proc freq data=medicareTM; table next_dominant_payer; run;

data medicareMA; set switch.jama_published_cohort_cleaned; if dominant_payer = "Medicare D: ADV" and switching =1; run;
proc freq data=medicareMA; table next_dominant_payer; run;

data exchange; set switch.jama_published_cohort_cleaned; if dominant_payer = "Exchange" and switching =1; run;
proc freq data=exchange; table next_dominant_payer; run;

data commercial; set switch.jama_published_cohort_cleaned; if dominant_payer = "Commercial" and switching =1; run;
proc freq data=commercial; table next_dominant_payer; run;






