* remove invalid gender and age information;

/* ref: Descriptive_stats.do */
use "/dcs07/hpm/data/iqvia_fia/glp1_paper/data/Step1_GLP1Claims.dta", clear

* merge patient demographics into claims;
* Create sort order (row number) to retain the first entry per patient;
* medicare;
* 1. Create OOPC per 30-day supply;



/* 01_load_and_merge_glp1_v2.do */
* (1) LOAD & COMBINE RAW CLAIMS FOR MULTIPLE YEARS;
* STEPS 1â€“7: BUILD INDEXED CLAIMS DATASET;
merge m:1 product_ndc using "`prod_ref'", keep(3) keepusing(usc_3* usc_5* branded_generic molecule_name otc_indicator)
keep if usc_5==39251 | usc_5==18120 | usc_5==39259

* reject reason; 
replace rjct_grp = 1 if inlist(rjct_cd, "88","608","088","0608") //Step Edit
replace rjct_grp = 2 if inlist(rjct_cd, "03T","03W","3X","3Y","64","6Q","75","03X")
replace rjct_grp = 2 if inlist(rjct_cd, "PA","080","0EU","0EV","0MV","0PA") //PriorAuth
replace rjct_grp = 3 if inlist(rjct_cd, "061","063","065","070")
replace rjct_grp = 3 if inlist(rjct_cd, "9Y","BB","MR","07Y","08A","08H")
replace rjct_grp = 4 if inlist(rjct_cd, "76","7X","AG","RN","076","07X","0AG","0RN") //Plan Limit
replace rjct_grp = 5 if missing(rjct_grp) //NonFormulary Reject

bysort patient_id molecule_name svc_dt: egen formulary_reject = max(inlist(rjct_grp,1,2,3,4))
bysort patient_id molecule_name svc_dt: egen any_fill = max(rjct_grp==0)
bysort patient_id molecule_name svc_dt: egen nonformulary_reject = max(rjct_grp==5)
bysort patient_id molecule_name svc_dt: egen r1 = max(rjct_grp==1)
bysort patient_id molecule_name svc_dt: egen r3 = max(rjct_grp==3)
bysort patient_id molecule_name svc_dt: egen r2 = max(rjct_grp==2)
bysort patient_id molecule_name svc_dt: egen r4 = max(rjct_grp==4)


replace index_rjct_rsn = "Multiple" if (r1+r2+r3+r4)>1
replace index_rjct_rsn = "PriorAuth" if r2==1 & index_rjct_rsn==""
replace index_rjct_rsn = "PlanLimit" if r4==1 & index_rjct_rsn==""
gen str24 index_result = ""
replace index_result = "Reject, But Fill Same Day" if formulary_reject==1 & any_fill==1
replace index_result = "NonFormulary Reject" if nonformulary_reject==1 & index_result==""
replace index_rjct_rsn = "StepEdit" if r1==1 & index_rjct_rsn==""
replace index_rjct_rsn = "NotCovered" if r3==1 & index_rjct_rsn==""

replace index_result = "Reject" if formulary_reject==1 & any_fill==0
replace index_result = "Fill" if any_fill==1 & index_result==""

*we will see subsequent revcersals




 
