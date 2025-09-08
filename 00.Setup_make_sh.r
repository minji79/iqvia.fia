
########################################################
##  Setting up and running R studio
########################################################

directory: cd /dcs07/hpm/data/iqvia_fia

cd /dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r

### glp1 proejct files
/dcs04/hpm/data/iqvia_fia/glp1_paper

# when give the permit to make a change to someone 
chmod 777 [file name]

/* run R */
srun --pty --x11 bash
module load R
module load rstudio
rstudio


########################################################
##  Make sh file
########################################################
# to make sh file, under the target directory, 
nano convert_dta_to_fst.sh

# in the file editor, copy and paste the *** codes (it is in the separate file)***, hit 'control + o' to save, and hit 'enter', then, 'control + x' to exit

# Make the script executable
chmod +x convert_dta_to_fst.sh

# submit my bash
sbatch convert_dta_to_fst.sh

# check my job status:
squeue --me


mv /dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r/glp1_gather.sh /dcs07/hpm/data/iqvia_fia/glp1_disc

mv /dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r/out/adalimumab_claims.parquet /dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r/data


