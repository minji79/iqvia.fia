/*============================================================*
 | Adapted from glp1/04_identify_diabetes.sas.
 | Exercises the repo's %yearly macro (per-year LEFT JOIN of the
 | index table to a RxFact extract), then the USC-code logic that
 | merges molecule classes and keeps anti-diabetic claims. Both the
 | macro body and the USC filtering are kept as authored.
 *============================================================*/

/* the per-year merge macro, verbatim from the source */
%macro yearly(year=, refer=);
proc sql;
  create table rx_&year._diabetes_med as
  select distinct a.*, b.svc_dt, b.ndc, b.rjct_cd
  from input.id as a
  left join &refer as b
  on a.patient_id = b.patient_id;
quit;
%mend yearly;

%yearly(year=20, refer=biosim.rxfact2020);
%yearly(year=18, refer=biosim.rxfact2018);

* pool the per-year results;
data input.rx_all_med; set rx_20_diabetes_med rx_18_diabetes_med; run;
proc sort data=input.rx_all_med nodupkey; by patient_id svc_dt; run;

* merge with molecule_name, usc_3, usc_5;
proc sql;
  create table input.rx_all_med as
  select distinct a.*, b.molecule_name, b.usc_3, b.usc_3_description, b.usc_5, b.usc_5_description
  from input.rx_all_med as a
  left join biosim.product as b
  on a.ndc = b.product_ndc;
quit;

/* using usc 3 level to form anti-diabetes medications */
data rx_diabetes_med; set input.rx_all_med; if usc_3 in ('39100', '39200', '39300'); run;

/* exclude GLP1s using usc_5 */
data input.rx_diabetes_med; set rx_diabetes_med; if usc_5 in ('39110','39121','39122','39123','39124','39131','39133','39134','39135','39210','39221','39222','39231','39233','39241',
'39252','39261','39262','39269','39271','39272','39281','39290','39311','39312','39313','39319'); run;

proc sort data=input.rx_diabetes_med; by patient_id svc_dt; run;
proc print data=input.rx_diabetes_med; var patient_id svc_dt ndc molecule_name usc_3 usc_5 rjct_cd; run;
proc freq data=input.rx_diabetes_med; table molecule_name; run;
