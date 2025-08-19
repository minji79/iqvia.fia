#!/usr/bin/env Rscript

## =============================
## 0) Setup & libraries
## =============================
suppressPackageStartupMessages({
  library(data.table)
  library(haven)
  library(arrow)
  library(fst)
})

`%||%` <- function(a, b) if (is.null(a)) b else a
ts_now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")

# --- Paths (align with your previous script) ---
setwd("/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r")

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

# Raw/reference
prod_ref <- "/dcs07/hpm/data/iqvia_fia/ref/product.dta"
plan_ref <- "/dcs07/hpm/data/iqvia_fia/ref/plan.dta"
encpatch_ref <- "/dcs07/hpm/data/iqvia_fia/full_raw/LevyPDRJRV.dta"

# Full raw (fst) per-year for Attempt A
years_A <- c(2018, 2020, 2022, 2024)
raw_dir_A <- "/dcs07/hpm/data/iqvia_fia/full_raw"

# Reduced single file for Attempt B/C
reduced_fst <- "/dcs07/hpm/data/iqvia_fia/reduced/RxFact_2018_2024_small.fst"

save_parquet <- function(dt, path, compression = "zstd") {
  write_parquet(as.data.frame(dt), path, compression = compression)
  cat("[", ts_now(), "] Wrote:", path, "\n")
}

## =============================
## (1) Product file → ADALIMUMAB NDCs (Stata step 1)
## =============================
cat("[", ts_now(), "] Step 1: Building ADALIMUMAB NDC list…\n")
prod <- as.data.table(read_dta(prod_ref))
keep_cols <- intersect(c("product_ndc", "usc_3_description", "molecule_name", "drug_labeler_corp_name"),
                       names(prod))
prod <- prod[, ..keep_cols]
prod_adali <- prod[grepl("ADALIMUMAB", molecule_name %||% "", ignore.case = TRUE)]

save_parquet(prod_adali, file.path(data_dir, "ADALIMUMAB_NDCs.parquet"))
ndcs <- unique(prod_adali[, .(product_ndc)])
setkey(ndcs, product_ndc)
rm(prod, prod_adali); gc()

## =============================
## Prepare encpatch (claim_id → encnt_outcm_cd)
## =============================
cat("[", ts_now(), "] Loading encpatch mapping…\n")
# Try column-select (newer haven). If not supported, fall back to full and subset.
encpatch <- tryCatch({
  as.data.table(read_dta(encpatch_ref, col_select = c("claim_id", "encnt_outcm_cd")))
}, error = function(e) {
  cat("  -> haven::read_dta col_select not available; reading then subsetting.\n")
  as.data.table(read_dta(encpatch_ref))[, .(claim_id, encnt_outcm_cd)]
})
setkey(encpatch, claim_id)

## =============================
## (2) Attempt A — year-by-year (Stata Attempt A)
## =============================
cat("[", ts_now(), "] Step 2A: Attempt A (year-by-year)…\n")

cols_needed_A <- c("claim_id", "ndc", "daw_cd", "plan_id", "rjct_cd")
out_A_parts <- character(0)

for (yr in years_A) {
  cat("  -> Processing year", yr, "\n")
  f_in <- file.path(raw_dir_A, sprintf("RxFact%d.fst", yr))
  if (!file.exists(f_in)) {
    cat("     (skip) Missing file:", f_in, "\n")
    next
  }

  # Read only columns we need
  rx <- as.data.table(fst::read_fst(f_in, columns = intersect(cols_needed_A, fst::metadata_fst(f_in)$columnNames)))

  # daw_cd -> daw_cd_s, ndc -> product_ndc
  if ("daw_cd" %in% names(rx) && !"daw_cd_s" %in% names(rx)) setnames(rx, "daw_cd", "daw_cd_s")
  if ("ndc"    %in% names(rx) && !"product_ndc" %in% names(rx)) setnames(rx, "ndc", "product_ndc")

  # encpatch merge (keep matched only, like Stata keep(3))
  if (!("claim_id" %in% names(rx))) {
    cat("     (skip) claim_id not present in", f_in, "\n")
    next
  }
  setkey(rx, claim_id)
  rx <- encpatch[rx, nomatch = 0L]

  # Filter to ADALIMUMAB ndcs
  if (!("product_ndc" %in% names(rx))) {
    cat("     (skip) product_ndc not present in", f_in, "\n")
    next
  }
  setkey(rx, product_ndc)
  rx <- ndcs[rx, nomatch = 0L]

  # Write per-year parquet
  f_out <- file.path(data_dir, sprintf("A_ADALIMUMAB_claims_%d.parquet", yr))
  save_parquet(rx, f_out)
  out_A_parts <- c(out_A_parts, f_out)
  rm(rx); gc()
}

# Optional: make a *logical dataset* across the per-year files (no big in-RAM bind)
# You can query it later with Arrow without merging into one big file.
cat("[", ts_now(), "] Attempt A per-year files:", length(out_A_parts), "\n")

## =============================
## (2) Attempt B — reduced file (Stata Attempt B)
## =============================
cat("[", ts_now(), "] Step 2B: Attempt B (reduced)…\n")
if (!file.exists(reduced_fst)) {
  stop("Reduced fst not found: ", reduced_fst)
}
cols_needed_B <- c("claim_id", "ndc", "plan_id", "rjct_cd")
rxB <- as.data.table(fst::read_fst(reduced_fst,
                                   columns = intersect(cols_needed_B, fst::metadata_fst(reduced_fst)$columnNames)))

if ("ndc" %in% names(rxB) && !"product_ndc" %in% names(rxB)) setnames(rxB, "ndc", "product_ndc")
# Filter to ADALIMUMAB ndcs
setkey(rxB, product_ndc)
rxB <- ndcs[rxB, nomatch = 0L]
save_parquet(rxB, file.path(data_dir, "B_ADALIMUMAB_claims.parquet"))
rm(rxB); gc()

## =============================
## (2) Attempt C — 0.5% sample of reduced (Stata Attempt C)
## =============================
cat("[", ts_now(), "] Step 2C: Attempt C (0.5% sample)…\n")
rxC <- as.data.table(fst::read_fst(reduced_fst,
                                   columns = intersect(cols_needed_B, fst::metadata_fst(reduced_fst)$columnNames)))
set.seed(123)
rxC <- rxC[runif(.N) < 0.005]
if ("ndc" %in% names(rxC) && !"product_ndc" %in% names(rxC)) setnames(rxC, "ndc", "product_ndc")
setkey(rxC, product_ndc)
rxC <- ndcs[rxC, nomatch = 0L]
save_parquet(rxC, file.path(data_dir, "C_ADALIMUMAB_claims.parquet"))
rm(rxC); gc()

## =============================
## (3) Rejection groups on Attempt B (Stata step 3)
## =============================
cat("[", ts_now(), "] Step 3: Rejection group classification on B…\n")
B <- as.data.table(read_parquet(file.path(data_dir, "B_ADALIMUMAB_claims.parquet")))

# rjct_cd ensure character; build rjct_grp
if (!"rjct_cd" %in% names(B)) B[, rjct_cd := NA_character_]
B[, rjct_cd := as.character(rjct_cd)]
B[, rjct_grp := NA_integer_]

step_set   <- c("88","608","088","0608")
prior_set  <- c("3N","3P","3S","3T","3W","03N","03P","03S","03T","03W",
                "3X","3Y","64","6Q","75","03X","03Y","064","06Q","075","80",
                "EU","EV","MV","PA","080","0EU","0EV","0MV","0PA")
notcov_set <- c("60","61","63","65","70","060","061","063","065","070",
                "7Y","8A","8H","9Q","9R","9T","9Y","BB","MR",
                "07Y","08A","08H","09Q","09R","09T","09Y","0BB","0MR")
planlim_set<- c("76","7X","AG","RN","076","07X","0AG","0RN")
fill_set   <- c("","00","000")

B[rjct_cd %in% step_set,    rjct_grp := 1L]
B[rjct_cd %in% prior_set,   rjct_grp := 2L]
B[rjct_cd %in% notcov_set,  rjct_grp := 3L]
B[rjct_cd %in% planlim_set, rjct_grp := 4L]
B[rjct_cd %in% fill_set,    rjct_grp := 0L]
B[is.na(rjct_grp),          rjct_grp := 5L]

## =============================
## (4) Plan merge & plan_type (Stata step 4)
## =============================
cat("[", ts_now(), "] Step 4: Plan merge and plan_type derivation…\n")
plan_keep <- c("plan_id","model_type","plan_name","adjudicating_pbm_plan_name","pay_type_description")
plan <- as.data.table(read_dta(plan_ref))
plan <- plan[, intersect(plan_keep, names(plan)), with = FALSE]

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
B[model_type %in% "VOUCHER", plan_type := "Coupon/Voucher"]
# Fallback
B[plan_type == "" | is.na(plan_type), plan_type := "Other"]

## =============================
## (5) Analysis file (Stata step 5)
## =============================
cat("[", ts_now(), "] Step 5: Write B_analytic_file.parquet…\n")
save_parquet(B, file.path(data_dir, "B_analytic_file.parquet"))
rm(B, plan); gc()

cat("[", ts_now(), "] All done.\n")
