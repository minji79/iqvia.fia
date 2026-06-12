/* autoexec for t001_glp1_area_plot
   Caps row scans during interactive demos. */
options obs=100;

/* The upstream script reads input.adalimumab_claim_v0, a long table of one
   row per claim with a YYYYMM month_id and a drug category. The live study
   sources it from the IQVIA FIA RxFact extract on the JHU cluster; here we
   stand up a small in-memory libname with a representative shape so the
   aggregation, date conversion, cumulative-stacking, and BAND plot all run
   exactly as written. */
libname input "input";

data input.adalimumab_claim_v0;
  infile datalines dsd truncover;
  input month_id category :$24.;
  datalines;
202301,Originator
202301,Originator
202301,Biosimilar (low WAC)
202302,Originator
202302,Biosimilar (low WAC)
202302,Biosimilar (high WAC)
202303,Originator
202303,Biosimilar (low WAC)
202303,Biosimilar (low WAC)
202303,Biosimilar (high WAC)
202304,Originator
202304,Biosimilar (low WAC)
202304,Biosimilar (low WAC)
202304,Biosimilar (high WAC)
202304,Biosimilar (high WAC)
202305,Originator
202305,Biosimilar (low WAC)
202305,Biosimilar (low WAC)
202305,Biosimilar (low WAC)
202305,Biosimilar (high WAC)
202306,Originator
202306,Biosimilar (low WAC)
202306,Biosimilar (low WAC)
202306,Biosimilar (low WAC)
202306,Biosimilar (high WAC)
202306,Biosimilar (high WAC)
;
run;
