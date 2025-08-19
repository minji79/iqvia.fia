#!/usr/bin/env Rscript

## --- ensure user lib & arrow present (no .sh changes) ---
user_lib <- Sys.getenv(
  "R_LIBS_USER",
  unset = file.path(Sys.getenv("HOME"),
                    "R",
                    paste(R.version$major, R.version$minor, sep = "."),
                    "library")
)
if (!dir.exists(user_lib)) dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(user_lib, .libPaths()))  # prefer user lib first

install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE, lib.loc = user_lib)) {
    install.packages(pkg, repos = "https://cloud.r-project.org", lib = user_lib)
  }
}
pkgs <- c("arrow", "data.table", "haven", "stringi", "fst")
lapply(pkgs, install_if_missing)


invisible(lapply(pkgs, function(p) library(p, character.only = TRUE, lib.loc = user_lib)))
                 
## --- end ensure user lib ---

suppressPackageStartupMessages({
  library(data.table)
  library(haven)
  library(stringi)
  library(fst)
  library(arrow)     # for parquet
})

                 
## ===========================================================
## 0. SET WORKING DIRECTORY & DEFINE PATHS
## ===========================================================
setwd("/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r")

data_dir <- file.path(getwd(), "data")
out_dir  <- file.path(getwd(), "out")
errs_dir  <- file.path(getwd(), "errs")
figs_dir  <- file.path(getwd(), "figures")
tabs_dir  <- file.path(getwd(), "tables")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(out_dir,  showWarnings = FALSE, recursive = TRUE)
dir.create(errs_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(figs_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tabs_dir, showWarnings = FALSE, recursive = TRUE)

# Reference files (dta)
prod_ref    <- "/dcs07/hpm/data/iqvia_fia/ref/product.dta"
plan_ref    <- "/dcs07/hpm/data/iqvia_fia/ref/plan.dta"
patient_ref    <- "/dcs07/hpm/data/iqvia_fia/ref/patient.dta"
provider_ref    <- "/dcs07/hpm/data/iqvia_fia/ref/provider.dta"
encpatch <- as.data.table(read_dta("/dcs07/hpm/data/iqvia_fia/full_raw/LevyPDRJRV.dta"))

# Choose the same “Attempt B/C” reduced files used in your Stata
claim_files <- c(
  "/dcs07/hpm/data/iqvia_fia/reduced/RxFact_2018_2024_small.fst"
)
claim_files <- claim_files[file.exists(claim_files)]
stopifnot(length(claim_files) > 0)

## Small helpers
tab <- function(x, y = NULL, sort = FALSE) {
  if (is.null(y)) {
    tt <- sort(table(x), decreasing = TRUE)
  } else {
    tt <- table(x, y)
    if (sort) tt <- tt[order(rowSums(tt), decreasing = TRUE), , drop = FALSE]
  }
  print(tt)
}
                 
save_parquet <- function(dt, path, compression = "zstd") {
  write_parquet(as.data.frame(dt), path, compression = compression)
  cat("Wrote Parquet:", path, "\n")
}
                 
ts_now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")

## ===========================================================
## (1) Load Product File. Filter to Drug Of Interest. Save NDCs : ~2:20
## ===========================================================
prod <- as.data.table(read_dta(prod_ref))

# use if strpos(molecule_name,"ADALIMUMAB")
#stopifnot("molecule_name" %in% names(prod))
#prod_adali <- prod[grepl("ADALIMUMAB", molecule_name, fixed = TRUE)]

# molecule_name, sort
#cat("== Table: molecule_name (sorted) ==\n")
#tab(prod_adali$molecule_name)

# keep product_ndc usc_3_description molecule_name drug_labeler_corp_name
#keep_cols <- c("product_ndc", "usc_3_description", "molecule_name", "drug_labeler_corp_name")
#keep_cols <- intersect(keep_cols, names(prod_adali))
#prod_adali <- prod_adali[, ..keep_cols]

#if (all(c("molecule_name","drug_labeler_corp_name") %in% names(prod_adali))) {
#  cat("== Table: molecule_name x drug_labeler_corp_name ==\n")
#  tab(prod_adali$molecule_name, prod_adali$drug_labeler_corp_name)
#}

#save_parquet(prod_adali, file.path(data_dir, "ADALIMUMAB_NDCs.parquet"))
prod_adali <- read_parquet(file.path(data_dir, "ADALIMUMAB_NDCs.parquet"))
                 
## =====================================================================
## (2) LOAD & COMBINE RAW CLAIMS FOR MULTIPLE YEARS: Many Ways to Do this
## =====================================================================

## Attempt A (full raw, largest)
cat("Time:", ts_now(), "\n")
rx2018 <- as.data.table(read_fst("/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2018.fst"))
rx2020 <- as.data.table(read_fst("/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2020.fst"))
rx2022 <- as.data.table(read_fst("/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2022.fst"))
rx2024 <- as.data.table(read_fst("/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2024.fst"))

rxA <- rbindlist(list(rx2018, rx2020, rx2022, rx2024), use.names = TRUE, fill = TRUE)
rm(rx2018, rx2020, rx2022, rx2024); gc()

# rename daw_cd daw_cd_s
if ("daw_cd" %in% names(rxA) && !"daw_cd_s" %in% names(rxA)) {
  setnames(rxA, "daw_cd", "daw_cd_s")
}

# merge encnt_outcm_cd by claim_id
stopifnot("claim_id" %in% names(rxA), "claim_id" %in% names(encpatch))
encpatch <- encpatch[, .(claim_id, encnt_outcm_cd)]
setkey(encpatch, claim_id)
setkey(rxA, claim_id)
rxA <- encpatch[rxA]  # keep matched (Stata keep(3)); rows without match dropped

# rename ndc product_ndc before NDC merge
if ("ndc" %in% names(rxA) && !"product_ndc" %in% names(rxA)) {
  setnames(rxA, "ndc", "product_ndc")
}

ndcs <- as.data.table(read_parquet(file.path(data_dir, "ADALIMUMAB_NDCs.parquet")))[, .(product_ndc)]
ndcs <- unique(ndcs)
setkey(ndcs, product_ndc)
setkey(rxA,  product_ndc)
rxA <- ndcs[rxA, nomatch = 0L]  # keep matched only

save_parquet(rxA, file.path(data_dir, "A_ADALIMUMAB_claims.parquet"))
rm(rxA); gc()
cat("Time:", ts_now(), "\n")
# ** in R vs. ~2:30 in Stata

## Attempt B (reduced file, efficient)
cat("Time:", ts_now(), "\n")
rxB <- as.data.table(read_fst("/dcs07/hpm/data/iqvia_fia/reduced/RxFact_2018_2024_small.fst"))

if ("ndc" %in% names(rxB) && !"product_ndc" %in% names(rxB)) {
  setnames(rxB, "ndc", "product_ndc")
}

setkey(rxB,  product_ndc)
rxB <- ndcs[rxB, nomatch = 0L]

save_parquet(rxB, file.path(data_dir, "B_ADALIMUMAB_claims.parquet"))
cat("Time:", ts_now(), "\n")
# ** in R vs. 35 Minutes in Stata

## Attempt C (random 0.5% sample of reduced)
cat("Time:", ts_now(), "\n")
rxC <- as.data.table(read_fst("/dcs07/hpm/data/iqvia_fia/reduced/RxFact_2018_2024_small.fst"))
set.seed(123)
rxC <- rxC[runif(.N) < 0.005]

if ("ndc" %in% names(rxC) && !"product_ndc" %in% names(rxC)) {
  setnames(rxC, "ndc", "product_ndc")
}
setkey(rxC, product_ndc)
rxC <- ndcs[rxC, nomatch = 0L]
save_parquet(rxC, file.path(data_dir, "C_ADALIMUMAB_claims.parquet"))
cat("Time:", ts_now(), "\n")
# 90 seconds in Stata (comment preserved)

## ======================================================
## (3) Manipulate Claims. Improve Reject Reason (best guess)
## ======================================================
# Using B (as in Stata)
B <- as.data.table(read_parquet(file.path(data_dir, "B_ADALIMUMAB_claims.parquet")))

# Classify rejection groups
# Stata column is rjct_cd (codes), we will create rjct_grp
if (!"rjct_cd" %in% names(B)) B[, rjct_cd := NA_character_]
B[, rjct_cd := as.character(rjct_cd)]

B[, rjct_grp := NA_integer_]

# Step edit (group 1)
step_set <- c("88","608","088","0608")
B[rjct_cd %in% step_set, rjct_grp := 1L]

# Prior auth (group 2)
prior_set <- c("3N","3P","3S","3T","3W","03N","03P","03S","03T","03W",
               "3X","3Y","64","6Q","75","03X","03Y","064","06Q","075","80",
               "EU","EV","MV","PA","080","0EU","0EV","0MV","0PA")
B[rjct_cd %in% prior_set, rjct_grp := 2L]

# Not covered (group 3)
notcov_set <- c("60","61","63","65","70","060","061","063","065","070",
                "7Y","8A","8H","9Q","9R","9T","9Y","BB","MR",
                "07Y","08A","08H","09Q","09R","09T","09Y","0BB","0MR")
B[rjct_cd %in% notcov_set, rjct_grp := 3L]

# Plan limit (group 4)
planlim_set <- c("76","7X","AG","RN","076","07X","0AG","0RN")
B[rjct_cd %in% planlim_set, rjct_grp := 4L]

# Fill (group 0)
fill_set <- c("","00","000")
B[rjct_cd %in% fill_set, rjct_grp := 0L]

# Anything else -> non-formulary (group 5)
B[is.na(rjct_grp), rjct_grp := 5L]

# Stata: tab rjct_grp encnt_outcm_cd
if ("encnt_outcm_cd" %in% names(B)) {
  cat("== Table: rjct_grp x encnt_outcm_cd ==\n")
  tab(B$rjct_grp, B$encnt_outcm_cd)
}

## ===================================
## (4) Manipulate Claims. Add Plan Info
## ===================================
plan <- as.data.table(read_dta(plan_ref))

# Keep only needed columns when merging
keep_plan <- c("plan_id","model_type","plan_name","adjudicating_pbm_plan_name","pay_type_description")
keep_plan <- intersect(keep_plan, names(plan))
plan <- plan[, ..keep_plan]

# Derive plan_type per the Stata mapping
B <- merge(B, plan, by = "plan_id", all.x = TRUE)

B[, plan_type := ""]
# Cash
B[model_type == "CASH", plan_type := "Cash"]

# Commercial
comm_types <- c("CDHP","COMBO","HMO","HMO - HR","INDIVIDUAL",
                "PPO","POS","TRAD IND","WRAP","EMPLOYER",
                "STATE EMP","FED EMP","PBM","PBM BOB","NON-HMO",
                "NETWORK","GROUP","IPA","STAFF","EPO")
B[model_type %in% comm_types, plan_type := "Commercial"]

# Medicare PDP (TM)
tm_types <- c("MED PDPG","MED PDP","DE MMP","EMP PDP","EMP RPDP")
B[model_type %in% tm_types, plan_type := "Medicare TM"]

# Medicare Advantage
adv_types <- c("MED ADVG","MED ADV","MED SNP","MED SNPG")
B[model_type %in% adv_types, plan_type := "Medicare ADV"]

# Medicaid MCO
B[model_type %in% c("MGD MEDI","MEDICAID"), plan_type := "Medicaid MCO"]

# Medicaid FFS
B[model_type == "FFS MED", plan_type := "Medicaid FFS"]

# Exchange (HIX substring)
B[grepl("HIX", model_type %||% "", fixed = TRUE), plan_type := "Exchange"]

# Coupon/Voucher & Discount Card
B[model_type %in% c("DISC CRD","DISC MED","SR CRD"), plan_type := "Discount Card"]
B[model_type %in% c("VOUCHER"), plan_type := "Coupon/Voucher"]

# Fallback to Other
B[plan_type == "" | is.na(plan_type), plan_type := "Other"]

# Stata: tab model_type plan_type
cat("== Table: model_type x plan_type ==\n")
tab(B$model_type, B$plan_type)

## ====================
## (5) Analysis File
## ====================
save_parquet(B, file.path(data_dir, "B_analytic_file.parquet"))
cat("Time:", ts_now(), "\n")



                 
