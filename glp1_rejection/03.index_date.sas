
data input.id_index;
    set input.rx17_25_glp1_long;        
    if encnt_outcm_cd = "PD" then paid_priority = 2;  
    else if encnt_outcm_cd = "RV" then paid_priority = 1;  
    else paid_priority = 0;
run;
proc sort data=input.id_index; by patient_id svc_dt descending paid_priority;  run;

data input.id_index;
    set input.id_index;
    by patient_id svc_dt;
    if first.patient_id then output;
    drop paid_priority;
run; 

data input.id_index; set input.id_index (rename=(svc_dt=index_date)); run;

/*============================================================*
 | 1. index date claim
 *============================================================*/

data input.id_index;
    set input.rx17_25_glp1_long;        
    if encnt_outcm_cd = "PD" then paid_priority = 2;  
    else if encnt_outcm_cd = "RV" then paid_priority = 1;  
    else paid_priority = 0;
run;
proc sort data=id_index; by patient_id svc_dt descending paid_priority;  run;

data input.id_index;
    /* First 'set' statement gets the earliest date for the patient */
    set input.id_index;
    by patient_id svc_dt;
    
    /* Retain the very first date found for each patient */
    retain first_date;
    if first.patient_id then index_date = svc_dt;
    
    /* Only output if the current row's date matches the first_date */
    if svc_dt = index_date;
    
    drop paid_priority;
run; /* 925056 individuals */
proc print data=input.id_index (obs=10); run;

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
data long; set input.rx17_25_glp1_long; if cohort in ("rejected at index date","reversed at index date"); run;   
data long; set long; if encnt_outcm_cd = "PD"; run;
proc sort data=long; by patient_id svc_dt; run;

data long; set long; by patient_id; if first.patient_id; run;
proc print data= long (obs=10); var patient_id svc_dt cohort; run;

proc sql;
    create table input.id_index as
    select a.*, b.svc_dt as first_filled_date
    from input.id_index as a
    left join long as b
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
