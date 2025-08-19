*----------------------------------------------*
* 0) SET WORKING DIRECTORY & DEFINE PATHS
*----------------------------------------------*
clear all
set more off
cd "/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/stata"

* Subfolders *
local data   "`c(pwd)'/data"
local out    "`c(pwd)'/out"
local errs   "`c(pwd)'/errs"
local figs   "`c(pwd)'/figures"
local tabs   "`c(pwd)'/tables"

* Raw/reference files *
local prod_ref      "/dcs07/hpm/data/iqvia_fia/ref/product.dta"
local plan_ref      "/dcs07/hpm/data/iqvia_fia/ref/plan.dta"
local patient_ref   "/dcs07/hpm/data/iqvia_fia/ref/patient.dta"
local provider_ref  "/dcs07/hpm/data/iqvia_fia/ref/provider.dta"

*******************************************************
* (1) Load Product File. Manipulate to Drug Of Interest. Save list of NDCs
*******************************************************
use "`prod_ref'" if strpos(molecule_name,"ADALIMUMAB"), clear
tab molecule_name, sort
keep product_ndc usc_3_description molecule_name drug_labeler_corp_name
tab molecule_name drug_labeler_corp_name
save "`data'/ADALIMUMAB_NDCs.dta", replace

*******************************************************
* (2) LOAD & COMBINE RAW CLAIMS FOR MULTIPLE YEARS: Many Ways to Do this.
*******************************************************

* Attempt A
* This is the most complete, but also the slowest, as it retains all variables in
* RXFACT. It takes the longest (by far)
* Note the every other year is fine, because each file contains the year before data too.
display c(current_time)
* Get all 4 big files (100GB each)
use "/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2018.dta", clear
append using "/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2020.dta"
append using "/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2022.dta"
rename daw_cd daw_cd_s
append using "/dcs07/hpm/data/iqvia_fia/full_raw/RxFact2024.dta"

* Merge with a variable that was missing in our first cut of this data: encnt_outcm_cd
merge 1:1 claim_id using "/dcs07/hpm/data/iqvia_fia/full_raw/LevyPDRJRV.dta", ///
    keepusing(encnt_outcm_cd) keep(3) gen(merge1)

* Merge and keep only claims for NDCs identified for ADALIMUMAB
rename ndc product_ndc
merge m:1 product_ndc using "`data'/ADALIMUMAB_NDCs.dta", keep(3) gen(merge2)
save "`data'/A_ADALIMUMAB_claims.dta", replace
drop merge*
display c(current_time)
* ~2:30 (2 Hours and 30 Minutes)

* Attempt B
* Here I start with a reduced dataset I have already made, it contains all claims,
* including the encnt_outcm_cd variable but way fewer variables (for efficiency)
display c(current_time)
use "/dcs07/hpm/data/iqvia_fia/reduced/RxFact_2018_2024_small.dta", clear
rename ndc product_ndc
merge m:1 product_ndc using "`data'/ADALIMUMAB_NDCs.dta", keep(3) gen(merge2)
save "`data'/B_ADALIMUMAB_claims.dta", replace
display c(current_time)
* 35 Minutes

* Attempt C
* Here I start with a random sample (0.5% of the data) of the larger dataset,
* when doing this, you could run in GUI for instance depending on how big of
* a random sample you take
display c(current_time)
use "/dcs07/hpm/data/iqvia_fia/reduced/RxFact_2018_2024_small.dta" if runiform()<0.005, clear
rename ndc product_ndc
merge m:1 product_ndc using "`data'/ADALIMUMAB_NDCs.dta", keep(3) gen(merge2)
save "`data'/C_ADALIMUMAB_claims.dta", replace
display c(current_time)
* 90 seconds

*******************************************************
* (3) Manipulate Claims. Improve Reject Reason (current best understanding)
*******************************************************
* Using B, but could also work with C here, in GUI to work on code.
* use "`data'/A_ADALIMUMAB_claims.dta", clear
use "`data'/B_ADALIMUMAB_claims.dta", clear
* use "`data'/C_ADALIMUMAB_claims.dta", clear

*. Classify rejection groups —*
gen byte rjct_grp = .
* Step edit (group 1) *
replace rjct_grp = 1 if inlist(rjct_cd, "88","608","088","0608")
* Prior auth (group 2) *
foreach code in 3N 3P 3S 3T 3W 03N 03P 03S 03T 03W ///
                3X 3Y 64 6Q 75 03X 03Y 064 06Q 075 80 EU EV MV PA 080 0EU 0EV 0MV 0PA {
    replace rjct_grp = 2 if rjct_cd == "`code'"
}
* Not covered (group 3) *
foreach code in 60 61 63 65 70 060 061 063 065 070 ///
                7Y 8A 8H 9Q 9R 9T 9Y BB MR 07Y 08A 08H 09Q 09R 09T 09Y 0BB 0MR {
    replace rjct_grp = 3 if rjct_cd == "`code'"
}
* Plan limit (group 4) *
replace rjct_grp = 4 if inlist(rjct_cd, "76","7X","AG","RN","076","07X","0AG","0RN")
* Fill (group 0) *
replace rjct_grp = 0 if inlist(rjct_cd, "","00","000")
* Anything else → non-formulary (group 5) *
replace rjct_grp = 5 if missing(rjct_grp)

tab rjct_grp encnt_outcm_cd

*******************************************************
* (4) Manipulate Claims. Add Plan Info
*******************************************************
* Could be keeping other variables here, but am choosing not to
merge m:1 plan_id using "`plan_ref'", ///
    keep(3) keepusing(model_type plan_name adjudicating_pbm_plan_name plan_name pay_type_description) nogenerate

gen str20 plan_type = ""
* Cash *
replace plan_type = "Cash" if model_type == "CASH"
* Commercial *
foreach m in CDHP COMBO HMO "HMO - HR" INDIVIDUAL ///
             PPO POS "TRAD IND" WRAP EMPLOYER ///
             "STATE EMP" "FED EMP" PBM "PBM BOB" "NON-HMO" ///
             NETWORK GROUP IPA STAFF EPO {
    replace plan_type = "Commercial" if model_type == "`m'"
}
* Medicare PDP (TM) *
foreach m in "MED PDPG" "MED PDP" "DE MMP" "EMP PDP" "EMP RPDP" {
    replace plan_type = "Medicare TM" if model_type == "`m'"
}
* Medicare Advantage *
foreach m in "MED ADVG" "MED ADV" "MED SNP" "MED SNPG" {
    replace plan_type = "Medicare ADV" if model_type == "`m'"
}
* Medicaid MCO *
foreach m in "MGD MEDI" "MEDICAID" {
    replace plan_type = "Medicaid MCO" if model_type == "`m'"
}
* Medicaid FFS *
replace plan_type = "Medicaid FFS" if model_type == "FFS MED"
* Exchange *
replace plan_type = "Exchange" if strpos(model_type, "HIX")
* Coupon/Voucher *
foreach m in "DISC CRD" "DISC MED" "SR CRD" {
    replace plan_type = "Discount Card" if model_type == "`m'"
}
foreach m in "VOUCHER" {
    replace plan_type = "Coupon/Voucher" if model_type == "`m'"
}
* Fallback to Other *
replace plan_type = "Other" if plan_type == ""

tab model_type plan_type

*******************************************************
* (5) Analysis File
*******************************************************
save "`data'/B_analytic_file.dta", replace
display c(current_time)

/*
*** Redo with A aka the full claims all variables
use "`data'/A_ADALIMUMAB_claims.dta", clear

*. Classify rejection groups —*
gen byte rjct_grp = .
* Step edit (group 1) *
replace rjct_grp = 1 if inlist(rjct_cd, "88","608","088","0608")
* Prior auth (group 2) *
foreach code in 3N 3P 3S 3T 3W 03N 03P 03S 03T 03W ///
                3X 3Y 64 6Q 75 03X 03Y 064 06Q 075 80 EU EV MV PA 080 0EU 0EV 0MV 0PA {
    replace rjct_grp = 2 if rjct_cd == "`code'"
}
* Not covered (group 3) *
foreach code in 60 61 63 65 70 060 061 063 065 070 ///
                7Y 8A 8H 9Q 9R 9T 9Y BB MR 07Y 08A 08H 09Q 09R 09T 09Y 0BB 0MR {
    replace rjct_grp = 3 if rjct_cd == "`code'"
}
* Plan limit (group 4) *
replace rjct_grp = 4 if inlist(rjct_cd, "76","7X","AG","RN","076","07X","0AG","0RN")
* Fill (group 0) *
replace rjct_grp = 0 if inlist(rjct_cd, "","00","000")
* Anything else → non-formulary (group 5) *
replace rjct_grp = 5 if missing(rjct_grp)

tab rjct_grp encnt_outcm_cd

* (4) Manipulate Claims. Add Plan Info
merge m:1 plan_id using "`plan_ref'", ///
    keep(3) keepusing(model_type plan_name adjudicating_pbm_plan_name plan_name pay_type_description) nogenerate

gen str20 plan_type = ""
replace plan_type = "Cash" if model_type == "CASH"
...
save "`data'/A_analytic_file.dta", replace
display c(current_time)
*/
