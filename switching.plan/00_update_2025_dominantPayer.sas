

/* ====================================================================
  1. convert parquet files to csv using R
 ==================================================================== */
srun --pty --x11 --partition sas bash
module load R
module load rstudio
rstudio


"/dcs07/hpm/data/iqvia_fia/rejection_rate_final/temp/insurance_patient_year.parquet"
"/dcs07/hpm/data/iqvia_fia/rejection_rate_final/temp/insurance_patient_year25.parquet"

/* in R */
library(arrow)
library(dplyr)

input_parquet_1 <- "/dcs07/hpm/data/iqvia_fia/rejection_rate_final/temp/insurance_patient_year.parquet"
input_parquet_2 <- "/dcs07/hpm/data/iqvia_fia/rejection_rate_final/temp/insurance_patient_year25.parquet"

output_csv_1   <- "/dcs07/hpm/data/iqvia_fia/biosim/insurance_patient_year_1724_updated.csv"
output_csv_2   <- "/dcs07/hpm/data/iqvia_fia/biosim/insurance_patient_year_25_updated.csv"

df1 <- read_parquet(input_parquet_1)
df2 <- read_parquet(input_parquet_2)

df1 <- df1 %>% mutate(patient_id = as.character(patient_id))
df2 <- df2 %>% mutate(patient_id = as.character(patient_id))

write.csv(df1, output_csv_1, row.names = FALSE)
write.csv(df2, output_csv_2, row.names = FALSE)


/* ====================================================================
  2. convert csv file to sas using SAS
 ==================================================================== */

proc import datafile="/dcs07/hpm/data/iqvia_fia/biosim/insurance_patient_year_1724_updated.csv"
    out=biosim.dominant_pyr_1724
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=10000;
run;
proc sql;
    select 
        count(*) as total_rows,
        sum(case when missing(dominant_payer) then 1 else 0 end) as n_missing,
        calculated n_missing / count(*) as pct_missing format=percent8.2
    from biosim.dominant_pyr_1724;
quit; /* none missing in plan_id */

proc freq data=biosim.dominant_pyr_1724; tables dominant_payer / missing; run;

proc contents data=biosim.dominant_pyr_1724; run;
proc print data=biosim.dominant_pyr_1724 (obs=10); run;

data biosim.dominant_pyr_1724 (drop= _:);
    set biosim.dominant_pyr_1724 (rename=(
        patient_id  = _patient_id
        plan_id     = _plan_id
        n_claimsPD  = _n_claimsPD
        n_claimsRV  = _n_claimsRV
        n_claimsRJ  = _n_claimsRJ
    ));
    
    if not missing(_patient_id) and _patient_id ne 'NA' then 
        patient_id = input(compress(_patient_id), BEST32.);
    else patient_id = .;

    if not missing(_plan_id) and _plan_id ne 'NA' then 
        plan_id = input(compress(_plan_id), BEST32.);
    else plan_id = .;

    if not missing(_n_claimsPD) and _n_claimsPD ne 'NA' then 
        n_claimsPD = input(compress(_n_claimsPD, , 'kd'), BEST32.);
    else n_claimsPD = .;

    if not missing(_n_claimsRV) and _n_claimsRV ne 'NA' then 
        n_claimsRV = input(compress(_n_claimsRV, , 'kd'), BEST32.);
    else n_claimsRV = .;

    if not missing(_n_claimsRJ) and _n_claimsRJ ne 'NA' then 
        n_claimsRJ = input(compress(_n_claimsRJ, , 'kd'), BEST32.);
    else n_claimsRJ = .;
run;
proc means data=biosim.dominant_pyr_1724 n nmiss;
    var plan_id;
run;


proc import datafile="/dcs07/hpm/data/iqvia_fia/biosim/insurance_patient_year_25_updated.csv"
    out=biosim.dominant_pyr_25
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=10000;
run;
proc freq data=biosim.dominant_pyr_25; tables plan_id / missing; run;
proc freq data=biosim.dominant_pyr_25; tables dominant_payer / missing; run;

proc print data=biosim.dominant_pyr_25 (obs=10); where plan_id ="NA"; run;
proc contents data=biosim.dominant_pyr_25; run;

proc sql;
    select 
        count(*) as total_rows,
        sum(case when missing(dominant_payer) then 1 else 0 end) as n_missing,
        calculated n_missing / count(*) as pct_missing format=percent8.2
    from biosim.dominant_pyr_25;
quit;

data biosim.dominant_pyr_25 (drop= _:);
    set biosim.dominant_pyr_25 (rename=(
        patient_id  = _patient_id
        plan_id     = _plan_id
        n_claimsPD  = _n_claimsPD
        n_claimsRV  = _n_claimsRV
        n_claimsRJ  = _n_claimsRJ
    ));
    
    if not missing(_patient_id) and _patient_id ne 'NA' then 
        patient_id = input(compress(_patient_id), BEST32.);
    else patient_id = .;

    if not missing(_plan_id) and _plan_id ne 'NA' then 
        plan_id = input(compress(_plan_id), BEST32.);
    else plan_id = .;

    if not missing(_n_claimsPD) and _n_claimsPD ne 'NA' then 
        n_claimsPD = input(compress(_n_claimsPD, , 'kd'), BEST32.);
    else n_claimsPD = .;

    if not missing(_n_claimsRV) and _n_claimsRV ne 'NA' then 
        n_claimsRV = input(compress(_n_claimsRV, , 'kd'), BEST32.);
    else n_claimsRV = .;

    if not missing(_n_claimsRJ) and _n_claimsRJ ne 'NA' then 
        n_claimsRJ = input(compress(_n_claimsRJ, , 'kd'), BEST32.);
    else n_claimsRJ = .;
run;
proc means data=biosim.dominant_pyr_25 n nmiss;
    var plan_id;
run;


/* merge two datasets */
data biosim.dominant_pyr_1725; set biosim.dominant_pyr_1724 biosim.dominant_pyr_25; run;
proc means data=biosim.dominant_pyr_1725 n nmiss;
    var plan_id;
run; /* 14825667 out of 40624914 */
proc print data=biosim.dominant_pyr_1725 (obs=30); run;

/* check the null */
proc print data=biosim.dominant_pyr_1724 (obs=10); where patient_id = 108810; run;
proc print data=biosim.dominant_pyr_1724 (obs=10); where patient_id = 109934; run;






