



/*============================================================*
 | 1. index date claim
 *============================================================*/

data input.id_index; set input.id_index (rename=(svc_dt=index_svc_dt)); run;
data input.id_index; set input.id_index (rename=(index_date=index_rx_dt)); run;
proc contents data=input.id_index; run;






* indicator ; 
proc freq data=input.id_index; table encnt_outcm_cd; run;
data input.id_index; set input.id_index; length cohort $100.; 
  if encnt_outcm_cd = "PD" then cohort ="filled at index date"; 
  else if encnt_outcm_cd = "RJ" then cohort ="rejected at index date"; 
  else if encnt_outcm_cd = "RV" then cohort ="reversed at index date"; 
  else cohort =""; 
run;
proc freq data=input.id_index; table cohort; run;

/*============================================================*
 | 2. keep all rows on the index date
 *============================================================*/

proc sql;
    create table allrows_index_date as
    select a.*
    from input.rx17_25_glp1_long as a
    inner join input.id_index as b
    on a.patient_id = b.patient_id 
       and a.svc_dt = b.index_date;
quit;
proc print data=allrows_index_date (obs=10); var patient_id svc_dt encnt_outcm_cd molecule_name; run;


/*============================================================*
 | 3. grouping based on the filled claim after initial rejection/ reverse
 *============================================================*/
 
* merge with the entire cohort data; 
proc sql;
    create table input.rx17_25_glp1_long as
    select a.*, b.cohort, b.index_date
    from input.rx17_25_glp1_long as a
    left join input.id_index as b
    on a.patient_id = b.patient_id;
quit;

* remain cohort who failed to fill at the index date; 
data input.first_filled_after_RJRV; set input.rx17_25_glp1_long; if cohort in ("rejected at index date","reversed at index date"); run;   
data input.first_filled_after_RJRV; set input.first_filled_after_RJRV; if encnt_outcm_cd = "PD"; run;
data input.first_filled_after_RJRV; set input.first_filled_after_RJRV; oop_30days = final_opc_amt / days_supply_cnt *30; run;
proc sort data=input.first_filled_after_RJRV; by patient_id svc_dt; run;

data input.first_filled_after_RJRV; set input.first_filled_after_RJRV; by patient_id; if first.patient_id; run;
proc print data= input.first_filled_after_RJRV (obs=10); var patient_id svc_dt cohort; run;

proc sql;
    create table input.id_index as
    select a.*, b.svc_dt as first_filled_date, b.molecule_name as first_filled_molecule, b.dominant_payer as first_filled_payer, 
    b.cash as first_filled_cash, b.coupon as first_filled_coupon, b.discount_card as first_filled_discount_card, b.oop_30days as first_filled_oop_30days
    from input.id_index as a
    left join input.first_filled_after_RJRV as b
    on a.patient_id = b.patient_id;
quit;

data input.id_index;
    set input.id_index;
    if missing(first_filled_date) and cohort = "filled at index date" then do;
        first_filled_date = index_date; 
    end;

    /* If they were rejected/reversed, ensure the date remains missing */
    else if missing(first_filled_date) and cohort in ("rejected at index date", "reversed at index date") then do;
        first_filled_date = .; 
    end;
run;

data input.id_index; set input.id_index; length cohort2 $100.; 
  
  if not missing(first_filled_date) then gap = first_filled_date - index_date; 
    else gap = .;
    
  if cohort = "rejected at index date" and not missing(first_filled_date) and gap < 90 then cohort2 = "filled after RJ in 90days"; 
  else if cohort = "reversed at index date" and not missing(first_filled_date) and gap < 90 then cohort2 = "filled after RV in 90days"; 
  else if cohort = "filled at index date" then cohort2 = cohort; 
  else if cohort in ("rejected at index date", "reversed at index date") and missing(first_filled_date) then cohort2 = "never filled";
  else if not missing(gap) and gap >= 90 then cohort2 = "filled after 90 days"; 
  else cohort2 = "other/unclassified";
run;

data input.id_index; set input.id_index; length cohort3 $100.; 
  if cohort2 in ("filled after 90 days","never filled") then cohort3 = "never filled or filled after 90 days";
  else cohort3 = cohort2; 
run;

proc freq data=input.id_index; table cohort3; run;
