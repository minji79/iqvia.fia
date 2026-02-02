
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

/* add GLP1s indicators */
data plan.eric_claim;
    set plan.eric_claim;
    format glp1 $100.;
    if index(upcase(molecule_name), "DULAGLUTIDE") > 0 then glp1 = "DULAGLUTIDE"; /* ndc =49 */
    else if index(upcase(molecule_name), "EXENATIDE") > 0 then glp1 = "EXENATIDE";  
    else if index(upcase(molecule_name), "LIXISENATIDE") > 0 then glp1 = "LIXISENATIDE";  
    else if index(upcase(molecule_name), "LIRAGLUTIDE") > 0 then glp1 = "LIRAGLUTIDE";  
    else if index(upcase(molecule_name), "LIRAGLUTIDE (WEIGHT MANAGEMENT)") > 0 then glp1 = "LIRAGLUTIDE (WEIGHT MANAGEMENT)";  
    else if index(upcase(molecule_name), "SEMAGLUTIDE") > 0 then glp1 = "SEMAGLUTIDE";  
    else if index(upcase(molecule_name), "SEMAGLUTIDE (WEIGHT MANAGEMENT)") > 0 then glp1 = "SEMAGLUTIDE (WEIGHT MANAGEMENT)";  
    else if index(upcase(molecule_name), "TIRZEPATIDE") > 0 then glp1 = "TIRZEPATIDE";  
    else if index(upcase(molecule_name), "TIRZEPATIDE (WEIGHT MANAGEMENT)") > 0 then glp1 = "TIRZEPATIDE (WEIGHT MANAGEMENT)";  
    else glp1 = "NA";  
run;
proc freq data=plan.eric_claim; table glp1; run;
proc freq data=plan.eric_claim; table glp1*year; run;



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
    DULAGLUTIDE_count = 0;
    EXENATIDE_count = 0;
    LIXISENATIDE_count = 0;
    LIRAGLUTIDE_count = 0;
    LIRAGLUTIDE_obesity_count = 0;
    SEMAGLUTIDE_count = 0;
    SEMAGLUTIDE_obesity_count = 0;
    TIRZEPATIDE_count = 0;
    TIRZEPATIDE_obesity_count = 0;

  end;

  claim_count + 1;

  if study_drug_u = "IMATINIB" then IMATINIB_count + 1;
  if study_drug_u = "BUDESONIDE-FORMOTEROL" then BUDEFORMO_count + 1;
  if study_drug_u = "GLATIRAMER" then GLATIRAMER_count + 1;
  if study_drug_u = "CYCLOSPORIN" then CYCLOSPORIN_count + 1;
  if study_drug_u = "ADALIMUMAB" then ADALIMUMAB_count + 1;
  if study_drug_u = "INSULIN" then INSULIN_count + 1;
  if study_drug_u = "PEGFILGRASTIM" then PEGFILGRASTIM_count + 1;
  if study_drug_u = "DULAGLUTIDE" then DULAGLUTIDE_count + 1;
  if study_drug_u = "EXENATIDE" then EXENATIDE_count + 1;
  if study_drug_u = "LIXISENATIDE" then LIXISENATIDE_count + 1;
  if study_drug_u = "LIRAGLUTIDE" then LIRAGLUTIDE_count + 1;
  if study_drug_u = "LIRAGLUTIDE (WEIGHT MANAGEMENT)" then LIRAGLUTIDE_obesity_count + 1;
  if study_drug_u = "SEMAGLUTIDE" then SEMAGLUTIDE_count + 1;
  if study_drug_u = "SEMAGLUTIDE (WEIGHT MANAGEMENT)" then SEMAGLUTIDE_obesity_count + 1;
  if study_drug_u = "TIRZEPATIDE" then TIRZEPATIDE_count + 1;
  if study_drug_u = "TIRZEPATIDE (WEIGHT MANAGEMENT)" then TIRZEPATIDE_obesity_count + 1;

  if last.patient_id then do;
    last_date = svc_dt;    /* latest because sorted */
    output;
  end;

  format index_date last_date mmddyy10.;
run;

/* duration of enrollment */
/* set index date again */
data plan.eric_patient; set plan.eric_patient; drop index_date; run;
proc sort data=plan.eric_claim; by patient_id svc_dt; run;
data index_date; set plan.eric_claim; by patient_id; if first.patient_id; run;

/* merge with patient's wide dataset */
proc sql;
 create table plan.eric_patient as
 select distinct a.*, b.svc_dt as index_date
 from plan.eric_patient as a
 left join index_date as b 
 on a.patient_id = b.patient_id;
quit;
data plan.eric_patient; set plan.eric_patient; duration_month = (last_date - index_date) /30; run;
proc means data=plan.eric_patient n nmiss mean std median q1 q3; var duration_month; run;


/* drug users indicators */
%macro drug (drug=);
data plan.eric_patient; set plan.eric_patient; if &drug_count >0 then &drug_user =1; else &drug_user =0; run;
proc freq data=plan.eric_patient; table &drug_user; title "&drug"; run;

%mend drug;
%drug(drug=LIRAGLUTIDE_obesity);



%drug(drug=IMATINIB);
%drug(drug=BUDEFORMO);
%drug(drug=GLATIRAMER);
%drug(drug=CYCLOSPORIN);
%drug(drug=ADALIMUMAB);
%drug(drug=INSULIN);
%drug(drug=PEGFILGRASTIM);
%drug(drug=EXENATIDE);
%drug(drug=LIXISENATIDE);
%drug(drug=LIRAGLUTIDE);
%drug(drug=LIRAGLUTIDE_obesity);
%drug(drug=SEMAGLUTIDE);
%drug(drug=SEMAGLUTIDE_obesity);
%drug(drug=TIRZEPATIDE);
%drug(drug=TIRZEPATIDE_obesity);


proc print data=plan.eric_patient (obs=10); run;



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
        mean(gross_cost) as avg_gross_cost,
        std(gross_cost) as std_gross_cost,
        count(*) as n_claims,

        calculated std_gross_cost / sqrt(calculated n_claims) as se_gross_cost,    /* standard error */
        calculated avg_gross_cost - 1.96 * (calculated std_gross_cost / sqrt(calculated n_claims))
            as lcl_gross_cost,               /* lower 95% CI */
        calculated avg_gross_cost + 1.96 * (calculated std_gross_cost / sqrt(calculated n_claims))
            as ucl_gross_cost               /* upper 95% CI */
            
    from plan.eric_claim
    group by year, molecule_name
    order by year, molecule_name;
quit;
proc print data=plan.drug_year_spending (obs=10); run;

/* Yearly Top 10 spending drugs */
proc sort data=plan.drug_year_spending out=drug_sorted;
    by year descending total_gross_cost;
run;

data drug_ranked;
    set drug_sorted;
    by year;
    if first.year then rank = 0;
    rank + 1;
run;

data top10_drugs_by_year;
    set drug_ranked;
    where rank <= 10;
run;
proc print data=top10_drugs_by_year (obs=20); run;

/* to include all yearly data for the top 10 drugs */
proc freq data=top10_drugs_by_year; table molecule_name; run;

data drug_ranked_selected; set plan.drug_year_spending; if molecule_name in ("ADALIMUMAB","DULAGLUTIDE","RIVAROXABAN", 
  "APIXABAN","EMPAGLIFLOZIN", "INSULIN GLARGINE","INSULIN LISPRO", "SEMAGLUTIDE","SEMAGLUTIDE", "TIRZEPATIDE", "DAPAGLIFLOZIN PROPANEDIOL"); run;

/* main figure */
proc sgplot data=drug_ranked_selected;
    /* 95% CI ribbon */
    band x=year lower=lcl_gross_cost upper=ucl_gross_cost /
        group=molecule_name
        transparency=0.75
        legendlabel="95% CI";

    /* Line */
    series x=year y=total_gross_cost /
        group=molecule_name
        lineattrs=(thickness=2)
        legendlabel="Mean spending";

    /* Dots at each year */
    scatter x=year y=total_gross_cost /
        group=molecule_name
        markerattrs=(symbol=circlefilled size=7);

    xaxis label="Year" integer;
    yaxis label="Gross Cost ($)" grid;

    keylegend / position=topright across=1;
    title "Gross costs for the Top 10 spending drugs within the ERIC plan over time";
run;

/* use legend of the following results */
proc sgplot data=drug_ranked_selected;
    series x=year y=total_gross_cost / group=molecule_name;
run;

/* 2024 data */
proc print data=drug_ranked_selected; where year=2024; title "TOP 10 spending drugs in 2024"; run;

/* Tables for Yearly Top 10 spending drugs */
%macro yearly(year=);
data drug_&year; set plan.drug_year_spending; if year=&year; run;
proc sort data=drug_&year; by descending total_gross_cost; run;
proc print data=drug_&year (obs=10); title "top10 spending drugs in &year"; run;

%mend yearly;
%yearly(year=2025);
%yearly(year=2024);
%yearly(year=2023);
%yearly(year=2022);
%yearly(year=2021);
%yearly(year=2020);
%yearly(year=2019);
%yearly(year=2018);
%yearly(year=2017);

/*============================================================*
 | 4. patient level aggregation - for GLP1s and Adalimumab
 *============================================================*/
proc print data=plan.eric_claim (obs=10); var patient_id svc_dt; run;

proc print data=plan.eric_patient (obs=10); var patient_id svc_dt index_date last_date duration; run;


/* median number of months stay */
proc sort data=plan.eric_claim; by plan_id patient_id; run;


