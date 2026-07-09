#!/bin/bash -e
##########################################################################
#SBATCH -c 16                                 	# number of cores per task
#SBATCH -p jic-compute,nbi-compute
#SBATCH --mem 256G                            # memory pool for all cores
#SBATCH -t 00-04:00                              # time (D-HH:MM)
#SBATCH --mail-user="rob.ellis@jic.ac.uk"
#SBATCH --mail-type=END,FAIL
#SBATCH --job-name="vcfgz"
#SBATCH --output=log/vcfgz/slurm-%x.%A_%a.out
#SBATCH --error=log/vcfgz/slurm-%x.%A_%a.err
#SBATCH --array=0-6
##SBATCH --array=0-1040
################################################################################
# samtools 1.18
source package c92263ec-95e5-43eb-a527-8f1496d56f1a
################################################################################
# SAMPLE_LIST="watkins_list"
SAMPLE_LIST="20250611_comp"
################################################################################

readarray -t SAMPLE_ARRAY < ${SAMPLE_LIST}

SAMPLE=${SAMPLE_ARRAY[${SLURM_ARRAY_TASK_ID}]}

mkdir -p vcfgz

echo "Compressing vcf for $SAMPLE"

bgzip --threads "$SLURM_CPUS_PER_TASK" -c "vcf/$SAMPLE.vcf" > "vcfgz/$SAMPLE.vcf.gz"

echo "Indexing compressed vcf"

singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" "vcfgz/$SAMPLE.vcf.gz"

echo "Done compressing and indexing"
