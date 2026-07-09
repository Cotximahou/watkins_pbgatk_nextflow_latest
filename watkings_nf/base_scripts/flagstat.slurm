#!/bin/bash -e
###########################################################################
#SBATCH --mail-user="rob.ellis@jic.ac.uk"
#SBATCH --mail-type=END,FAIL
#SBATCH -p jic-compute,nbi-compute
###########################################################################
#SBATCH --job-name="fs"
#SBATCH -c 16
#SBATCH --mem 64G
#SBATCH -t 00-08:00
#SBATCH --output=log/fs/slurm-%x.%A_%a.out
#SBATCH --error=log/fs/slurm-%x.%A_%a.err
#SBATCH --array=198,199
##SBATCH --array=0-1038
###########################################################################
# samtools 1.18
source package c92263ec-95e5-43eb-a527-8f1496d56f1a
###########################################################################
SAMPLE_LIST="/jic/scratch/platforms/informatics/rellis/watkins_list"
###########################################################################

readarray -t SAMPLE_ARRAY < ${SAMPLE_LIST}

SAMPLE=${SAMPLE_ARRAY[${SLURM_ARRAY_TASK_ID}]}

echo "${SAMPLE}"

mkdir -p flagstat

echo ${SAMPLE} > flagstat/${SAMPLE}
samtools flagstat -@ ${SLURM_CPUS_PER_TASK} cram/${SAMPLE}.cram >> flagstat/${SAMPLE}

echo "${SAMPLE}, $(sed '2q;d' flagstat/${SAMPLE} |cut -d ' ' -f1), $(sed '8q;d' flagstat/${SAMPLE} |cut -d ' ' -f1)" >> stat.csv

echo "DONE"
