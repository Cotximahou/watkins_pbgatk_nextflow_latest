#!/bin/bash

while read l; do
	if [ ! -f "/jic/scratch/platforms/informatics/rellis/watkins_pbgatk/vcf/$l.vcf" ]; then
		echo "$l.vcf"
	fi
done < watkins_list 
