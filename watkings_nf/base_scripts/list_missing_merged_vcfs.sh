#!/bin/bash


readarray -t CONTIG_ARRAY < <(cat ref/19082024_paragon_v3.fa |grep ">"|cut -d ">" -f2)

COUNT=0

for i in ${CONTIG_ARRAY[@]}; do

	if [ ! -f "/jic/scratch/platforms/informatics/rellis/watkins_pbgatk/chr/watkins_$i.vcf.gz" ]; then
		echo "$COUNT $i.vcf.gz"
	fi

	COUNT=$(( COUNT + 1 ))
done
