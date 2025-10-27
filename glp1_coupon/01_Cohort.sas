

/*============================================================*
 | 1) start from all glp1 claims between 2017 - 2024
 *============================================================*/

proc contents data=input.rx18_24_glp1_long_v00; run;
proc contents data=input.patients_v1; run;


data coupon.cohort_long_v00; set input.rx18_24_glp1_long_v00; if molecule_name not in ("LIXISENATIDE", "ALBIGLUTIDE"); run; /* - 16929 */

 
