#!/bin/bash

# Loop over job numbers (or whatever index you need)
for job_number in {1..1}; do
    # Generate a timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    job_name="adalimumab_gather_v3_${job_number}"
    output_file="adalimumab_gather_v3_${job_number}_${timestamp}.out"
    error_file="adalimumab_gather_v3_${job_number}_${timestamp}.err"

    sbatch <<EOT
#!/bin/bash
#SBATCH --job-name=${job_name}
#SBATCH --cpus-per-task=8
#SBATCH --mem=999GB
#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=mkim255@jhu.edu

#SBATCH --output=out/${output_file}
#SBATCH --error=errs/${error_file}

module load R

# Run R and echo every line + its output
Rscript --vanilla -e 'options(echo=TRUE); source("adalimumab_gather_v2.R", echo=TRUE)' ${job_number}

echo "R exit code: \$?"
EOT

done
