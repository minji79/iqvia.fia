/*============================================================*
 | 1) dominant payer identify
 |   Adapted from glp1/03_dominant_plan_identification.sas.
 |   The LEFT JOIN to the plan-mapping table, the missing()-based
 |   fill-in of dominant_payer, and the FREQ are kept as authored;
 |   the two source tables are the small samples built in autoexec.sas.
 *============================================================*/
proc print data=input.joe_plan_mapping (obs=20); run;

* with primary cohort;
proc sql;
	create table rx18_24_glp1_long_v00 as
	select distinct a.*, b.dominant_payer
	from input.rx18_24_glp1_long_v00 as a
	left join input.joe_plan_mapping as b
	on a.patient_id = b.patient_id and a.year = b.year;
quit;

data rx18_24_glp1_long_v00; set rx18_24_glp1_long_v00;
	if missing(dominant_payer) and payer_type_indicator = "dominant_payer" then dominant_payer = payer_type;
	else if missing(dominant_payer) and payer_type_indicator = "secondary_payer" then dominant_payer = "Unclear Insurance";
	else dominant_payer = dominant_payer;
run;
proc freq data=rx18_24_glp1_long_v00 ; table dominant_payer; run;

proc print data=rx18_24_glp1_long_v00 (obs=20); var payer_type dominant_payer; run;
proc print data=rx18_24_glp1_long_v00 (obs=60); var patient_id year molecule_name payer_type dominant_payer; where missing(dominant_payer); run;
