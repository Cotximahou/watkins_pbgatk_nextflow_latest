#!/bin/bash -e
################################################################################
#SBATCH -c 32                                 	# number of cores per task
#SBATCH -p jic-gpu 
#SBATCH --mem 950000                            # memory pool for all cores
#SBATCH -t 0-10:00                              # time (D-HH:MM)
#SBATCH --mail-user="rob.ellis@jic.ac.uk"
#SBATCH --mail-type=END,FAIL
#SBATCH --gres=ssd,gpu:a100:2                   # request number of GPUs and SSD
#SBATCH --localscratch=ssd:1000                 # request 1TB SSD
#SBATCH --job-name="pbgatk"
#SBATCH --output=log/pbgatk_2gpus_p/slurm-%x.%A_%a.out
#SBATCH --error=log/pbgatk_2gpus_p/slurm-%x.%A_%a.err
#SBATCH --array=93
################################################################################
# parabricks 4.3.3.1
source package 40b030a5-9757-4084-a0f8-379ed3146631
################################################################################
SAMPLE_LIST="watkins_ecs_list"
# SAMPLE_LIST="watkins_mybookduo_list"
################################################################################

readarray -t SAMPLE_ARRAY < ${SAMPLE_LIST}

SAMPLE=${SAMPLE_ARRAY[${SLURM_ARRAY_TASK_ID}]}

readarray -d '' READS < <(find /jic/archive/projects/watseq/ECS/pr-raw-watseq/ -name ${SAMPLE}*.R1.fastp.fastq.gz -not -path "/jic/archive/projects/watseq/ECS/pr-raw-watseq/WatSeq-modern_global_reads/data/modern_clean1/zzz.sup/*" -print0 | sort)
# readarray -d '' READS < <(find /jic/archive/projects/watseq/My_Book_Duo/ -name ${SAMPLE}*.R1.fastq.gz -print0 | sort)

INPUT_ARG=()

FILE_PATH=$(echo "${READS[0]}" |cut -d "." -f 1)
FILE_NAME=$(basename $FILE_PATH)
SAMPLEID=$(echo $FILE_NAME |cut -d "_" -f 1)
PLATFORM=ILLUMINA

for i in ${READS[@]}; do 
	PREFIX=$(echo "$i" |cut -d "." -f 1)	
	INPUT_ARG+="--in-fq $PREFIX.R1.fastp.fastq.gz $PREFIX.R2.fastp.fastq.gz "
	# INPUT_ARG+="--in-fq $PREFIX.R1.fastq.gz $PREFIX.R2.fastq.gz "
done

mkdir -p cram
mkdir -p vcf

pbrun germline \
	--ref ref/19082024_paragon_v3.fa \
	${INPUT_ARG[@]} \
	--out-bam cram/${SAMPLE}.cram \
	--tmp-dir $SLURM_LOCAL_SCRATCH/ \
	--out-variants vcf/${SAMPLE}.vcf \
	--run-partition \
	--num-gpus 2 \
        --num-htvc-threads 32 \
	--read-group-sm ${SAMPLEID} \
	--read-group-pl ${PLATFORM} \
	--read-group-id-prefix ${SAMPLEID} \
	--keep-tmp \
	--x3
