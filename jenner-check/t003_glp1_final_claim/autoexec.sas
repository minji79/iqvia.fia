/* autoexec for t003_glp1_final_claim
   Caps row scans during interactive demos. */
options obs=100;

/* The upstream script (glp1/07_final_claim.sas) selects, for each patient, the
   most recent claim on or before their discontinuation date, splitting the
   cohort by a patient-level discontinuation flag and pooling the two results.
   The live tables are the IQVIA FIA long claims file and the derived patient
   table on the JHU cluster; here we build small samples with the same keys
   (patient_id, svc_dt, disc_date, discontinuation) so the IN(subquery) filter,
   the descending sort, and the first.patient_id last-claim pick run as written. */
libname input "input";

/* Long claims: several dated rows per patient */
data input.rx18_24_glp1_long_v01;
  infile datalines dsd truncover;
  input patient_id svc_dt :yymmdd10. payer_type :$20.
        encnt_outcm_cd :$8. days_supply_cnt
        disc_date :yymmdd10. disc_at_6m disc_at_1y disc_at_2y;
  format svc_dt disc_date yymmdd10.;
  datalines;
2001,2022-01-15,Commercial,PD,30,2022-06-10,1,0,0
2001,2022-03-20,Commercial,PD,30,2022-06-10,1,0,0
2001,2022-06-10,Commercial,PD,30,2022-06-10,1,0,0
2001,2022-09-01,Commercial,RJ,30,2022-06-10,1,0,0
2002,2021-02-01,Medicare D: TM,PD,90,2021-11-05,0,1,0
2002,2021-08-15,Medicare D: TM,PD,90,2021-11-05,0,1,0
2002,2021-11-05,Medicare D: TM,PD,90,2021-11-05,0,1,0
2003,2020-05-01,Medicaid: MCO,PD,30,.,0,0,0
2003,2020-07-01,Medicaid: MCO,PD,30,.,0,0,0
2003,2021-01-01,Medicaid: MCO,PD,30,.,0,0,0
;
run;

/* Patient-level table with the discontinuation flag */
data input.patients_v1;
  infile datalines dsd truncover;
  input patient_id discontinuation;
  datalines;
2001,1
2002,1
2003,0
;
run;
