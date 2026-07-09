#!/bin/bash -e
###########################################################################
#SBATCH --mail-user="rob.ellis@jic.ac.uk"
#SBATCH --mail-type=END,FAIL
#SBATCH -p jic-compute,nbi-compute
###########################################################################
#SBATCH --job-name="merge_vcf"
#SBATCH -c 32
#SBATCH --mem 495G
#SBATCH -t 01-00:00
#SBATCH --gres=ssd
#SBATCH --localscratch=ssd:1500
#SBATCH --output=log/merge_vcf2/slurm-%x.%A_%a.out
#SBATCH --error=log/merge_vcf2/slurm-%x.%A_%a.err
#SBATCH --array=0
##SBATCH --array=0-431
###########################################################################
SAMPLE_LIST_AA=watkins_list_aa_2
SAMPLE_LIST_AB=watkins_list_ab_2
SAMPLE_LIST_AC=watkins_list_ac_2
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

mkdir -p chr2

readarray -t CONTIG_ARRAY < <(cat ref/19082024_paragon_v3.fa |grep ">"|cut -d ">" -f2)

CONTIG=${CONTIG_ARRAY[${SLURM_ARRAY_TASK_ID}]}

echo "Creating vcf samples for $CONTIG"

mkdir -p ${SLURM_LOCAL_SCRATCH}/aa
mkdir -p ${SLURM_LOCAL_SCRATCH}/ab
mkdir -p ${SLURM_LOCAL_SCRATCH}/ac

readarray -t SAMPLES_AA < $SAMPLE_LIST_AA
readarray -t SAMPLES_AB < $SAMPLE_LIST_AB
readarray -t SAMPLES_AC < $SAMPLE_LIST_AC


for i in ${SAMPLES_AA[@]}; do
	singularity exec ~/sif/bcftools-1.21.sif bcftools view -r $CONTIG vcfgz/$i.vcf.gz -o ${SLURM_LOCAL_SCRATCH}/aa/$i.vcf.gz
	singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/aa/$i.vcf.gz
done

for i in ${SAMPLES_AB[@]}; do
	singularity exec ~/sif/bcftools-1.21.sif bcftools view -r $CONTIG vcfgz/$i.vcf.gz -o ${SLURM_LOCAL_SCRATCH}/ab/$i.vcf.gz
	singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/ab/$i.vcf.gz
done

for i in ${SAMPLES_AC[@]}; do
	singularity exec ~/sif/bcftools-1.21.sif bcftools view -r $CONTIG vcfgz/$i.vcf.gz -o ${SLURM_LOCAL_SCRATCH}/ac/$i.vcf.gz
	singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/ac/$i.vcf.gz
done

echo "First stage merging vcf samples for $CONTIG"

singularity exec ~/sif/bcftools-1.21.sif bcftools merge --threads "$SLURM_CPUS_PER_TASK" -o ${SLURM_LOCAL_SCRATCH}/aa.vcf.gz ${SLURM_LOCAL_SCRATCH}/aa/*.vcf.gz
singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/aa.vcf.gz

singularity exec ~/sif/bcftools-1.21.sif bcftools merge --threads "$SLURM_CPUS_PER_TASK" -o ${SLURM_LOCAL_SCRATCH}/ab.vcf.gz ${SLURM_LOCAL_SCRATCH}/ab/*.vcf.gz
singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/ab.vcf.gz

singularity exec ~/sif/bcftools-1.21.sif bcftools merge --threads "$SLURM_CPUS_PER_TASK" -o ${SLURM_LOCAL_SCRATCH}/ac.vcf.gz ${SLURM_LOCAL_SCRATCH}/ac/*.vcf.gz
singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" ${SLURM_LOCAL_SCRATCH}/ac.vcf.gz


echo "Second stage merging vcf samples for $CONTIG"

singularity exec ~/sif/bcftools-1.21.sif bcftools merge --threads "$SLURM_CPUS_PER_TASK" -o chr2/watkins_$CONTIG.vcf.gz ${SLURM_LOCAL_SCRATCH}/aa.vcf.gz ${SLURM_LOCAL_SCRATCH}/ab.vcf.gz ${SLURM_LOCAL_SCRATCH}/ac.vcf.gz
singularity exec ~/sif/bcftools-1.21.sif bcftools index --threads "$SLURM_CPUS_PER_TASK" chr2/watkins_$CONTIG.vcf.gz

echo "Done merging vcf for $CONTIG"
