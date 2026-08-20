

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
