
libname planlist "/dcs07/hpm/data/iqvia_fia/glp1_disc/plan_coverage";   /* my own directory */

/************************************************************************************
	1.   All Plans (N=14734)
************************************************************************************/
* all plan_id;
proc print data=biosim.rxfact2024 (obs=10); run;
proc contents data=biosim.plan; run; /* 14734 distinct plans */


/************************************************************************************
	2.  Plan covering GLP1 (N=9855)
************************************************************************************/
* merge the plan_id;
data plan_id; set input.rx18_24_glp1_long_v01; keep plan_id plan_type; run;
proc sort data=plan_id nodupkey; by _all_; run;  /* 23277839 -> 40917 obs */

* distinct plan_id;
proc sql;
  select count(distinct(plan_id)) as plan_number
  from plan_id;
quit; /* 9855 plans covering glp1 */

/*
data plan_id; set input.rx18_24_glp1_long_v01; keep plan_id plan_type year; if molecule_name in ("SEMAGLUTIDE (WEIGHT MANAGEMENT)", "SEMAGLUTIDE", "TIRZEPATIDE (WEIGHT MANAGEMENT)", "TIRZEPATIDE"); run;
proc sort data=plan_id nodupkey; by _all_; run;  /* 23277839 -> 32930 obs */

* distinct plan_id;
proc sql;
  select count(distinct(plan_id)) as plan_number
  from plan_id;
quit; /* 8858 plans covering glp1 */
*/


/************************************************************************************
	3.  Plan list up (N=9855)
************************************************************************************/
%macro yearly(year=);
data rx_&year._glp1;
  set input.rx_&year._glp1;
  
  PD = (encnt_outcm_cd_='PD'); 
  RV = (encnt_outcm_cd='RV'); 
  RJ_Step = (encnt_outcm_cd='RJ' and rjct_grp=1); 
  RJ_PrAu = (encnt_outcm_cd='RJ' and rjct_grp=2); 
  RJ_NtCv = (encnt_outcm_cd='RJ' and rjct_grp=3); 
  RJ_PlLm = (encnt_outcm_cd='RJ' and rjct_grp=4); 
  RJ_NotForm = (encnt_outcm_cd='RJ' and rjct_grp=5); 

run;

%mend yearly;
%yearly(year=24); /* 8299345 obs, with 50 variables */
%yearly(year=23); /* 6273028 obs */
%yearly(year=22); /* 3287046 obs */
%yearly(year=21); /* 2189023 obs */
%yearly(year=20); /* 1754725 obs */
%yearly(year=19); /* 1453451 obs */
%yearly(year=18); /* 1176157 obs */


%macro yearly(year=);
proc sql; 
  create table rx_&year._plan as
  select distinct a.*,
         &year as year,
         sum(case when b.encnt_outcm_cd = "PD" then 1 else 0 end) as any_glp1_PD, 
         sum(case when b.molecule_name = "SEMAGLUTIDE (WEIGHT MANAGEMENT)" and b.encnt_outcm_cd = "PD" then 1 else 0 end) as semaglutide_weight_PD, 
         sum(case when b.molecule_name = "SEMAGLUTIDE" and b.encnt_outcm_cd = "PD" then 1 else 0 end) as semaglutide_t2db_PD, 
         sum(case when b.molecule_name = "TIRZEPATIDE (WEIGHT MANAGEMENT)" and b.encnt_outcm_cd = "PD" then 1 else 0 end) as tirzepatide_weight_PD, 
         sum(case when b.molecule_name = "TIRZEPATIDE" and b.encnt_outcm_cd = "PD" then 1 else 0 end) as tirzepatide_t2db_PD, 

         sum(case when b.encnt_outcm_cd = "RJ" then 1 else 0 end) as any_glp1_RJ, 
         sum(case when b.molecule_name = "SEMAGLUTIDE (WEIGHT MANAGEMENT)" and b.encnt_outcm_cd = "RJ" then 1 else 0 end) as semaglutide_weight_RJ, 
         sum(case when b.molecule_name = "SEMAGLUTIDE" and b.encnt_outcm_cd = "RJ" then 1 else 0 end) as semaglutide_t2db_RJ, 
         sum(case when b.molecule_name = "TIRZEPATIDE (WEIGHT MANAGEMENT)" and b.encnt_outcm_cd = "RJ" then 1 else 0 end) as tirzepatide_weight_RJ, 
         sum(case when b.molecule_name = "TIRZEPATIDE" and b.encnt_outcm_cd = "RJ" then 1 else 0 end) as tirzepatide_t2db_RJ, 

         sum(case when b.encnt_outcm_cd = "RJ" and b.RJ_NtCv = 1 then 1 else 0 end) as any_glp1_RJ_NtCv,
         sum(case when b.molecule_name = "SEMAGLUTIDE (WEIGHT MANAGEMENT)" and b.RJ_NtCv = 1 then 1 else 0 end) as semaglutide_weight_RJ_NtCv,
         sum(case when b.molecule_name = "SEMAGLUTIDE" and b.RJ_NtCv = 1 then 1 else 0 end) as semaglutide_t2db_RJ_NtCv,
         sum(case when b.molecule_name = "TIRZEPATIDE (WEIGHT MANAGEMENT)" and b.RJ_NtCv = 1 then 1 else 0 end) as tirzepatide_weight_RJ_NtCv,
         sum(case when b.molecule_name = "TIRZEPATIDE" and b.RJ_NtCv = 1 then 1 else 0 end) as tirzepatide_t2db_RJ_NtCv,

         sum(case when b.encnt_outcm_cd = "RJ" and b.RJ_PrAu = 1 then 1 else 0 end) as any_glp1_RJ_PrAu,
         sum(case when b.molecule_name = "SEMAGLUTIDE (WEIGHT MANAGEMENT)" and b.RJ_PrAu = 1 then 1 else 0 end) as semaglutide_weight_RJ_PrAu,
         sum(case when b.molecule_name = "SEMAGLUTIDE" and b.RJ_PrAu = 1 then 1 else 0 end) as semaglutide_t2db_RJ_PrAu,
         sum(case when b.molecule_name = "TIRZEPATIDE (WEIGHT MANAGEMENT)" and b.RJ_PrAu = 1 then 1 else 0 end) as tirzepatide_weight_RJ_PrAu,
         sum(case when b.molecule_name = "TIRZEPATIDE" and b.RJ_PrAu = 1 then 1 else 0 end) as tirzepatide_t2db_RJ_PrAu,

         sum(case when b.encnt_outcm_cd = "RJ" and b.RJ_Step = 1 then 1 else 0 end) as any_glp1_RJ_Step,
         sum(case when b.molecule_name = "SEMAGLUTIDE (WEIGHT MANAGEMENT)" and b.RJ_Step = 1 then 1 else 0 end) as semaglutide_weight_RJ_Step,
         sum(case when b.molecule_name = "SEMAGLUTIDE" and b.RJ_Step = 1 then 1 else 0 end) as semaglutide_t2db_RJ_Step,
         sum(case when b.molecule_name = "TIRZEPATIDE (WEIGHT MANAGEMENT)" and b.RJ_Step = 1 then 1 else 0 end) as tirzepatide_weight_RJ_Step, 
         sum(case when b.molecule_name = "TIRZEPATIDE" and b.RJ_Step = 1 then 1 else 0 end) as tirzepatide_t2db_RJ_Step,

         sum(case when b.encnt_outcm_cd = "RJ" and b.RJ_PlLm = 1 then 1 else 0 end) as any_glp1_RJ_QLim,
         sum(case when b.molecule_name = "SEMAGLUTIDE (WEIGHT MANAGEMENT)" and b.RJ_PlLm = 1 then 1 else 0 end) as semaglutide_weight_RJ_QLim,
         sum(case when b.molecule_name = "SEMAGLUTIDE" and b.RJ_PlLm = 1 then 1 else 0 end) as semaglutide_t2db_RJ_QLim,
         sum(case when b.molecule_name = "TIRZEPATIDE (WEIGHT MANAGEMENT)" and b.RJ_PlLm = 1 then 1 else 0 end) as tirzepatide_weight_RJ_QLim,
         sum(case when b.molecule_name = "TIRZEPATIDE" and b.RJ_PlLm= 1 then 1 else 0 end) as tirzepatide_t2db_RJ_QLim
  
  from plan_id as a 
  left join rx_&year._glp1 as b
  on a.plan_id = b.plan_id
  group by a.plan_id;
quit;

%mend yearly;
%yearly(year=24);
%yearly(year=23);
%yearly(year=22);
%yearly(year=21);
%yearly(year=20);
%yearly(year=19);
%yearly(year=18);

data planlist.glp1_plan; set rx_24_plan rx_23_plan rx_22_plan rx_21_plan rx_20_plan rx_19_plan rx_18_plan; run; /* 68992 obs */
proc sort data=planlist.glp1_plan; by plan_id year; run;

proc print data=planlist.glp1_plan (obs=30); run;

/************************************************************************************
	4. indicator for Coverage estimating
      - denominator = 0 -> null
      - numerator = 0 (denominator != 0) -> 0
************************************************************************************/
data planlist.glp1_plan; set planlist.glp1_plan;
  semaglutide_weight_p_reject = semaglutide_weight_RJ / (semaglutide_weight_PD + semaglutide_weight_RJ);
  semaglutide_weight_p_reject_NC = semaglutide_weight_RJ_NtCv / semaglutide_weight_RJ;
  semaglutide_weight_p_reject_PA = semaglutide_weight_RJ_PrAu / semaglutide_weight_RJ;
  semaglutide_weight_p_reject_ST = semaglutide_weight_RJ_Step / semaglutide_weight_RJ;
  semaglutide_weight_p_reject_QL = semaglutide_weight_RJ_QLim / semaglutide_weight_RJ;

  semaglutide_t2db_p_reject = semaglutide_t2db_RJ / (semaglutide_t2db_PD + semaglutide_t2db_RJ);
  semaglutide_t2db_p_reject_NC = semaglutide_t2db_RJ_NtCv / semaglutide_t2db_RJ;
  semaglutide_t2db_p_reject_PA = semaglutide_t2db_RJ_PrAu / semaglutide_t2db_RJ;
  semaglutide_t2db_p_reject_ST = semaglutide_t2db_RJ_Step / semaglutide_t2db_RJ;
  semaglutide_t2db_p_reject_QL = semaglutide_t2db_RJ_QLim / semaglutide_t2db_RJ;

  tirzepatide_weight_p_reject = tirzepatide_weight_RJ / (tirzepatide_weight_PD + tirzepatide_weight_RJ);
  tirzepatide_weight_p_reject_NC = tirzepatide_weight_RJ_NtCv / tirzepatide_weight_RJ;
  tirzepatide_weight_p_reject_PA = tirzepatide_weight_RJ_PrAu / tirzepatide_weight_RJ;
  tirzepatide_weight_p_reject_ST = tirzepatide_weight_RJ_Step / tirzepatide_weight_RJ;
  tirzepatide_weight_p_reject_QL = tirzepatide_weight_RJ_QLim / tirzepatide_weight_RJ;

  tirzepatide_t2db_p_reject = tirzepatide_t2db_RJ / (tirzepatide_t2db_PD + tirzepatide_t2db_RJ);
  tirzepatide_t2db_p_reject_NC = tirzepatide_t2db_RJ_NtCv / tirzepatide_t2db_RJ;
  tirzepatide_t2db_p_reject_PA = tirzepatide_t2db_RJ_PrAu / tirzepatide_t2db_RJ;
  tirzepatide_t2db_p_reject_ST = tirzepatide_t2db_RJ_Step / tirzepatide_t2db_RJ;
  tirzepatide_t2db_p_reject_QL = tirzepatide_t2db_RJ_QLim / tirzepatide_t2db_RJ;
run;


* semaglutide_weight_RJ_reason;
data glp1_plan;
  set planlist.glp1_plan;

  if missing(semaglutide_weight_p_reject) then semaglutide_weight_covered = .; else semaglutide_weight_covered = (semaglutide_weight_p_reject < 0.5);
  if missing(semaglutide_t2db_p_reject) then semaglutide_t2db_covered = .; else semaglutide_t2db_covered = (semaglutide_t2db_p_reject < 0.5);
  if missing(tirzepatide_weight_p_reject) then tirzepatide_weight_covered = .; else tirzepatide_weight_covered = (tirzepatide_weight_p_reject < 0.5);
  if missing(tirzepatide_t2db_p_reject) then tirzepatide_t2db_covered = .; else tirzepatide_t2db_covered = (tirzepatide_t2db_p_reject < 0.5);
  
  length semaglutide_weight_RJ_reason $4;   /* last 4 chars */

  array rj_vars[4] semaglutide_weight_RJ_NtCv 
                    semaglutide_weight_RJ_PrAu 
                    semaglutide_weight_RJ_Step 
                    semaglutide_weight_RJ_QLim;

  array rj_names[4] $20 _temporary_ ('NtCv' 'PrAu' 'Step' 'QLim');

  max_val = .;
  max_idx = .;

  do i = 1 to dim(rj_vars);
      if missing(max_val) or rj_vars[i] > max_val then do;
          max_val = rj_vars[i];
          max_idx = i;
      end;
  end;

  if not missing(max_idx) then semaglutide_weight_RJ_reason = rj_names[max_idx];
  else semaglutide_weight_RJ_reason = "";

  drop i max_val max_idx;
run;

proc print data=glp1_plan (obs=50); var plan_id year semaglutide_weight_PD semaglutide_weight_RJ semaglutide_weight_RJ_NtCv semaglutide_weight_RJ_PrAu
  semaglutide_weight_p_reject semaglutide_weight_p_reject_NC semaglutide_weight_p_reject_PA semaglutide_weight_covered semaglutide_weight_RJ_reason; run;

  
* semaglutide_t2db_RJ_reason;
data glp1_plan;
  set glp1_plan;
  length semaglutide_t2db_RJ_reason $4;   /* last 4 chars */

  array rj_vars[4] semaglutide_t2db_RJ_NtCv 
                    semaglutide_t2db_RJ_PrAu 
                    semaglutide_t2db_RJ_Step 
                    semaglutide_t2db_RJ_QLim;

  array rj_names[4] $20 _temporary_ ('NtCv' 'PrAu' 'Step' 'QLim');

  max_val = .;
  max_idx = .;

  do i = 1 to dim(rj_vars);
      if missing(max_val) or rj_vars[i] > max_val then do;
          max_val = rj_vars[i];
          max_idx = i;
      end;
  end;

  if not missing(max_idx) then semaglutide_t2db_RJ_reason = rj_names[max_idx];
  else semaglutide_t2db_RJ_reason = "";

  drop i max_val max_idx;
run;


* tirzepatide_weight_RJ_reason;
data glp1_plan;
  set glp1_plan;
  length tirzepatide_weight_RJ_reason $4;   /* last 4 chars */

  array rj_vars[4] tirzepatide_weight_RJ_NtCv 
                    tirzepatide_weight_RJ_PrAu 
                    tirzepatide_weight_RJ_Step 
                    tirzepatide_weight_RJ_QLim;

  array rj_names[4] $20 _temporary_ ('NtCv' 'PrAu' 'Step' 'QLim');

  max_val = .;
  max_idx = .;

  do i = 1 to dim(rj_vars);
      if missing(max_val) or rj_vars[i] > max_val then do;
          max_val = rj_vars[i];
          max_idx = i;
      end;
  end;

  if not missing(max_idx) then tirzepatide_weight_RJ_reason = rj_names[max_idx];
  else tirzepatide_weight_RJ_reason = "";

  drop i max_val max_idx;
run;

* tirzepatide_t2db_RJ_reason;
data glp1_plan;
  set glp1_plan;
  length tirzepatide_t2db_RJ_reason $4;   /* last 4 chars */

  array rj_vars[4] tirzepatide_t2db_RJ_NtCv 
                    tirzepatide_t2db_RJ_PrAu 
                    tirzepatide_t2db_RJ_Step 
                    tirzepatide_t2db_RJ_QLim;

  array rj_names[4] $20 _temporary_ ('NtCv' 'PrAu' 'Step' 'QLim');

  max_val = .;
  max_idx = .;

  do i = 1 to dim(rj_vars);
      if missing(max_val) or rj_vars[i] > max_val then do;
          max_val = rj_vars[i];
          max_idx = i;
      end;
  end;

  if not missing(max_idx) then tirzepatide_t2db_RJ_reason = rj_names[max_idx];
  else tirzepatide_t2db_RJ_reason = "";

  drop i max_val max_idx;
run;

data planlist.glp1_plan; set glp1_plan; run;

proc print data=glp1_plan (obs=50); var plan_id year 
semaglutide_weight_covered semaglutide_weight_RJ_reason semaglutide_t2db_covered semaglutide_t2db_RJ_reason
  tirzepatide_weight_covered tirzepatide_weight_RJ_reason tirzepatide_t2db_covered tirzepatide_t2db_RJ_reason; where plan_id in (1,6,100); run;

  

proc freq data=input.rx18_24_glp1_long_v01; table molecule_name; run;

