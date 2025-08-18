install.packages(c("data.table", "fst", "arrow", "dplyr"))

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

# 2.1. Attempt A with dta files 
# This is the most complete, and it retains all varaibles in RXFACT. It takes the longest (by far)
# Note the every other year is fine, because each file contains the year before data too

# Time tracking
cat("Start time:", format(Sys.time(), "%H:%M:%S"), "\n")

# Get all 4 big files (100GB each)
full_files <- c(
  "/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2018.fst",
  "/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2020.fst",
  "/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2022.fst",
  "/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2024.fst"
)
claims_all <- rbindlist(lapply(full_files, read_fst), use.names = TRUE, fill = TRUE) # Read and combine all 4 years

# Rename daw_cd
setnames(claims_all, old = "daw_cd", new = "daw_cd_s", skip_absent = TRUE)

# Merge with a variable that was missing in our first cut of this data: encnt_outcm_cd 
outcm <- read_parquet("/dcs07/hpm/data/iqvia_fia/full_raw/LevyPDRJRV.parquet") %>% as.data.table()

# Keep only claim_id + encnt_outcm_cd
outcm <- outcm[, .(claim_id, encnt_outcm_cd)]

# Merge 1:1 by claim_id
setkey(claims_all, claim_id)
setkey(outcm, claim_id)
claims_all <- merge(claims_all, outcm, by = "claim_id", all.x = TRUE)


ndc_path <- "/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r/data/ADALIMUMAB_NDCs.csv"
ndcs <- fread(ndc_path)
setnames(ndcs, old = "product_ndc", new = "ndc", skip_absent = TRUE) # Ensure correct column name
setnames(claims_all, old = "ndc", new = "product_ndc", skip_absent = TRUE) # Standardize column in claims

# Merge m:1 by product_ndc
setkey(claims_all, product_ndc)
setkey(ndcs, ndc)
claims_adali <- merge(claims_all, ndcs, by.x = "product_ndc", by.y = "ndc", all.x = FALSE, all.y = FALSE)

# Save as Parquet
out_path <- "/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r/data/A_ADALIMUMAB_claims.parquet"
write_parquet(claims_adali, out_path)

cat("End time:", format(Sys.time(), "%H:%M:%S"), "\n")


# 2.2. Attempt B — Use pre-reduced version
claims_small <- read_parquet("/dcs07/hpm/data/iqvia_fia/reduced/RxFact_2018_2024_small.fst") %>% as.data.table()

ndcs <- fread(file.path(data_dir, "ADALIMUMAB_NDCs.dta"))$product_ndc

claims_adali <- claims_small[product_ndc %in% ndcs]
write_parquet(claims_adali, file.path(data_dir, "ADALIMUMAB_claims.parquet"))


# ------------------------------------------------------
# 3. Add Rejection Group (rjct_grp) Classification
# ------------------------------------------------------
claims_adali <- read_parquet(file.path(data_dir, "ADALIMUMAB_claims.parquet")) %>% as.data.table()

claims_adali[, rjct_grp := NA_integer_]






























