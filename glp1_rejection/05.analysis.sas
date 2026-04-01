proc contents data=input.id_index; run;
proc freq data=input.id_index; table RJ_reason_adj; run;

* outcome = primary non-adherance (non_ad_event=1);
data df; set input.id_index; if cohort4 ="filled at index date" then non_ad_event=0; else non_ad_event=1; run;

* age ; 
data df; set df; 
if 






proc logistic data=df;
    class patient_gender(ref='M') region (ref='Midwest') dominant_payer_adj (ref='Commercial') diabetes_history (ref='1') RJ_reason_adj (ref='Approved - paid') 
          molecule_name (ref='SEMAGLUTIDE') / param=glm order=internal;
    model non_ad_event(event='1') = age_at_claim patient_gender dominant_payer_adj diabetes_history RJ_reason_adj cash coupon discount_card molecule_name year;
run;

