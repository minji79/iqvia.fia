

directory: cd /dcs07/hpm/data/iqvia_fia
ref

/* run sas */
rm ~/.config/chromium/Singleton*
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* set library */
libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */

libname glp1 "/dcs07/hpm/data/iqvia_fia/glp1_paper";
libname glp1_data "/dcs07/hpm/data/iqvia_fia/glp1_paper/data";
libname auth_gen "/dcs07/hpm/data/iqvia_fia/auth_generics";
libname form_apx "/dcs07/hpm/data/iqvia_fia/formulary_approx";   /* formulary_approx  */

* see the files under glp1;
ods pdf file="molecule_trend_filled.png";
ods graphics / imagename="example_image" imagefmt=png;
title "Your Report with PNG Image";
ods pdf text = "^S={preimage='C:\path\to\your_image.png'}";
ods pdf close;



proc import datafile="/dcs07/hpm/data/iqvia_fia/glp1_paper/Step1b_glp1_ever_users.dta "
    out=mydata
    dbms=dta
    replace;
run;
proc print data=mydata (obs=20); run;


* convert do file to sas files;
filename dofile "/dcs07/hpm/data/iqvia_fia/glp1_paper/01_load_and_merge_glp1.do";
data do_commands;
    infile dofile;
    input line $char200.;
run;

proc print data=do_commands; run;



filename myfile "/dcs07/hpm/data/iqvia_fia/glp1_paper/01_load_and_merge_glp1.sh ";

data preview;
    infile myfile;
    input line $char200.;
run;

proc print data=preview(obs=10); run;
