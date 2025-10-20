
proc contents data=input.final_claims; run;

/*============================================================*
|  1. disc_at_1y - overall
*============================================================*/
proc freq data=input.patients_v1; table disc_at_1y; run;

/*============================================================*
|  2. disc_at_1y - Payer type at the last fill
*============================================================*/
* pool payer_type; 
data final_claims; set input.final_claims; length payer_type_adj $100.; if payer_type in ("Cash", "Coupon","Discount Card","PBM","PPO/HMO","Part B","Unspec","missing") then payer_type_adj = "Others"; else payer_type_adj = payer_type; run;

proc freq data=final_claims; table disc_at_1y*payer_type_adj /norow nopercent; run;

/*============================================================*
|  2. disc_at_1y - encnt_outcm_cd at the last fill
*============================================================*/
proc freq data=input.final_claims; table disc_at_1y*encnt_outcm_cd /norow nopercent; run;

* rejection reason;
* pool  rejection reason;
data final_claims; set input.final_claims; length RJ_reason_adj $100.; if RJ_reason in ("NA", "RJ by Secondary","RJ_Coverage_Not_Active","RJ_Others_NotForm") then RJ_reason_adj = "Others"; else RJ_reason_adj = RJ_reason; run;
proc freq data=final_claims; table disc_at_1y*RJ_reason_adj /norow nopercent; run;


/*============================================================*
|  3. disc_at_1y - indication & diabetes_history & molecule & mail (chnl_cd)
*============================================================*/
proc freq data=input.final_claims; table disc_at_1y*indication /norow nopercent; run;
proc freq data=input.final_claims; table disc_at_1y*diabetes_history /norow nopercent; run;

proc freq data=input.final_claims; table disc_at_1y*molecule_name /norow nopercent; run;

proc freq data=input.final_claims; table disc_at_1y*chnl_cd /norow nopercent; run;

/*============================================================*
|  4. disc_at_1y - OOP at the last claim
*============================================================*/
* among paid claims;
data final_claims_paid;set input.final_claims; if encnt_outcm_cd ="PD"; run; 
data final_claims_paid; set final_claims_paid; oop_30day = final_opc_amt / days_supply_cnt * 30; run;

proc univariate data=final_claims_paid noprint;
    var oop_30day;
    output out=quantiles pctlpre=P_ pctlpts=25 50 75;
run;
proc print data=quantiles (obs=10); run;

data final_claims_paid; set final_claims_paid; 
 if oop_30day <= 0 then oop_30day_q = 1; 
 else if 0 < oop_index <= 13.3875 then oop_30day_q = 2; 
 else if 13.3875 < oop_index <= 26.7857 then oop_30day_q = 3; 
 else oop_30day_q = 4; 
run;
proc freq data=final_claims_paid; table oop_30day_q; run;


* oop_index_q = 1 ~ 4; 
data final_claims_paid_q1; set final_claims_paid; if oop_30day_q = 1;  run;
proc freq data=final_claims_paid_q1; table disc_at_1y; run;

data final_claims_paid_q4; set final_claims_paid; if oop_30day_q = 4;  run;
proc freq data=final_claims_paid_q4; table disc_at_1y; run;


/*============================================================*
|  5. disc_at_1y - cash, coupon, discount card users
*============================================================*/
proc freq data=input.patients_v1; table disc_at_1y*cash_ever /norow nopercent; run;
proc freq data=input.patients_v1; table disc_at_1y*coupon_ever /norow nopercent; run;
proc freq data=input.patients_v1; table disc_at_1y*discount_card_ever /norow nopercent; run;


/*============================================================*
|  6. disc_at_1y - patient's characteristics
*============================================================*/
* 65 year older indicator;
data input.final_claims; set input.final_claims; if age_at_claim >=65 then age_65_over =1; else age_65_over =0; run; 
proc freq data=input.final_claims; table disc_at_1y*age_65_over /norow nopercent; run;

proc freq data=input.final_claims; table disc_at_1y*patient_gender /norow nopercent; run;
proc freq data=input.final_claims; table disc_at_1y*region /norow nopercent; run;


