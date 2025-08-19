#!/usr/bin/env Rscript

## --- ensure user lib & pkgs ---
user_lib <- Sys.getenv(
  "R_LIBS_USER",
  unset = file.path(Sys.getenv("HOME"),
                    "R",
                    paste(R.version$major, R.version$minor, sep = "."),
                    "library")
)
if (!dir.exists(user_lib)) dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(user_lib, .libPaths()))

install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE, lib.loc = user_lib)) {
    install.packages(pkg, repos = "https://cloud.r-project.org", lib = user_lib)
  }
}
pkgs <- c("data.table","haven","stringi","arrow")
invisible(lapply(pkgs, install_if_missing))
invisible(lapply(pkgs, function(p) library(p, character.only = TRUE, lib.loc = user_lib)))

suppressPackageStartupMessages({
  library(data.table); library(haven); library(stringi); library(arrow)
})

## ---------------------------
## Config (edit paths here)
## ---------------------------
# Match your Stata working dir, but we keep R files separate
setwd("/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r")

data_dir <- file.path(getwd(), "data")
out_dir  <- file.path(getwd(), "out")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(out_dir,  showWarnings = FALSE, recursive = TRUE)

# Reference files
prod_ref    <- "/dcs07/hpm/data/iqvia_fia/ref/product.dta"
plan_ref    <- "/dcs07/hpm/data/iqvia_fia/ref/plan.dta"
enc_patch   <- "/dcs07/hpm/data/iqvia_fia/full_raw/LevyPDRJRV.dta"  # optional; only used if present

# Choose the same “Attempt B/C” reduced files used in your Stata
claim_files <- c(
  "/dcs07/hpm/data/iqvia_fia/reduced/RxFact_2018_2024_small.dta"
)
claim_files <- claim_files[file.exists(claim_files)]
stopifnot(length(claim_files) > 0)

# Optional: sampling fraction like Stata Attempt C (0.005 = 0.5%)
sample_frac <- NA_real_  # set to 0.005 to mimic Attempt C

## ---------------------------
## Helpers
## ---------------------------
# Standardized names we’ll use
std <- list(
  ndc        = "ndc",
  plan_id    = "plan_id",
  claim_id   = "claim_id",
  rjct_cd    = "rjct_cd",
  rjct_grp   = "rjct_grp",
  encnt_code = "encnt_outcm_cd",
  model_type = "model_type"
)

# Candidate source names (robust to schema variants)
cands <- list(
  ndc        = c("product_ndc","product_ndc11","ndc11","ndc_11","ndc","prod_ndc"),
  plan_id    = c("plan_id","planid","plan_id_num"),
  claim_id   = c("claim_id","claimid","rx_claim_id","claim_num"),
  rjct_cd    = c("rjct_cd","reject_code","rejection_code"),
  encnt_code = c("encnt_outcm_cd","encounter_outcome_code","encnt_code"),
  model_type = c("model_type","modeltype")
)

pick_and_rename <- function(dt, cand_vec, to) {
  hit <- intersect(cand_vec, names(dt))
  if (length(hit)) setnames(dt, hit[1], to)
  dt
}

# Recode rjct_grp from rjct_cd (string), matching Stata groups 0–5
recode_rjct_grp <- function(dt, rjct_cd_col = std$rjct_cd) {
  if (!(rjct_cd_col %in% names(dt))) {
    dt[, (std$rjct_grp) := NA_integer_]
    return(dt)
  }
  # ensure character
  dt[, (rjct_cd_col) := as.character(get(rjct_cd_col))]

  # initialize
  dt[, (std$rjct_grp) := NA_integer_]

  # Group 1: Step edit
  step_set <- c("88","608","088","0608")

  # Group 2: Prior auth
  prior_set <- c("3N","3P","3S","3T","3W","03N","03P","03S","03T","03W",
                 "3X","3Y","64","6Q","75","03X","03Y","064","06Q","075","80",
                 "EU","EV","MV","PA","080","0EU","0EV","0MV","0PA")

  # Group 3: Not covered
  notcov_set <- c("60","61","63","65","70","060","061","063","065","070",
                  "7Y","8A","8H","9Q","9R","9T","9Y","BB","MR",
                  "07Y","08A","08H","09Q","09R","09T","09Y","0BB","0MR")

  # Group 4: Plan limit
  planlim_set <- c("76","7X","AG","RN","076","07X","0AG","0RN")

  # Group 0: Fill
  fill_set <- c("","00","000")

  # Apply in same order as Stata
  dt[get(rjct_cd_col) %in% step_set,     (std$rjct_grp) := 1L]
  dt[get(rjct_cd_col) %in% prior_set,    (std$rjct_grp) := 2L]
  dt[get(rjct_cd_col) %in% notcov_set,   (std$rjct_grp) := 3L]
  dt[get(rjct_cd_col) %in% planlim_set,  (std$rjct_grp) := 4L]
  dt[get(rjct_cd_col) %in% fill_set,     (std$rjct_grp) := 0L]
  # Anything else → 5
  dt[is.na(get(std$rjct_grp)), (std$rjct_grp) := 5L]

  dt
}

# Plan-type mapping (base) + rules
plan_map <- fread(text="
model_type,plan_type
CASH,Cash
MED PDPG,Medicare TM
MED PDP,Medicare TM
DE MMP,Medicare TM
EMP PDP,Medicare TM
EMP RPDP,Medicare TM
MED ADVG,Medicare ADV
MED ADV,Medicare ADV
FFS MED,Medicaid FFS
MGD MEDI,Medicaid MCO
MEDICAID,Medicaid MCO
VOUCHER,Coupon/Voucher
DISC CRD,Discount Card
DISC MED,Discount Card
SR CRD,Discount Card
CDHP,Commercial
COMBO,Commercial
HMO,Commercial
HMO - HR,Commercial
INDIVIDUAL,Commercial
PPO,Commercial
POS,Commercial
TRAD IND,Commercial
WRAP,Commercial
EMPLOYER,Commercial
STATE EMP,Commercial
FED EMP,Commercial
PBM,Commercial
PBM BOB,Commercial
NON-HMO,Commercial
NETWORK,Commercial
GROUP,Commercial
IPA,Commercial
STAFF,Commercial
EPO,Commercial
")

derive_plan_type <- function(plan_dt) {
  # normalize
  if (!std$model_type %in% names(plan_dt)) plan_dt[, (std$model_type) := NA_character_]
  plan_dt[, (std$model_type) := stri_trans_toupper(stri_trim_both(as.character(get(std$model_type))))]

  setkey(plan_map, model_type)
  setkeyv(plan_dt, std$model_type)
  out <- plan_map[plan_dt, on = "model_type"]

  # HIX substring → Exchange
  out[grepl("HIX", get(std$model_type), fixed = TRUE), plan_type := "Exchange"]
  # Fallback
  out[is.na(plan_type) | plan_type == "", plan_type := "Other"]
  out
}

## ---------------------------
## 1) Products – ADALIMUMAB NDCs
## ---------------------------
cat("Reading product:", prod_ref, "\n")
prod <- as.data.table(read_dta(prod_ref))
# find molecule_name column
mol_col <- intersect(c("molecule_name","molecule","molecule_desc"), names(prod))
stopifnot(length(mol_col) > 0)
setnames(prod, mol_col[1], "molecule_name")

# normalize and filter
prod[, molecule_name := stri_trans_toupper(stri_trim_both(molecule_name))]

# find NDC column and standardize
prod <- pick_and_rename(prod, cands$ndc, std$ndc)
stopifnot(std$ndc %in% names(prod))

adali_ndcs <- unique(prod[grepl("ADALIMUMAB", molecule_name, ignore.case = TRUE), .(ndc = get(std$ndc))])
# keep as character to be lenient when joining, also make a numeric version for numeric NDCs
adali_ndcs[, ndc_chr := as.character(ndc)]
suppressWarnings(adali_ndcs[, ndc_num := as.numeric(ndc)])
setkey(adali_ndcs, ndc_chr)
cat("ADALIMUMAB NDCs:", nrow(adali_ndcs), "\n")

## ---------------------------
## 2) Plan metadata
## ---------------------------
cat("Reading plan metadata:", plan_ref, "\n")
plan <- as.data.table(read_dta(plan_ref))
plan <- pick_and_rename(plan, cands$plan_id, std$plan_id)
plan <- pick_and_rename(plan, cands$model_type, std$model_type)
stopifnot(std$plan_id %in% names(plan))
plan[, (std$plan_id) := as.character(get(std$plan_id))]
plan <- derive_plan_type(plan)
plan <- plan[, .(plan_id = get(std$plan_id), model_type = get(std$model_type), plan_type)]
setkey(plan, plan_id)

## ---------------------------
## 3) Claims: read, normalize, filter, rjct_grp, encnt patch, plan merge
## ---------------------------
read_claims <- function(p) {
  cat("  ->", p, "\n")
  dt <- as.data.table(read_dta(p))

  # Sampling like Stata Attempt C if requested
  if (is.finite(sample_frac) && !is.na(sample_frac) && sample_frac > 0 && sample_frac < 1) {
    dt <- dt[runif(.N) < sample_frac]
  }

  # rename to standardized names if present
  dt <- pick_and_rename(dt, cands$ndc,        std$ndc)
  dt <- pick_and_rename(dt, cands$plan_id,    std$plan_id)
  dt <- pick_and_rename(dt, cands$claim_id,   std$claim_id)
  dt <- pick_and_rename(dt, cands$rjct_cd,    std$rjct_cd)
  dt <- pick_and_rename(dt, cands$encnt_code, std$encnt_code)

  # keep relevant
  keep <- intersect(names(dt), c(std$claim_id, std$ndc, std$plan_id, std$rjct_cd, std$encnt_code))
  dt <- dt[, ..keep]

  # normalize types
  if (std$claim_id %in% names(dt)) dt[, (std$claim_id) := as.character(get(std$claim_id))]
  if (std$plan_id  %in% names(dt)) dt[, (std$plan_id)  := as.character(get(std$plan_id))]
  if (std$ndc      %in% names(dt)) {
    dt[, ndc_chr := as.character(get(std$ndc))]
    suppressWarnings(dt[, ndc_num := as.numeric(get(std$ndc))])
  } else {
    dt[, c("ndc_chr","ndc_num") := .(NA_character_, NA_real_)]
  }

  # filter to ADALIMUMAB by either char or numeric match
  setkey(dt, ndc_chr)
  dt1 <- adali_ndcs[dt, on = "ndc_chr==ndc_chr", nomatch = 0L]

  if (nrow(dt1) == 0L) {
    # try numeric join (for purely numeric NDCs)
    setkey(adali_ndcs, ndc_num); setkey(dt, ndc_num)
    dt1 <- adali_ndcs[dt, on = "ndc_num==ndc_num", nomatch = 0L]
  }

  if (nrow(dt1) == 0L) return(data.table())

  # recode rjct_grp from rjct_cd to match Stata logic
  dt1 <- recode_rjct_grp(dt1, rjct_cd_col = std$rjct_cd)

  # patch encnt_outcm_cd if missing and patch file exists
  if (!(std$encnt_code %in% names(dt1)) && file.exists(enc_patch)) {
    ep <- as.data.table(read_dta(enc_patch))
    ep <- pick_and_rename(ep, cands$claim_id, std$claim_id)
    ep <- pick_and_rename(ep, cands$encnt_code, std$encnt_code)
    if (all(c(std$claim_id,std$encnt_code) %in% names(ep))) {
      ep <- ep[, .(claim_id = as.character(get(std$claim_id)),
                   encnt_outcm_cd = as.character(get(std$encnt_code)))]
      setkey(ep, claim_id)
      setkeyv(dt1, std$claim_id)
      dt1 <- ep[dt1, on = "claim_id", nomatch = 0L]
    }
  }

  # merge plan metadata
  if (std$plan_id %in% names(dt1)) {
    setkeyv(dt1, std$plan_id)
    dt1 <- plan[dt1, on = "plan_id"]
  } else {
    dt1[, c("model_type","plan_type") := .(NA_character_, "Other")]
  }

  # nice label for rjct_grp
  lvl <- c("Fill","Step edit","Prior auth","Not covered","Plan limit","Other")
  dt1[, rjct_grp_lbl := fifelse(get(std$rjct_grp) %in% 0:5, lvl[get(std$rjct_grp)+1L], NA_character_)]

  dt1
}

cat("Start:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
parts <- lapply(claim_files, read_claims)
claims_adali <- rbindlist(parts, use.names = TRUE, fill = TRUE)
cat("ADALIMUMAB claims rows:", nrow(claims_adali), "\n")

## ---------------------------
## 4) Save outputs
## ---------------------------
# Reorder a bit for convenience
ord <- intersect(c("claim_id","ndc","ndc_chr","plan_id","model_type","plan_type",
                   "rjct_cd","rjct_grp","rjct_grp_lbl","encnt_outcm_cd"), names(claims_adali))
setcolorder(claims_adali, c(ord, setdiff(names(claims_adali), ord)))

# Parquet (recommended for speed/interop)
out_parquet <- file.path(out_dir, "adalimumab_claims.parquet")
write_parquet(claims_adali, out_parquet, compression = "zstd")
cat("Wrote Parquet:", out_parquet, "\n")

# Optional RDS (handy inside R)
out_rds <- file.path(out_dir, "adalimumab_claims.rds")
saveRDS(claims_adali, out_rds)
cat("Wrote RDS:", out_rds, "\n")

cat("Done.\n")
