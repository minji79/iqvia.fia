
/* 1. indicate ppl leaving FIA network pool 
  define as ppl without 
  patient_id level claim number with any type of plan
  compare with the dominant payer information
*/

* 1. made dataset for the last year in FIA dataset;
proc means data=input.dominant_payer_cleaned n nmiss min max; var year; run;
proc sort data=input.dominant_payer_cleaned out=dominant_payer_cleaned; by patient_id descending year; run; 
data dominant_payer_cleaned; set dominant_payer_cleaned; by patient_id; if first.patient_id; run;
proc print data=dominant_payer_cleaned (obs=50); run;

* 2. merge with the cohort long dataset;
* 2. indicate index year == last year; 
proc sql;
  create table switch.jama_published_cohort_cleaned as
  select distinct a.*, b.year as last_year_fia
  from switch.jama_published_cohort_cleaned as a
  left join dominant_payer_cleaned as b
	on a.patient_id = b.patient_id;
quit; 

* 3. update switching variable including those cases - see the freq including them ; 
data switch.jama_published_cohort_cleaned; set switch.jama_published_cohort_cleaned; drop switching; run;
data switch.jama_published_cohort_cleaned;
    set switch.jama_published_cohort_cleaned;
    if year >= last_year_fia then switching = 2; 
    else if missing(plan_id) or missing(next_dominant_plan_id) then switching = .;
    else if next_dominant_plan_id = plan_id then switching = 0; 
    else switching = 1; 
run;

data switch.jama_published_cohort_cleaned;
    set switch.jama_published_cohort_cleaned;
    if year >= last_year_fia then switching_v2 = 2; 
    else if missing(dominant_plan_id) or missing(next_dominant_plan_id) then switching_v2 = .;
    else if next_dominant_plan_id = dominant_plan_id then switching_v2 = 0; 
    else switching_v2 = 1; 
run;

proc freq data=switch.jama_published_cohort_cleaned; table switching; run;  /* N= 122250 */
proc freq data=switch.jama_published_cohort_cleaned; table switching_v2; run; /* N= 122250 */
proc print data=switch.jama_published_cohort_cleaned (obs=20); where missing(plan_id); run; /* none */
proc contents data=switch.jama_published_cohort_cleaned; run;

/* when using switching -> new cohort N= 1612378 */
data switch.cohort_1612378; set switch.jama_published_cohort_cleaned; if switching ne 2; run;
data switch.cohort_1612378; set switch.cohort_1612378; if not missing(switching); run;

/* when using switching_v2 -> new cohort N= 1570729 */
data switch.cohort_1570729; set switch.jama_published_cohort_cleaned; if switching_v2 ne 2; run;
data switch.cohort_1570729; set switch.cohort_1570729; if not missing(switching_v2); run;

/* 1. indicate ppl leaving FIA network pool */
proc freq data=switch.cohort_1612378; table switching*index_day_outcome /norow nopercent; run;
proc freq data=switch.cohort_1612378; table switching*table1_outcomes /norow nopercent; run;

proc freq data=switch.cohort_1570729; table switching_v2*index_day_outcome /norow nopercent; run;
proc freq data=switch.cohort_1570729; table switching_v2*table1_outcomes /norow nopercent; run;

/* by initial payer */
data sample; set switch.cohort_1570729; if dominant_payer="Commercial"; run;
data sample; set switch.cohort_1570729; if dominant_payer="Exchange"; run;
data sample; set switch.cohort_1570729; if dominant_payer="Medicare D: TM"; run;
data sample; set switch.cohort_1570729; if dominant_payer="Medicare D: ADV"; run;
data sample; set switch.cohort_1570729; if dominant_payer="Medicaid: FFS"; run;
data sample; set switch.cohort_1570729; if dominant_payer="Medicaid: MCO"; run;
proc freq data=sample; table switching_v2*table1_outcomes /norow nopercent; run;


/* 1. Create Sample Dataset Structure */
data plot_data;
    length insurer $20 status $25;
    input insurer $ status $ switch_rate;
    datalines;
Commercial Paid 9.75
Commercial Formulary_exclusion 12.11
Commercial Utilization_management 10.45
Exchange Paid 22.51
Exchange Formulary_exclusion 23.58
Exchange Utilization_management 23.93
Part_D_TM Paid 20.4
Part_D_TM Formulary_exclusion 23.4
Part_D_TM Utilization_management 24.63
MA-Part_D Paid 14.18
MA-Part_D Formulary_exclusion 15.8
MA-Part_D Utilization_management 15.12
Medicaid_FFS Paid 13.87
Medicaid_FFS Formulary_exclusion 24.74
Medicaid_FFS Utilization_management 13.47
Medicaid_MCO Paid 17.65
Medicaid_MCO Formulary_exclusion 15.57
Medicaid_MCO Utilization_management 15.55
;
run;

/* 3. Produce Plot using PROC SGPLOT */
proc sgplot data=plot_data noborder;
    /* 1. Custom Color and Symbol Mapping (Single block inside PROC SGPLOT) */
    styleattrs 
        datasymbols=(circlefilled) 
        datacontrastcolors=(cx6e6e6e cxcd4352 cx2b7cb7);

    /* 2. Grouped Scatter Plot with Clustering */
    scatter x=insurer y=switch_rate / 
        group=status 
        groupdisplay=cluster 
        clusterwidth=0.4
        markerattrs=(size=11);

    /* 3. X-Axis Formatting (Fixed fitpolicy syntax) */
    xaxis label="" 
          fitpolicy=rotate 
          valuesrotate=diagonal;

    /* 4. Y-Axis Formatting: Range 0 to 28, Gridlines */
    yaxis label="Switched plan (%)" 
          values=(0 to 28 by 5) 
          grid 
          gridattrs=(color=cxf0f0f0 pattern=solid);

    /* 5. Legend Customization */
    keylegend / location=inside 
               position=bottomright 
               noborder 
               down=3;

    /* 6. Title Styling */
    title justify=left height=13pt bold "Switch rate by index insurer";
run;



/* heatmap */
/* by initial payer */
data sample; set switch.cohort_1570729; if dominant_payer="Commercial"; run;
data sample; set switch.cohort_1570729; if dominant_payer="Exchange"; run;
data sample; set switch.cohort_1570729; if dominant_payer="Medicare D: TM" and switching_v2 =1;; run;
data sample; set switch.cohort_1570729; if dominant_payer="Medicare D: ADV"; run;
data sample; set switch.cohort_1570729; if dominant_payer="Medicaid: FFS"; run;
data sample; set switch.cohort_1570729; if dominant_payer="Medicaid: MCO"; run;

data sample; set switch.cohort_1570729; if dominant_payer="Medicare D: TM" and switching_v2 =1;; run;
proc freq data=sample; table switching_v2*next_dominant_payer /nocol nopercent; run;

/* ====================================================================
   STEP 1: Create Data with a Blank Separator Column (" ")
   ==================================================================== */
data heatmap_raw;
    length index_payer $20 outcome $25 section $15;
    input row_id index_payer $1-15 outcome $17-35 pct count section $;
    datalines;
Commercial      Did not switch     90.3 225076 outcome
Commercial      Switched           9.7  24194  outcome
Commercial      Commercial         59.0 14237  destination
Commercial      Exchange           11.0 2666   destination
Commercial      Part D TM          10.0 2521   destination
Commercial      MA-Part D          10.0 2327   destination
Commercial      Medicaid FFS       7.0  1736   destination
Commercial      Medicaid MCO       3.0  707    destination

Exchange        Did not switch     76.0 17198  outcome
Exchange        Switched           24.0 5437   outcome
Exchange        Commercial         29.0 1552   destination
Exchange        Exchange           40.0 2149   destination
Exchange        Part D TM          8.0  413    destination
Exchange        MA-Part D          12.0 644    destination
Exchange        Medicaid FFS       11.0 600    destination
Exchange        Medicaid MCO       1.0  79     destination

Part D TM       Did not switch     86.0 68285  outcome
Part D TM       Switched           14.0 11162  outcome
Part D TM       Commercial         2.0  278    destination
Part D TM       Exchange           0.0  17     destination
Part D TM       Part D TM          73.0 8200   destination
Part D TM       MA-Part D          21.0 2380   destination
Part D TM       Medicaid FFS       2.0  247    destination
Part D TM       Medicaid MCO       0.0  40     destination

MA-Part D       Did not switch     92.1 60759  outcome
MA-Part D       Switched           7.9  5178   outcome
MA-Part D       Commercial         4.0  205    destination
MA-Part D       Exchange           0.0  16     destination
MA-Part D       Part D TM          8.0  393    destination
MA-Part D       MA-Part D          85.0 4427   destination
MA-Part D       Medicaid FFS       2.0  88     destination
MA-Part D       Medicaid MCO       1.0  49     destination

Medicaid FFS    Did not switch     92.5 65689  outcome
Medicaid FFS    Switched           7.5  5332   outcome
Medicaid FFS    Commercial         30.0 1578   destination
Medicaid FFS    Exchange           14.0 759    destination
Medicaid FFS    Part D TM          27.0 1457   destination
Medicaid FFS    MA-Part D          16.0 878    destination
Medicaid FFS    Medicaid FFS       2.0  95     destination
Medicaid FFS    Medicaid MCO       11.0 565    destination

Medicaid MCO    Did not switch     87.7 37348  outcome
Medicaid MCO    Switched           12.3 5238   outcome
Medicaid MCO    Commercial         3.62 542    destination
Medicaid MCO    Exchange           3.72  557    destination
Medicaid MCO    Part D TM          11.73 1758    destination
Medicaid MCO    MA-Part D          13.63 2042    destination
Medicaid MCO    Medicaid FFS       48.0 2495   destination
Medicaid MCO    Medicaid MCO       8.0  421    destination
;
run;

/* ====================================================================
   STEP 2: Format Display Text & Separate Color Response Variables
   ==================================================================== */
data heatmap_data;
    set heatmap_raw;
    length display_text $30;

    /* Cell Overlay Text */
    if pct < 10 then display_text = cat(strip(put(pct, 4.1)), "%", '0A'x, "(", strip(put(count, comma10.)), ")");
    else display_text = cat(strip(put(pct, 3.0)), "%", '0A'x, "(", strip(put(count, comma10.)), ")");

    /* Separate heatmaps into two response variables */
    if section = 'outcome' then pct_outcome = pct;
    else pct_destination = pct;

    /* Dynamic Font Colors (White for dark tiles, Black for light tiles) */
    if outcome = 'Did not switch' or pct > 45 then text_white = display_text;
    else text_black = display_text;
run;

/* ====================================================================
   STEP 3: Render SGPLOT with Text Labels and Blank Gap Column (" ")
   ==================================================================== */
proc sgplot data=heatmap_data noborder noautolegend;

    /* Greyscale Heatmap (Left Panel) */
    heatmap x=outcome y=index_payer / 
        colorresponse=pct_outcome 
        colormodel=(cxf0f0f0 cx1a1a1a) 
        discretex discretey;

    /* Blue Heatmap (Right Panel) */
    heatmap x=outcome y=index_payer / 
        colorresponse=pct_destination 
        colormodel=(cxe8f1f8 cx0d47a1) 
        discretex discretey;

    /* White Text Overlay */
    text x=outcome y=index_payer text=text_white / 
        textattrs=(size=8pt weight=bold color=white) 
        splitchar='0A'x;

    /* Black Text Overlay */
    text x=outcome y=index_payer text=text_black / 
        textattrs=(size=8pt weight=bold color=black) 
        splitchar='0A'x;

    /* Y-Axis: Explicit character string array for label order */
    yaxis label="Index-year payer type" 
          type=discrete 
          reverse
          values=("Commercial" "Exchange" "Part D TM" "MA-Part D" "Medicaid FFS" "Medicaid MCO");

    /* X-Axis: " " acts as an empty gap column between 'Switched' and 'Commercial' */
    xaxis label="" 
          type=discrete 
          fitpolicy=rotate
          values=("Did not switch" "Switched" " " "Commercial" "Exchange" "Part D TM" "MA-Part D" "Medicaid FFS" "Medicaid MCO");

    title justify=left height=14pt bold "What happened after any formulary rejection?";
run;



/* 2. indicate plan_id exiting from the market
  define as ppl without 
  patient_id level claim number with any type of plan
  compare with the dominant payer information
*/

* 1. from the scratch dataset - sort by plan_id year - count all claims with adjudication status; 
* 2. : 
