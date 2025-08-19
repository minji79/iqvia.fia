#!/usr/bin/env Rscript

## =============================
## Setup & libraries
## =============================
suppressPackageStartupMessages({
  library(data.table)
  library(haven)
  library(arrow)
  library(fst)
})

`%||%` <- function(a, b) if (is.null(a)) b else a
ts_now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")
save_parquet <- function(dt, path, compression = "zstd") {
  write_parquet(as.data.frame(dt), path, compression = compression)
  cat("[", ts_now(), "] Wrote:", path, "\n")
}

## =============================
## Paths (same as before)
## =============================
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

# References
prod_ref     <- "/dcs07/hpm/data/iqvia_fia/ref/product.dta"
plan_ref     <- "/dcs07/hpm/data/iqvia_fia/ref/plan.dta"  # not used in this script, but kept for consistency
encpatch_ref <- "/dcs07/hpm/data/iqvia_fia/full_raw/LevyPDRJRV.dta"

# Attempt A sources (per-year fst)
years_A  <- c(2018, 2020, 2022, 2024)
raw_dirA <- "/dcs07/hpm/data/iqvia_fia/full_raw"

# Attempt B/C source (reduced fst)
reduced_fst <- "/dcs07/hpm/data/iqvia_fia/reduced/RxFact_2018_2024_small.fst"

## =============================
## (1) Product file → ADALIMUMAB NDCs
## =============================
cat("[", ts_now(), "] Step 1: Build ADALIMUMAB NDC list…\n")
prod <- as.data.table(read_dta(prod_ref))
keep_cols <- intersect(c("product_ndc","usc_3_description","molecule_name","drug_labeler_corp_name"),
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
cat("[", ts_now(), "] Load encpatch mapping…\n")
encpatch <- tryCatch({
  as.data.table(read_dta(encpatch_ref, col_select = c("claim_id","encnt_outcm_cd")))
}, error = function(e) {
  as.data.table(read_dta(encpatch_ref))[, .(claim_id, encnt_outcm_cd)]
})
setkey(encpatch, claim_id)

## =============================
## (2A) Attempt A — per-year processing
## =============================
cat("[", ts_now(), "] Step 2A: Attempt A (year-by-year)…\n")
cols_needed_A <- c("claim_id","ndc","daw_cd","plan_id","rjct_cd")
out_A_parts <- character(0)

for (yr in years_A) {
  f_in <- file.path(raw_dirA, sprintf("RxFact%d.fst", yr))
  if (!file.exists(f_in)) {
    cat("  -> Skip missing:", f_in, "\n"); next
  }
  cat("  -> Year", yr, "\n")

  cols_avail <- tryCatch(fst::metadata_fst(f_in)$columnNames, error = function(e) NULL)
  rx <- as.data.table(fst::read_fst(f_in, columns = intersect(cols_needed_A, cols_avail %||% cols_needed_A)))

  # daw_cd -> daw_cd_s; ndc -> product_ndc
  if ("daw_cd" %in% names(rx) && !"daw_cd_s" %in% names(rx)) setnames(rx, "daw_cd", "daw_cd_s")
  if ("ndc"    %in% names(rx) && !"product_ndc" %in% names(rx)) setnames(rx, "ndc", "product_ndc")

  # Merge encpatch (keep matched only)
  if (!("claim_id" %in% names(rx))) { cat("     (skip) claim_id missing\n"); next }
  setkey(rx, claim_id)
  rx <- encpatch[rx, nomatch = 0L]

  # Filter to ADALIMUMAB NDCs
  if (!("product_ndc" %in% names(rx))) { cat("     (skip) product_ndc missing\n"); next }
  setkey(rx, product_ndc)
  rx <- ndcs[rx, nomatch = 0L]

  f_out <- file.path(data_dir, sprintf("A_ADALIMUMAB_claims_%d.parquet", yr))
  save_parquet(rx, f_out)
  out_A_parts <- c(out_A_parts, f_out)

  rm(rx); gc()
}
cat("[", ts_now(), "] Attempt A files written:", length(out_A_parts), "\n")

## =============================
## (2B) Attempt B — reduced file (full range)
## =============================
cat("[", ts_now(), "] Step 2B: Attempt B (reduced)…\n")
stopifnot(file.exists(reduced_fst))
cols_needed_B <- c("claim_id","ndc","plan_id","rjct_cd")
cols_avail_B  <- tryCatch(fst::metadata_fst(reduced_fst)$columnNames, error = function(e) NULL)

rxB <- as.data.table(fst::read_fst(reduced_fst,
                                   columns = intersect(cols_needed_B, cols_avail_B %||% cols_needed_B)))
if ("ndc" %in% names(rxB) && !"product_ndc" %in% names(rxB)) setnames(rxB, "ndc", "product_ndc")
setkey(rxB, product_ndc)
rxB <- ndcs[rxB, nomatch = 0L]
save_parquet(rxB, file.path(data_dir, "B_ADALIMUMAB_claims.parquet"))
rm(rxB); gc()

## =============================
## (2C) Attempt C — 0.5% sample of reduced
## =============================
cat("[", ts_now(), "] Step 2C: Attempt C (0.5% sample)…\n")
rxC <- as.data.table(fst::read_fst(reduced_fst,
                                   columns = intersect(cols_needed_B, cols_avail_B %||% cols_needed_B)))
set.seed(123)
rxC <- rxC[runif(.N) < 0.005]
if ("ndc" %in% names(rxC) && !"product_ndc" %in% names(rxC)) setnames(rxC, "ndc", "product_ndc")
setkey(rxC, product_ndc)
rxC <- ndcs[rxC, nomatch = 0L]
save_parquet(rxC, file.path(data_dir, "C_ADALIMUMAB_claims.parquet"))
rm(rxC); gc()

cat("[", ts_now(), "] Done (Attempts A/B/C).\n")
