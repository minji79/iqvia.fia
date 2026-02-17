

proc contents data=biosim.RxFact2025; run;
proc freq data=biosim.RxFact2025; table rjct_cd; run;

data biosim.RxFact2025; set biosim.RxFact2025; year=year(svc_dt); run;
data biosim.RxFact2025; set biosim.RxFact2025; if year = 2025; run;
proc freq data=biosim.RxFact2025; table year; run;







