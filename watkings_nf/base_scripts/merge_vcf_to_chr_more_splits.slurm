#!/bin/bash -e
###########################################################################
#SBATCH --mail-user="rob.ellis@jic.ac.uk"
#SBATCH --mail-type=END,FAIL
#SBATCH -p jic-gpu
###########################################################################
#SBATCH --job-name="merge_vcf"
#SBATCH -c 32
#SBATCH --mem 1000G
#SBATCH -t 01-00:00
#SBATCH --gres=ssd
#SBATCH --localscratch=ssd:1500
#SBATCH --output=log/merge_vcf/slurm-%x.%A_%a.out
#SBATCH --error=log/merge_vcf/slurm-%x.%A_%a.err
#SBATCH --array=424
##SBATCH --array=0-431
###########################################################################
SAMPLE_LIST_AAA=watkins_list_aaa
SAMPLE_LIST_AAB=watkins_list_aab
SAMPLE_LIST_ABA=watkins_list_aba
SAMPLE_LIST_ABB=watkins_list_abb
SAMPLE_LIST_AC=watkins_list_ac
###########################################################################

echo "Waiting on ${SLURM_LOCAL_SCRATCH} becoming available"

COUNT=0

while [ ! -d "${SLURM_LOCAL_SCRATCH}" ]; do
    sleep 15
    COUNT=$(( COUNT + 1 ))

    if [[ "$COUNT" == "40" ]]; then
	    echo "Timeout waiting for ${SLURM_LOCAL_SCRATCH} on $(hostname)" 1>&2;
	    exit -1
    fi

done

echo "${SLURM_LOCAL_SCRATCH} is now available create directories"

mkdir -p chr

readarray -t CONTIG_ARRAY < <(cat ref/19082024_paragon_v3.fa |grep ">"|cut -d ">" -f2)

CONTIG=${CONTIG_ARRAY[${SLURM_ARRAY_TASK_ID}]}

echo "Creating vcf samples for $CONTIG"

mkdir -p ${SLURM_LOCAL_SCRATCH}/aaa
mkdir -p ${SLURM_LOCAL_SCRATCH}/aab
mkdir -p ${SLURM_LOCAL_SCRATCH}/aba
mkdir -p ${SLURM_LOCAL_SCRATCH}/abb
mkdir -p ${SLURM_LOCAL_SCRATCH}/ac

readarray -t SAMPLES_AAA < $SAMPLE_LIST_AAA
readarray -t SAMPLES_AAB < $SAMPLE_LIST_AAB
readarray -t SAMPLES_ABA < $SAMPLE_LIST_ABA
readarray -t SAMPLES_ABB < $SAMPLE_LIST_ABB
readarray -t SAMPLES_AC < $SAMPLE_LIST_AC


for i in ${SAMPLES_AAA[@]}; do
	singularity exec ~/sif/bcftools-1.21.sif bcftools view -r $CONTIG vcfgz/$i.vcf.gz -o ${SLURM_LOCAL_SCRATCH}/aaa/$i.vcf.gz
	singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/aaa/$i.vcf.gz
done

for i in ${SAMPLES_AAB[@]}; do
	singularity exec ~/sif/bcftools-1.21.sif bcftools view -r $CONTIG vcfgz/$i.vcf.gz -o ${SLURM_LOCAL_SCRATCH}/aab/$i.vcf.gz
	singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/aab/$i.vcf.gz
done

for i in ${SAMPLES_ABA[@]}; do
	singularity exec ~/sif/bcftools-1.21.sif bcftools view -r $CONTIG vcfgz/$i.vcf.gz -o ${SLURM_LOCAL_SCRATCH}/aba/$i.vcf.gz
	singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/aba/$i.vcf.gz
done

for i in ${SAMPLES_ABB[@]}; do
	singularity exec ~/sif/bcftools-1.21.sif bcftools view -r $CONTIG vcfgz/$i.vcf.gz -o ${SLURM_LOCAL_SCRATCH}/abb/$i.vcf.gz
	singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/abb/$i.vcf.gz
done

for i in ${SAMPLES_AC[@]}; do
	singularity exec ~/sif/bcftools-1.21.sif bcftools view -r $CONTIG vcfgz/$i.vcf.gz -o ${SLURM_LOCAL_SCRATCH}/ac/$i.vcf.gz
	singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/ac/$i.vcf.gz
done

echo "First stage merging vcf samples for $CONTIG"

singularity exec ~/sif/bcftools-1.21.sif bcftools merge --threads "$SLURM_CPUS_PER_TASK" -o ${SLURM_LOCAL_SCRATCH}/aaa.vcf.gz ${SLURM_LOCAL_SCRATCH}/aaa/*.vcf.gz
singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/aaa.vcf.gz

singularity exec ~/sif/bcftools-1.21.sif bcftools merge --threads "$SLURM_CPUS_PER_TASK" -o ${SLURM_LOCAL_SCRATCH}/aab.vcf.gz ${SLURM_LOCAL_SCRATCH}/aab/*.vcf.gz
singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/aab.vcf.gz

singularity exec ~/sif/bcftools-1.21.sif bcftools merge --threads "$SLURM_CPUS_PER_TASK" -o ${SLURM_LOCAL_SCRATCH}/aba.vcf.gz ${SLURM_LOCAL_SCRATCH}/aba/*.vcf.gz
singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/aba.vcf.gz

singularity exec ~/sif/bcftools-1.21.sif bcftools merge --threads "$SLURM_CPUS_PER_TASK" -o ${SLURM_LOCAL_SCRATCH}/abb.vcf.gz ${SLURM_LOCAL_SCRATCH}/abb/*.vcf.gz
singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/abb.vcf.gz

singularity exec ~/sif/bcftools-1.21.sif bcftools merge --threads "$SLURM_CPUS_PER_TASK" -o ${SLURM_LOCAL_SCRATCH}/ac.vcf.gz ${SLURM_LOCAL_SCRATCH}/ac/*.vcf.gz
singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/ac.vcf.gz


echo "Second stage merging vcf samples for $CONTIG"

singularity exec ~/sif/bcftools-1.21.sif bcftools merge --threads "$SLURM_CPUS_PER_TASK" -o chr/watkins_$CONTIG.vcf.gz ${SLURM_LOCAL_SCRATCH}/aaa.vcf.gz ${SLURM_LOCAL_SCRATCH}/aab.vcf.gz ${SLURM_LOCAL_SCRATCH}/aba.vcf.gz ${SLURM_LOCAL_SCRATCH}/abb.vcf.gz ${SLURM_LOCAL_SCRATCH}/ac.vcf.gz
singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" chr/watkins_$CONTIG.vcf.gz

echo "Done merging vcf for $CONTIG"
