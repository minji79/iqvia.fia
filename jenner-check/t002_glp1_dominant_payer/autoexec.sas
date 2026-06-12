/* autoexec for t002_glp1_dominant_payer
   Caps row scans during interactive demos. */
options obs=100;

/* The upstream script (glp1/03_dominant_plan_identification.sas) joins the
   long GLP-1 claims table to a patient/year payer-mapping table, then fills in
   a dominant_payer where the mapping was missing. The live tables come from
   the IQVIA FIA extract and Joe's plan-mapping file on the JHU cluster; here
   we build small samples with the same key columns so the LEFT JOIN, the
   missing()-based recode, and the FREQ all run as written. */
libname input "input";

/* Long GLP-1 claims: patient/year with an observed payer */
data input.rx18_24_glp1_long_v00;
  infile datalines dsd truncover;
  input patient_id year molecule_name :$32. payer_type :$20.
        payer_type_indicator :$20.;
  datalines;
1001,2019,SEMAGLUTIDE,Commercial,dominant_payer
1001,2020,SEMAGLUTIDE,Commercial,dominant_payer
1002,2019,TIRZEPATIDE,Medicare D: TM,dominant_payer
1002,2021,TIRZEPATIDE,Medicare D: TM,secondary_payer
1003,2020,LIRAGLUTIDE,Medicaid: MCO,dominant_payer
1004,2019,DULAGLUTIDE,Commercial,secondary_payer
1005,2022,SEMAGLUTIDE,Cash,dominant_payer
1006,2020,SEMAGLUTIDE,Commercial,dominant_payer
;
run;

/* Plan-mapping: only some patient/years have a mapped dominant_payer */
data input.joe_plan_mapping;
  infile datalines dsd truncover;
  input patient_id year dominant_payer :$24.;
  datalines;
1001,2019,Commercial
1001,2020,Commercial
1002,2019,Medicare Advantage
1003,2020,Medicaid
1006,2020,Commercial
;
run;
