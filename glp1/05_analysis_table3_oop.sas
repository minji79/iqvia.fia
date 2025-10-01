
/*============================================================*
 |      quaterly OOP 
 *============================================================*/
input.rx18_24_glp1_long_v01; 
* make quater indicator; 


/*============================================================*
 |      margins plot with prob of rejection (event = rejection)
 *============================================================*/

 rejection rate - claim level

* preprocessing for fitting;
 
 proc logistic data=input.rx18_24_glp1_long_v01;
    class market(ref='other') gender(ref='M') / param=ref;
    model outcome(event='1') = market age gender year*market;
    store logit_model;   /* save the model for later use */
run;

proc plm restore=logit_model;
    effectplot slicefit(x=year sliceby=market) / at(age=50 gender='F');
    effectplot slicefit(x=market sliceby=year) / clm;
    effectplot contour(x=year y=age) / sliceby=market;
run;

proc plm restore=logit_model;
    lsmeans market*year / ilink odds cl;
run;
