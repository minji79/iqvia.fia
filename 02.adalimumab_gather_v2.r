#!/usr/bin/env Rscript

# ============================================================
# ETL for MOLECULE_OF_INTEREST (here, we use ADALIMUMAB) claims in IQVIA FIA dataset
# Purpose: Load, clean, and classify claims and plan info
# Inputs: product.dta, plan.dta, RxFact2018-2024.dta, LevyPDRJRV.dta
# Outputs: "MOLECULE_OF_INTEREST_NDCs.parquet", 
#          "A_MOLECULE_OF_INTEREST_claims.parquet",
#          "B_MOLECULE_OF_INTEREST_claims.parquet",
#          "C_MOLECULE_OF_INTEREST_claims.parquet",
#          "B_analytic_file.parquet"
# ============================================================

## =============================
## 0) Setup & libraries
## =============================

#BiocManager::install("data.table")
#BiocManager::install("haven")
#BiocManager::install("arrow")
#BiocManager::install("fst")

#library(data.table)
#library(haven)
#library(arrow)
#library(fst)

# 0) Make installs predictable in batch jobs
options(repos = c(CRAN = "https://cloud.r-project.org"))
# 1) Ensure a writable personal library and put it first on .libPaths()
lib <- Sys.getenv("R_LIBS_USER")
if (lib == "") {
  lib <- file.path(Sys.getenv("HOME"), "R", paste0("lib-", paste(R.version$major, R.version$minor, sep=".")))
  Sys.setenv(R_LIBS_USER = lib)
}

dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))

# 2) Detect what’s installed in ANY active lib path (not just the default)
pkgs <- c("data.table", "haven", "arrow", "fst")
have <- rownames(installed.packages(lib.loc = .libPaths()))
to_install <- setdiff(pkgs, have)

# 3) Install missing ones with parallel compile, fail loudly on error
if (length(to_install)) {
  ncpu <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "1"))
  for (p in to_install) {
    message("\n--- Installing ", p, " ---")
    tryCatch(
      install.packages(p, lib = lib, dependencies = TRUE, Ncpus = ncpu),
      error = function(e) {
        message("FAILED to install ", p, ": ", conditionMessage(e))
        quit(status = 1)
      }
    )
  }
}

# 4) Load and stop if any package still missing
ok <- vapply(pkgs, require, logical(1), character.only = TRUE, quietly = FALSE)
if (!all(ok)) {
  missing <- paste(pkgs[!ok], collapse = ", ")
  stop("Could not load packages: ", missing)
}
# Optional: print session info to your SLURM log
print(sessionInfo())





# Set working directory
setwd("/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r")

# Create directory paths
data_dir <- file.path(getwd(), "data")
out_dir  <- file.path(getwd(), "out")
errs_dir <- file.path(getwd(), "errs")
figs_dir <- file.path(getwd(), "figures")
tabs_dir <- file.path(getwd(), "tables")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(out_dir,  showWarnings = FALSE, recursive = TRUE)
dir.create(errs_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(figs_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tabs_dir, showWarnings = FALSE, recursive = TRUE)

# Reference file paths
prod_ref <- "/dcs07/hpm/data/iqvia_fia/ref/product.dta"
plan_ref <- "/dcs07/hpm/data/iqvia_fia/ref/plan.dta"
encpatch_ref <- "/dcs07/hpm/data/iqvia_fia/full_raw/LevyPDRJRV.dta"

# Time logger
ts_now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")
logmsg <- function(msg) cat(sprintf("[%s] %s\n", ts_now(), msg))

## =============================
## 1. Load Product File. Manipulate to Drug Of Interest. Save list of NDCs
## =============================
prod <- as.data.table(read_dta(prod_ref))
stopifnot("molecule_name" %in% names(prod))
prod <- prod[grepl("ADALIMUMAB", molecule_name, ignore.case = TRUE)]

logmsg("Tabulate molecule_name (sorted):")
print(sort(table(prod$molecule_name), decreasing = TRUE))

keep_cols <- intersect(c("product_ndc", "usc_3_description", "molecule_name", "drug_labeler_corp_name"), names(prod))
prod <- prod[, ..keep_cols]

if (all(c("molecule_name", "drug_labeler_corp_name") %in% names(prod))) {
  logmsg("Tabulate molecule_name x drug_labeler_corp_name:")
  print(with(prod, table(molecule_name, drug_labeler_corp_name)))
}

write_parquet(prod, file.path(data_dir, "ADALIMUMAB_NDCs.parquet"), compression = "zstd")

ndcs <- unique(prod[, .(product_ndc)])
setkey(ndcs, product_ndc)

## =============================
## 2. LOAD & COMBINE RAW CLAIMS FOR MULTIPLE YEARS: Many Ways to Do this.
## =============================

## ========= Attempt A =========
# This is the most complete, but also the slowest, as it retains all variables in RXFACT. It takes the longest (by far)
# Note the every other year is fine, because each file contains the year before data too.

logmsg("Attempt A Start")

# load 4 full raw files (keep all variables)
rx2018 <- as.data.table(read_dta("/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2018.dta"))
rx2020 <- as.data.table(read_dta("/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2020.dta"))
rx2022 <- as.data.table(read_dta("/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2022.dta"))
rx2024 <- as.data.table(read_dta("/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2024.dta"))

# Rename daw_cd → daw_cd_s if exists
for (dt in list(rx2018, rx2020, rx2022, rx2024)) {
  if ("daw_cd" %in% names(dt)) setnames(dt, "daw_cd", "daw_cd_s")
}

rx_all <- rbindlist(list(rx2018, rx2020, rx2022, rx2024), use.names = TRUE, fill = TRUE)
rm(rx2018, rx2020, rx2022, rx2024); gc()

# Merge with encounter outcome
encpatch <- as.data.table(read_dta(encpatch_ref))[, .(claim_id, encnt_outcm_cd)]
stopifnot(!anyDuplicated(encpatch$claim_id))
setkey(encpatch, claim_id)
setkey(rx_all, claim_id)
rx_all <- encpatch[rx_all, nomatch = 0L]

# Merge with ADALIMUMAB NDCs
# Rename ndc to product_ndc for consistency
if ("ndc" %in% names(rx_all) && !"product_ndc" %in% names(rx_all)) {
  setnames(rx_all, "ndc", "product_ndc")
}

if ("ndc" %in% names(rx_all) && !"product_ndc" %in% names(rx_all)) {
  setnames(rx_all, "ndc", "product_ndc")
}
setkey(rx_all, product_ndc)
rx_a <- ndcs[rx_all, nomatch = 0L]
write_parquet(rx_a, file.path(data_dir, "A_ADALIMUMAB_claims.parquet"), compression = "zstd")

logmsg("Attempt A End")


## ========= Attempt B =========
# Here I start with a reduced dataset I have already made, it contains all claims,
# including the encnt_outcm_cd variable but way fewer variables (for efficiency)

logmsg("Attempt B Start")

# Load reduced dataset (includes encnt_outcm_cd, fewer vars)
rx_small <- as.data.table(read_dta("/dcs07/hpm/data/iqvia_fia/reduced/RxFact_2018_2024_small.dta"))

# Rename ndc to match prod file
if ("ndc" %in% names(rx_small) && !"product_ndc" %in% names(rx_small)) {
  setnames(rx_small, "ndc", "product_ndc")
}
setkey(rx_small, product_ndc)
rx_b <- ndcs[rx_small, nomatch = 0L]
write_parquet(rx_b, file.path(data_dir, "B_ADALIMUMAB_claims.parquet"), compression = "zstd")

logmsg("Attempt B End")


## ========= Attempt C =========
# Here I start with a random sample (0.5% of the data) of the larger dataset,
# when doing this, you could run in GUI for instance depending on how big of
# a random sample you take

logmsg("Attempt C Start")

# Sample 0.5% of rows randomly
set.seed(42)
rx_sample <- rx_small[runif(.N) < 0.005]
setkey(rx_sample, product_ndc)
rx_c <- ndcs[rx_sample, nomatch = 0L]
write_parquet(rx_c, file.path(data_dir, "C_ADALIMUMAB_claims.parquet"), compression = "zstd")

logmsg("Attempt C End")

## =============================
## 3. Manipulate Claims. Improve Reject Reason (current best understanding)
## =============================

# Using B, but could also work with C here, in GUI to work on code.
claims <- as.data.table(read_parquet(file.path(data_dir, "B_ADALIMUMAB_claims.parquet")))
claims[, rjct_grp := NA_integer_]

# Group 1: Step Edit
claims[rjct_cd %in% c("88", "608", "088", "0608"), rjct_grp := 1]

# Group 2: Prior Auth
group2_codes <- c("3N", "3P", "3S", "3T", "3W", "03N", "03P", "03S", "03T", "03W",
                  "3X", "3Y", "64", "6Q", "75", "03X", "03Y", "064", "06Q", "075",
                  "80", "EU", "EV", "MV", "PA", "080", "0EU", "0EV", "0MV", "0PA")
claims[rjct_cd %in% group2_codes, rjct_grp := 2]

# Group 3: Not Covered
group3_codes <- c("60", "61", "63", "65", "70", "060", "061", "063", "065", "070",
                  "7Y", "8A", "8H", "9Q", "9R", "9T", "9Y", "BB", "MR",
                  "07Y", "08A", "08H", "09Q", "09R", "09T", "09Y", "0BB", "0MR")
claims[rjct_cd %in% group3_codes, rjct_grp := 3]

# Group 4: Plan Limit
claims[rjct_cd %in% c("76", "7X", "AG", "RN", "076", "07X", "0AG", "0RN"), rjct_grp := 4]

# Group 0: Successful Fill
claims[rjct_cd %in% c("", "00", "000"), rjct_grp := 0]

# Group 5: Non-formulary or Others
claims[is.na(rjct_grp), rjct_grp := 5]

# Tabulate rjct_grp by encnt_outcm_cd
print(claims[, .N, by = .(rjct_grp, encnt_outcm_cd)][order(rjct_grp)])


## =============================
## 4.  Manipulate Claims. Add Plan Info
## =============================

# Could be keeping other variables here, but am choosing not to
plans  <- as.data.table(read_dta(plan_ref))

# Keep only relevant plan variables
keep_vars <- c("plan_id", "model_type", "plan_name",
               "adjudicating_pbm_plan_name", "pay_type_description")
plans <- plans[, ..keep_vars]

# Merge by plan_id
setkey(claims, plan_id)
setkey(plans, plan_id)
claims <- plans[claims, nomatch = 0L]

# Classify plan_type
claims[, plan_type := ""]

# Cash
claims[model_type == "CASH", plan_type := "Cash"]

# Commercial
commercial_types <- c("CDHP", "COMBO", "HMO", "HMO - HR", "INDIVIDUAL",
                      "PPO", "POS", "TRAD IND", "WRAP", "EMPLOYER",
                      "STATE EMP", "FED EMP", "PBM", "PBM BOB", "NON-HMO",
                      "NETWORK", "GROUP", "IPA", "STAFF", "EPO")
claims[model_type %in% commercial_types, plan_type := "Commercial"]

# Medicare TM
medicare_tm <- c("MED PDPG", "MED PDP", "DE MMP", "EMP PDP", "EMP RPDP")
claims[model_type %in% medicare_tm, plan_type := "Medicare TM"]

# Medicare Advantage
medicare_adv <- c("MED ADVG", "MED ADV", "MED SNP", "MED SNPG")
claims[model_type %in% medicare_adv, plan_type := "Medicare ADV"]

# Medicaid MCO
medicaid_mco <- c("MGD MEDI", "MEDICAID")
claims[model_type %in% medicaid_mco, plan_type := "Medicaid MCO"]

# Medicaid FFS
claims[model_type == "FFS MED", plan_type := "Medicaid FFS"]

# Exchange (any model_type containing "HIX")
claims[grepl("HIX", model_type, fixed = TRUE), plan_type := "Exchange"]

# Discount Card
discount_card <- c("DISC CRD", "DISC MED", "SR CRD")
claims[model_type %in% discount_card, plan_type := "Discount Card"]

# Coupon/Voucher
claims[model_type == "VOUCHER", plan_type := "Coupon/Voucher"]

# Fallback to "Other"
claims[plan_type == "", plan_type := "Other"]

# Tabulate model_type x plan_type
print(claims[, .N, by = .(model_type, plan_type)][order(-N)])

## =============================
## 5. Analysis File
## =============================
write_parquet(claims, file.path(data_dir, "B_analytic_file.parquet"), compression = "zstd")

logmsg("Analysis File saved")
