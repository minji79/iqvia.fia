#!/usr/bin/env Rscript

## =============================
## Setup & libraries
## =============================
suppressPackageStartupMessages({
  library(data.table)
  library(haven)
  library(arrow)
})

`%||%` <- function(a, b) if (is.null(a)) b else a
ts_now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")
save_parquet <- function(dt, path, compression = "zstd") {
  write_parquet(as.data.frame(dt), path, compression = compression)
  cat("[", ts_now(), "] Wrote:", path, "\n")
}

## =============================
## Paths (same as in script 1)
## =============================
setwd("/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r")
data_dir <- file.path(getwd(), "data")
plan_ref <- "/dcs07/hpm/data/iqvia_fia/ref/plan.dta"

## =============================
## (3) Rejection groups on Attempt B output
## =============================
cat("[", ts_now(), "] Step 3: Rejection group classification…\n")
B <- as.data.table(read_parquet(file.path(data_dir, "B_ADALIMUMAB_claims.parquet")))

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
## (4) Plan merge + plan_type mapping
## =============================
cat("[", ts_now(), "] Step 4: Plan merge and plan_type…\n")
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

# Medicaid MCO / FFS
B[model_type %in% c("MGD MEDI","MEDICAID"), plan_type := "Medicaid MCO"]
B[model_type == "FFS MED", plan_type := "Medicaid FFS"]

# Exchange (HIX substring)
B[grepl("HIX", model_type %||% "", fixed = TRUE), plan_type := "Exchange"]

# Coupon/Voucher & Discount Card
B[model_type %in% c("DISC CRD","DISC MED","SR CRD"), plan_type := "Discount Card"]
B[model_type %in% "VOUCHER", plan_type := "Coupon/Voucher"]

# Fallback
B[plan_type == "" | is.na(plan_type), plan_type := "Other"]

## =============================
## (5) Analysis parquet
## =============================
cat("[", ts_now(), "] Step 5: Save analytic parquet…\n")
save_parquet(B, file.path(data_dir, "B_analytic_file.parquet"))
rm(B, plan); gc()

cat("[", ts_now(), "] Done (post-processing).\n")
