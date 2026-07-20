process EXTRACT_CONTIG_SAMPLE {
    label 'cpu_medium'
    container params.container_bcftools

    input:
    tuple val(contig), val(sample_id), path(vcfgz), path(csi)

    output:
    tuple val(contig),
          path("${contig}__${sample_id}.vcf.gz"),
          path("${contig}__${sample_id}.vcf.gz.csi"), emit: contig_vcfgz

    script:
    """
    bcftools view -r ${contig} -Oz -o ${contig}__${sample_id}.vcf.gz ${vcfgz}
    bcftools index --threads ${task.cpus} ${contig}__${sample_id}.vcf.gz
    """
}

process MERGE_CONTIG_CHUNK {
    label 'cpu_merge'
    container params.container_bcftools

    input:
    tuple val(contig), val(chunk_id), val(n_vcfs), path(vcfs), path(csis)

    output:
    tuple val(contig),
          path("${contig}.chunk${chunk_id}.vcf.gz"),
          path("${contig}.chunk${chunk_id}.vcf.gz.csi"), emit: chunk_vcfgz

    script:
    def vcfList = vcfs instanceof List ? vcfs : [vcfs]
    def vcfArgs = vcfList.collect { it.toString() }.join(' ')

    """
    if [[ ${n_vcfs} -eq 1 ]]; then
        cp ${vcfList[0]} ${contig}.chunk${chunk_id}.vcf.gz
    else
        bcftools merge --threads ${task.cpus} -Oz -o ${contig}.chunk${chunk_id}.vcf.gz ${vcfArgs}
    fi

    bcftools index --threads ${task.cpus} ${contig}.chunk${chunk_id}.vcf.gz
    """
}

// FIX: input now includes csis (index files) which were previously dropped
// in main.nf's .map() before this process. bcftools merge requires index
// files to be present alongside the VCFs.
process MERGE_CONTIG_FINAL {
    label 'cpu_merge'
    container params.container_bcftools

    publishDir "${params.outdir}/chr", mode: 'copy', pattern: 'watkins_*.vcf.gz'
    publishDir "${params.outdir}/chr", mode: 'copy', pattern: 'watkins_*.vcf.gz.csi'

    input:
    tuple val(contig), path(chunk_vcfs), path(chunk_csis)

    output:
    tuple val(contig),
          path("watkins_${contig}.vcf.gz"),
          path("watkins_${contig}.vcf.gz.csi"), emit: contig_vcf

    script:
    def chunkList = chunk_vcfs instanceof List ? chunk_vcfs : [chunk_vcfs]
    def n        = chunkList.size()
    def vcfArgs  = chunkList.collect { it.toString() }.join(' ')

    """
    if [[ ${n} -eq 1 ]]; then
        cp ${chunkList[0]} watkins_${contig}.vcf.gz
    else
        bcftools merge --threads ${task.cpus} -Oz -o watkins_${contig}.vcf.gz ${vcfArgs}
    fi

    bcftools index --threads ${task.cpus} watkins_${contig}.vcf.gz
    """
}

process CONCAT_ALL_CONTIGS {
    label 'cpu_merge'
    container params.container_bcftools

    publishDir "${params.outdir}", mode: 'copy', pattern: 'watkins_all.vcf.gz*'

    input:
    path(vcfs)
    path(csis)

    output:
    tuple path("watkins_all.vcf.gz"), path("watkins_all.vcf.gz.csi"), emit: full_vcf

    script:
    def vcfList = vcfs instanceof List ? vcfs.sort { it.name } : [vcfs]
    def n = vcfList.size()
    def vcfArgs = vcfList.join(' ')

    """
    if [[ ${n} -eq 1 ]]; then
        cp ${vcfList[0]} watkins_all.vcf.gz
    else
        echo "Validating sample sets for final merge..."
        ref_samples=$(bcftools query -l ${vcfList[0]} | tr '\n' ',' | sed 's/,$//')
        echo "Reference sample set from ${vcfList[0]}: ${ref_samples}"
        for f in ${vcfArgs}; do
            samples=$(bcftools query -l "$f" | tr '\n' ',' | sed 's/,$//')
            if [[ "${samples}" != "${ref_samples}" ]]; then
                echo "ERROR: sample set mismatch between ${vcfList[0]} and $f"
                echo "  ref: ${ref_samples}"
                echo "  file: ${samples}"
                exit 1
            fi
        done

        bcftools merge --threads ${task.cpus} -Oz -o watkins_all.vcf.gz ${vcfArgs}
    fi

    bcftools index --threads ${task.cpus} watkins_all.vcf.gz
    """
}