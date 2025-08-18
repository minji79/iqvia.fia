#!/bin/bash

# Loop over job numbers (or whatever index you need)
for job_number in {1..1}; do
    # Generate a timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    job_name="convert_dta_to_fst_${job_number}"
    output_file="convert_dta_to_fst_${job_number}_${timestamp}.out"
    error_file="convert_dta_to_fst_${job_number}_${timestamp}.err"

    sbatch <<EOT
#!/bin/bash
#SBATCH --job-name=${job_name}
#SBATCH --cpus-per-task=8
#SBATCH --mem=999GB
#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=mkim255@jhu.edu

#SBATCH --output=out/${output_file}
#SBATCH --error=errs/${error_file}

export STATATMP=/dcs07/hpm/data/iqvia_fia/root/
module load R
Rscript convert_dta_to_fst.R ${job_number}
echo "R exit code: \$?"
EOT

done
