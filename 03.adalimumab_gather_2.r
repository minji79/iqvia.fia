#install.packages(c("data.table", "fst", "arrow", "dplyr", "haven"))

library(haven)
library(data.table)
library(arrow)
library(dplyr)
library(fst)

# Set working directory
setwd("/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r") 

# Define folders
data_dir <- file.path(getwd(), "data")
out_dir  <- file.path(getwd(), "out")
figs_dir <- file.path(getwd(), "figures")
tabs_dir <- file.path(getwd(), "tables")

# Input file paths
prod_ref     <- "/dcs07/hpm/data/iqvia_fia/ref/product.dta"
plan_ref     <- "/dcs07/hpm/data/iqvia_fia/ref/plan.dta"
patient_ref  <- "/dcs07/hpm/data/iqvia_fia/ref/patient.dta"
provider_ref <- "/dcs07/hpm/data/iqvia_fia/ref/provider.dta"


# ------------------------------------------------------
# 1. Load Product File. Manipulate to Drug Of Interest. Save list of NDCs
# ------------------------------------------------------

prod <- read_parquet(prod_ref) %>% as.data.table()

# Filter for ADALIMUMAB
prod_adali <- prod[grepl("ADALIMUMAB", molecule_name, fixed = TRUE)]

# Save NDCs code list with subset columns
ndc_list <- prod_adali[, .(product_ndc, usc_3_description, molecule_name, drug_labeler_corp_name)]
fwrite(ndc_list, file.path(data_dir, "ADALIMUMAB_NDCs.dta"))

# ------------------------------------------------------
# 2. LOAD & COMBINE RAW CLAIMS FOR MULTIPLE YEARS: Many Ways to Do this. 
# ------------------------------------------------------

# following Attempt B — Use pre-reduced version
# Here I start with a reduced dataset I have already made, it contains all claims, including the encnt_outcm_cd variable, but way fewer variables (for efficnecy)
claims_small <- read_fst("/dcs07/hpm/data/iqvia_fia/reduced/RxFact_2018_2024_small.fst") %>% as.data.table()

ndcs <- fread(file.path(data_dir, "ADALIMUMAB_NDCs.dta"))$product_ndc

claims_adali <- claims_small[product_ndc %in% ndcs]
write_parquet(claims_adali, file.path(data_dir, "ADALIMUMAB_claims.parquet"))

cat("End time:", format(Sys.time(), "%H:%M:%S"), "\n")

# ------------------------------------------------------
# 3. Add Rejection Group (rjct_grp) Classification
# ------------------------------------------------------
claims_adali <- read_parquet(file.path(data_dir, "ADALIMUMAB_claims.parquet")) %>% as.data.table()

claims_adali[, rjct_grp := NA_integer_]






























