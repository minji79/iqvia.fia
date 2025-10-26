
directory: cd /dcs07/hpm/data/iqvia_fia

/* run sas */
rm ~/.config/chromium/Singleton*
srun --pty --x11 --partition sas bash
module load sas
sas -helpbrowser SAS -xrm "SAS.webBrowser:'/usr/bin/chromium-browser'" -xrm "SAS.helpBrowser:'/usr/bin/chromium-browser'"

/* set library */
libname coupon "/dcs07/hpm/data/iqvia_fia/glp1_coupon";   /* my own directory */
libname input "/dcs07/hpm/data/iqvia_fia/glp1_disc";   /* discontinuation study data */
libname home "/dcs07/hpm/data/iqvia_fia";   /* home directory */
libname fia100 "/dcs07/hpm/data/iqvia_fia/full_raw";   /* 100% rqw data */
libname ref "/dcs07/hpm/data/iqvia_fia/ref";   /* reference files */
libname red "/dcs07/hpm/data/iqvia_fia/reduced";   /* reference files */
libname glp1 "/dcs04/hpm/data/iqvia_fia/glp1_paper/data";
libname biosim "/dcs07/hpm/data/iqvia_fia/biosim";   /* for reference files */

libname fast "/fastscratch/myscratch/mkim";   /* my fastbarch with 1 TB memory */
