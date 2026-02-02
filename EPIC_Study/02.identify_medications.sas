
proc contents data=plan.eric_claim; run;
proc contents data=biosim.product; run;

/*============================================================*
 | 1. NDC level - identify drug of interest
 *============================================================*/

data plan.drug_ndc;
    set biosim.product;
    if index(upcase(molecule_name), "IMATINIB") > 0 then flag = 1; /* ndc =49 */
    else if index(upcase(molecule_name), "BUDESONIDE-FORMOTEROL FUMARATE DIHYDRATE") > 0 then flag = 1;  
    else if index(upcase(molecule_name), "BUDESONIDE-GLYCOPYRROLATE-FORMOTEROL FUMARATE") > 0 then flag = 1;  
    else if index(upcase(molecule_name), "GLATIRAMER") > 0 then flag = 1;  /* ndc 14 */
    else if index(upcase(molecule_name), "CYCLOSPORIN") > 0 then flag = 1;  /* ndc 76 */
    else if index(upcase(molecule_name), "ADALIMUMAB") > 0 then flag = 1;  /* ndc 119 */
    else if index(upcase(molecule_name), "INSULIN") > 0 and usc_5_description ne "DIABETIC ACCESSORIES" then flag = 1;  /* ndc 332 */
    else if index(upcase(molecule_name), "PEGFILGRASTIM") > 0 then flag = 1;  
    else flag=0; 
run;
data plan.drug_ndc; set plan.drug_ndc; if flag = 1; run; /* 623 NDCs */


data plan.eric_claim;
    set plan.eric_claim;
    format study_drug $100.;
    if index(upcase(molecule_name), "IMATINIB") > 0 then study_drug = "IMATINIB"; /* ndc =49 */
    else if index(upcase(molecule_name), "BUDESONIDE-FORMOTEROL FUMARATE DIHYDRATE") > 0 then study_drug = "BUDESONIDE-FORMOTEROL";  
    else if index(upcase(molecule_name), "BUDESONIDE-GLYCOPYRROLATE-FORMOTEROL FUMARATE") > 0 then study_drug = "BUDESONIDE-FORMOTEROL";  
    else if index(upcase(molecule_name), "GLATIRAMER") > 0 then study_drug = "GLATIRAMER";  
    else if index(upcase(molecule_name), "CYCLOSPORIN") > 0 then study_drug = "CYCLOSPORIN";  
    else if index(upcase(molecule_name), "ADALIMUMAB") > 0 then study_drug = "ADALIMUMAB";  
    else if index(upcase(molecule_name), "INSULIN") > 0 and usc_5_description ne "DIABETIC ACCESSORIES" then study_drug = "INSULIN";  
    else if index(upcase(molecule_name), "PEGFILGRASTIM") > 0 then study_drug = "PEGFILGRASTIM";  
    else study_drug = "NA";  
run;

proc freq data=plan.eric_claim; table study_drug; run;
proc freq data=plan.eric_claim; table study_drug*year; run;


/*============================================================*
 | 2. patient level aggregation - by molecule
 *============================================================*/

proc sort data=plan.eric_claim;
  by patient_id svc_dt;
run;

data plan.eric_patient;
  set plan.eric_claim;
  by patient_id;

  length study_drug_u $50;
  study_drug_u = upcase(strip(study_drug));

  if first.patient_id then do;
    claim_count = 0;
    IMATINIB_count = 0;
    BUDEFORMO_count = 0;
    GLATIRAMER_count = 0;
    CYCLOSPORIN_count = 0;
    ADALIMUMAB_count = 0;
    INSULIN_count = 0;
    PEGFILGRASTIM_count = 0;

    index_date = svc_dt;   /* earliest because sorted */
  end;

  claim_count + 1;

  if study_drug_u = "IMATINIB" then IMATINIB_count + 1;
  if study_drug_u = "BUDESONIDE-FORMOTEROL" then BUDEFORMO_count + 1;
  if study_drug_u = "GLATIRAMER" then GLATIRAMER_count + 1;
  if study_drug_u = "CYCLOSPORIN" then CYCLOSPORIN_count + 1;
  if study_drug_u = "ADALIMUMAB" then ADALIMUMAB_count + 1;
  if study_drug_u = "INSULIN" then INSULIN_count + 1;
  if study_drug_u = "PEGFILGRASTIM" then PEGFILGRASTIM_count + 1;

  if last.patient_id then do;
    last_date = svc_dt;    /* latest because sorted */
    output;
  end;

  format index_date last_date mmddyy10.;
run;

data plan.eric_patient; set plan.eric_patient; if IMATINIB_count >0 then IMATINIB_user =1; else IMATINIB_user =0; run;
data plan.eric_patient; set plan.eric_patient; if BUDEFORMO_count >0 then BUDEFORMO_user =1; else BUDEFORMO_user =0; run;
data plan.eric_patient; set plan.eric_patient; if GLATIRAMER_count >0 then GLATIRAMER_user =1; else GLATIRAMER_user =0; run;
data plan.eric_patient; set plan.eric_patient; if CYCLOSPORIN_count >0 then CYCLOSPORIN_user =1; else CYCLOSPORIN_user =0; run;
data plan.eric_patient; set plan.eric_patient; if ADALIMUMAB_count >0 then ADALIMUMAB_user =1; else ADALIMUMAB_user =0; run;
data plan.eric_patient; set plan.eric_patient; if INSULIN_count >0 then INSULIN_user =1; else INSULIN_user =0; run;
data plan.eric_patient; set plan.eric_patient; if PEGFILGRASTIM_count >0 then PEGFILGRASTIM_user =1; else PEGFILGRASTIM_user =0; run;
data plan.eric_patient; set plan.eric_patient; duration = last_date - index_date; run;

proc print data=plan.eric_patient (obs=10); run;

proc freq data=plan.eric_patient; table IMATINIB_user; run;
proc freq data=plan.eric_patient; table BUDEFORMO_user; run;
proc freq data=plan.eric_patient; table GLATIRAMER_user; run;
proc freq data=plan.eric_patient; table CYCLOSPORIN_user; run;
proc freq data=plan.eric_patient; table ADALIMUMAB_user; run;
proc freq data=plan.eric_patient; table INSULIN_user; run;
proc freq data=plan.eric_patient; table PEGFILGRASTIM_user; run;


/*============================================================*
 | 3. top 10 spending drugs 
 *============================================================*/
proc contents data=plan.eric_claim; run;

data plan.eric_claim; set plan.eric_claim; gross_cost = sum(pri_payer_pay_amt, sec_payer_pay_amt, final_opc_amt); run;

/* pooling spending by molecule */
proc summary data=plan.eric_claim nway;
    class year molecule_name;
    var gross_cost;
    output out=drug_year_spending
        sum = total_gross_cost
        mean = mean_gross_cost
        n = n_claims;
run;

proc sql;
    create table plan.drug_year_spending as
    select
        year,
        molecule_name,
        sum(gross_cost) as total_gross_cost,
        mean(gross_cost) as mean_gross_cost,
        count(*) as n_claims
    from plan.eric_claim
    group by year, molecule_name
    order by year, molecule_name;
quit;



/*============================================================*
 | 4. patient level aggregation - by plan
 *============================================================*/

/* median number of months stay */
proc sort data=plan.eric_claim; by plan_id patient_id; run;


