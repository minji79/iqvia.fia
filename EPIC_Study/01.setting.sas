


/* run sas */
rm ~/.config/chromium/Singleton*
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* set library */
libname plan "/dcs07/hpm/data/iqvia_fia/jhu_plan";   
libname input "/dcs07/hpm/data/iqvia_fia/glp1_disc";   /* my own directory */
libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */
libname glp1 "/dcs04/hpm/data/iqvia_fia/glp1_paper/data";
libname biosim "/dcs07/hpm/data/iqvia_fia/biosim";   /* for reference files */
libname coupon "/dcs07/hpm/data/iqvia_fia/glp1_disc/glp1_coupon";   
libname parquet "/dcs07/hpm/data/iqvia_fia/parquet/data";   

libname fast "/fastscratch/myscratch/mkim";   /* my fastbarch with 1 TB memory */


/*============================================================*
 | 1. set list up for plan information
 *============================================================*/
* plan;
proc contents data=biosim.plan; run;

data plan.epic_plan;
    set biosim.plan;
    if index(upcase(plan_name), "3M COMPANY") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "ALIGHT") > 0 then flag = 1;  /* can not find */ 
    else if index(upcase(plan_name), "ALLIANT") > 0 then flag = 1;  /* 2 */ 
    else if index(upcase(plan_name), "AMAZON") > 0 then flag = 1;  /* include discount card program */
    else if index(upcase(plan_name), "AMERICAN AIR") > 0 then flag = 1;
    else if index(upcase(plan_name), "AON") > 0 then flag = 1;
    else if index(upcase(plan_name), "GALLAGHER") > 0 then flag = 1; /* 2 */
    else if index(upcase(plan_name), "AT AND T") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "BANK OF AMERICA") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLACKROCK") > 0 then flag = 1;
    else if index(upcase(plan_name), "BLUE SHIELD") > 0 then flag = 1;  /* 10 */
    else if index(upcase(plan_name), "BOEING COMPANY") > 0 then flag = 1;  /* 2 */
    else if index(upcase(plan_name), "BRISTOL-MYERS") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "CATERPILLAR") > 0 then flag = 1;
    else if index(upcase(plan_name), "CHEVRON CORPORATION") > 0 then flag = 1;
    else if index(upcase(plan_name), "CIGNA") > 0 then flag = 1;          /* 169 plans */
    else if index(upcase(plan_name), "COMCAST/NBC") > 0 then flag = 1;
    else if index(upcase(plan_name), "COSTCO WHOLESALE") > 0 then flag = 1;
    else if index(upcase(plan_name), "CROWELL") > 0 then flag = 1;
    else if index(upcase(plan_name), "CVS HEALTH") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "DEERE") > 0 then flag = 1;
    else if index(upcase(plan_name), "DELTA AIR") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "EATON") > 0 then flag = 1; /* 2 */
    else if index(upcase(plan_name), "ELEVANCE") > 0 then flag = 1;
    else if index(upcase(plan_name), "EXXON") > 0 then flag = 1;
    
    else if index(upcase(plan_name), "") > 0 then flag = 1;
    else if index(upcase(plan_name), "") > 0 then flag = 1;
    
    else flag = 0;
run;


proc print data=biosim.plan; where index(upcase(plan_name), "EXXON") > 0; run;


