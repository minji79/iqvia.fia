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

if (!requireNamespace("arrow", quietly = TRUE)) {
  install.packages("arrow",
                   repos = "https://cloud.r-project.org",
                   lib   = user_lib)
}

library(arrow)
## --- end ensure user lib ---

suppressPackageStartupMessages({
  library(data.table)
  library(haven)
  library(stringi)
  library(arrow)     # for parquet
})

# ---------------------------
# Config
# ---------------------------
setwd("/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r")

data_dir <- file.path(getwd(), "data")
out_dir  <- file.path(getwd(), "out")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(out_dir,  showWarnings = FALSE, recursive = TRUE)

prod_ref <- "/dcs07/hpm/data/iqvia_fia/ref/product.dta"
plan_ref <- "/dcs07/hpm/data/iqvia_fia/ref/plan.dta"

claim_files <- c(
  "/dcs07/hpm/data/iqvia_fia/reduced/RxFact2022_small.dta",
  "/dcs07/hpm/data/iqvia_fia/reduced/RxFact2024_small.dta"
)

claim_filesa <- claim_files[file.exists(claim_files)]
stopifnot(length(claim_files) > 0)

# Name candidates (auto-detect and normalize)
cands <- list(
  ndc         = c("product_ndc","product_ndc11","ndc11","ndc_11","ndc","prod_ndc"),
  plan_id     = c("plan_id","planid","plan_id_num"),
  claim_id    = c("claim_id","claimid","rx_claim_id","claim_num"),
  rjct_grp    = c("rjct_grp","reject_group","rejection_group"),
  encnt_code  = c("encnt_outcm_cd","encounter_outcome_code","encnt_code"),
  model_type  = c("model_type","modeltype")
)

std <- list(                      # standardized names we?ll use after renaming
  ndc        = "ndc",
  plan_id    = "plan_id",
  claim_id   = "claim_id",
  rjct_grp   = "rjct_grp",
  encnt_code = "encnt_outcm_cd",
  model_type = "model_type"
)

# Plan-type mapping
plan_map <- fread(text="
model_type,plan_type
CASH,Cash
MED PDPG,Medicare TM
MED PDP,Medicare TM
DE MMP,Medicare TM
MED ADVG,Medicare Advantage
MED ADV,Medicare Advantage
FFS MED,Medicaid FFS
MED MCO,Medicaid MCO
VOUCHER,Coupon/Voucher
DISC CRD,Discount Card
DISC MED,Discount Card
SR CRD,Discount Card
CDHP,Commercial
PPO,Commercial
POS,Commercial
HMO,Commercial
EPO,Commercial
INDIVIDUAL,Commercial
PBM,Commercial
PBM BOB,Commercial
STATE EMP,Commercial
FED EMP,Commercial
EMPLOYER,Commercial
")

# ---------------------------
# Helpers
# ---------------------------
pick_and_rename <- function(dt, cand_vec, to) {
  hit <- intersect(cand_vec, names(dt))
  if (length(hit)) setnames(dt, hit[1], to)
  dt
}
normalize_cols <- function(dt, needed) {
  # force types for join keys if present
  for (nm in intersect(needed, names(dt))) set(dt, j = nm, value = as.character(dt[[nm]]))
  dt
}

# ---------------------------
# Logging
# ---------------------------
ts <- format(Sys.time(), "%Y%m%d_%H%M%S")
cat("Start:", ts, "\n")

# ---------------------------
# 1) Products ? ADALIMUMAB NDCs
# ---------------------------
cat("Reading product file:", prod_ref, "\n")
prod <- as.data.table(read_dta(prod_ref))
prod <- pick_and_rename(prod, cands$ndc, std$ndc)
stopifnot(std$ndc %in% names(prod))

mol_col <- intersect(c("molecule_name","molecule","molecule_desc"), names(prod))
stopifnot(length(mol_col) > 0)
setnames(prod, mol_col[1], "molecule_name")

prod[, molecule_name := stri_trans_toupper(stri_trim_both(molecule_name))]
#adali_ndcs <- unique(prod[grepl("ADALIMUMAB", molecule_name, fixed = TRUE), ..std$ndc])
adali_ndcs <- unique(prod[grepl("adalimumab", molecule_name, ignore.case = TRUE), .(ndc = get(std$ndc))])

setnames(adali_ndcs, std$ndc, "ndc")
setkey(adali_ndcs, ndc)
cat("ADALIMUMAB NDCs:", nrow(adali_ndcs), "\n") # 119

# ---------------------------
# 2) Plan metadata
# ---------------------------
cat("Reading plan metadata:", plan_ref, "\n")
plan <- as.data.table(read_dta(plan_ref))
plan <- pick_and_rename(plan, cands$plan_id, std$plan_id)
plan <- pick_and_rename(plan, cands$model_type, std$model_type)
stopifnot(std$plan_id %in% names(plan))
if (!(std$model_type %in% names(plan))) plan[, (std$model_type) := NA_character_]

plan[, (std$plan_id)  := as.character(get(std$plan_id))]
plan[, (std$model_type):= stri_trans_toupper(stri_trim_both(as.character(get(std$model_type))))]

# attach plan_type
setkeyv(plan, std$model_type)
setkey(plan_map, model_type)
plan <- plan_map[plan, on = "model_type"]
plan[grepl("HIX", get(std$model_type), fixed = TRUE), plan_type := "Exchange"]
plan[is.na(plan_type) | plan_type == "", plan_type := "Other"]

setkeyv(plan, std$plan_id)
plan <- plan[, .(plan_id = get(std$plan_id), model_type = get(std$model_type), plan_type)]

# ---------------------------
# 3) Claims: read, normalize, filter to ADALIMUMAB, merge plan
# ---------------------------
read_claims <- function(p) {
  cat("  ->", p, "\n")
  dt <- as.data.table(read_dta(p))

  # rename to standardized names if present
  dt <- pick_and_rename(dt, cands$ndc,        std$ndc)
  dt <- pick_and_rename(dt, cands$plan_id,    std$plan_id)
  dt <- pick_and_rename(dt, cands$claim_id,   std$claim_id)
  dt <- pick_and_rename(dt, cands$rjct_grp,   std$rjct_grp)
  dt <- pick_and_rename(dt, cands$encnt_code, std$encnt_code)

  # keep just what we need
  keep <- intersect(names(dt), c(std$claim_id, std$ndc, std$plan_id, std$rjct_grp, std$encnt_code))
  dt <- dt[, ..keep]

  # types
  dt <- normalize_cols(dt, c(std$claim_id, std$ndc, std$plan_id))

  # filter to adalimumab by NDC
  if (!(std$ndc %in% names(dt))) return(data.table())  # no ndc col in this slice
  setkeyv(dt, std$ndc)
  dt <- adali_ndcs[dt, on = c(ndc = std$ndc), nomatch = 0L]

  # merge plan metadata
  if (std$plan_id %in% names(dt)) {
    setkeyv(dt, std$plan_id)
    dt <- plan[dt, on = c(plan_id = std$plan_id)]
  } else {
    dt[, c("model_type","plan_type") := .(NA_character_, "Other")]
  }

# optional: label rjct group (kept as numeric + label string)
  if (std$rjct_grp %in% names(dt)) {
    lvl <- c("Fill","Step edit","Prior auth","Not covered","Plan limit","Other")
    dt[, rjct_grp_lbl := fifelse(get(std$rjct_grp) %in% 0:5, lvl[get(std$rjct_grp)+1L], NA_character_)]
  }
  df[]
}

cat("Claims files found:", length(claim_files), "\n")
parts <- lapply(claim_files, read_claims)
claims_adali <- rbindlist(parts, use.names = TRUE, fill = TRUE)
cat("ADALIMUMAB claims rows:", nrow(claims_adali), "\n")


# ---------------------------
# 4) Save as Parquet (best for R/Arrow/Polars/Python)
# ---------------------------
out_parquet <- file.path(data_dir, "adalimumab_claims.parquet")
# Reorder a bit for convenience
ord <- intersect(c("claim_id","ndc","plan_id","model_type","plan_type","rjct_grp","rjct_grp_lbl","encnt_outcm_cd"), names(claims_adali))
setcolorder(claims_adali, c(ord, setdiff(names(claims_adali), ord)))

# Write compressed Parquet
write_parquet(claims_adali, out_parquet, compression = "zstd")
cat("Wrote Parquet:", out_parquet, "\n")
cat("Done.\n")

















