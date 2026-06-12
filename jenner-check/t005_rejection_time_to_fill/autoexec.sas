/* autoexec for t005_rejection_time_to_fill
   Caps row scans during interactive demos. */
options obs=100;

/* glp1_rejection/05.analysis.sas computes rx_to_index_days (index_date minus
   rx_written_dt) and summarizes the time-to-fill distribution: PROC MEANS
   (n/median/q1/q3/min/max), a PROC SQL CASE bucketing into <=6 / 7-30 / >30
   days, and a PROC UNIVARIATE histogram. The live id_index table is built
   from the IQVIA FIA RxFact extract on the JHU cluster; here we supply a small
   id_index sample with the same columns so the derivation and summaries run as
   authored. */
libname input "input";

data input.id_index;
  infile datalines dsd truncover;
  input patient_id rx_written_dt :yymmdd10. index_date :yymmdd10.
        cohort4 :$32.;
  format rx_written_dt index_date yymmdd10.;
  datalines;
4001,2022-01-10,2022-01-12,filled after RV/RJ in 90days
4002,2022-02-01,2022-02-04,filled after RV/RJ in 90days
4003,2022-03-15,2022-03-30,filled after RV/RJ in 90days
4004,2022-04-01,2022-04-25,filled after RV/RJ in 90days
4005,2022-05-05,2022-06-20,filled after RV/RJ in 90days
4006,2022-06-01,2022-06-05,filled after RV/RJ in 90days
4007,2022-07-10,2022-07-11,filled at index date
4008,2022-08-01,2022-09-15,filled after RV/RJ in 90days
4009,2022-09-01,2022-09-09,filled after RV/RJ in 90days
4010,2022-10-01,2022-11-20,filled after RV/RJ in 90days
;
run;
