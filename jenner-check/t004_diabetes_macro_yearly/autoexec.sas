/* autoexec for t004_diabetes_macro_yearly
   Caps row scans during interactive demos. */
options obs=100;

/* glp1/04_identify_diabetes.sas defines a %yearly macro that left-joins a
   per-patient index table to a year's RxFact claims, plus USC-code logic that
   keeps anti-diabetic molecules. The live RxFact and product tables live on
   the JHU cluster; here we stand up a small index table, two yearly RxFact
   samples, and a product reference so the macro and the USC filter run as
   authored. */
libname input "input";
libname biosim "input";

/* Per-patient index (one start_date per patient) */
data input.id;
  infile datalines dsd truncover;
  input patient_id start_date :yymmdd10.;
  format start_date yymmdd10.;
  datalines;
3001,2020-03-01
3002,2020-07-15
3003,2018-11-20
;
run;

/* Two yearly RxFact samples (patient_id, svc_dt, ndc, rjct_cd) */
data biosim.rxfact2020;
  infile datalines dsd truncover;
  input patient_id svc_dt :yymmdd10. ndc :$11. rjct_cd :$4.;
  format svc_dt yymmdd10.;
  datalines;
3001,2020-02-10,00002143380,
3001,2020-04-05,00002143380,00
3002,2020-06-01,00169413211,
3002,2020-08-20,00074433902,PA
3003,2020-01-15,00002771659,
;
run;

data biosim.rxfact2018;
  infile datalines dsd truncover;
  input patient_id svc_dt :yymmdd10. ndc :$11. rjct_cd :$4.;
  format svc_dt yymmdd10.;
  datalines;
3003,2018-10-01,00002143380,
3003,2018-12-10,00169413211,
3001,2018-05-05,00074433902,
;
run;

/* Product reference: ndc -> molecule / USC class */
data biosim.product;
  infile datalines dsd truncover;
  input product_ndc :$11. molecule_name :$32.
        usc_3 :$8. usc_3_description :$40.
        usc_5 :$8. usc_5_description :$40.;
  datalines;
00002143380,INSULIN GLARGINE,39200,ANTIDIABETICS INSULIN,39210,LONG ACTING INSULIN
00169413211,METFORMIN,39100,ANTIDIABETICS ORAL,39131,BIGUANIDES
00074433902,SEMAGLUTIDE,39100,ANTIDIABETICS ORAL,39252,GLP-1 AGONISTS
00002771659,EMPAGLIFLOZIN,39300,ANTIDIABETICS OTHER,39311,SGLT2 INHIBITORS
;
run;
