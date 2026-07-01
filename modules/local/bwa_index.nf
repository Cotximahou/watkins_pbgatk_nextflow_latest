// Builds BWA index + samtools .fai for a reference FASTA.
// Uses storeDir so the index is built only once and reused across runs.

process BWA_INDEX {
    label 'cpu_medium'
    container params.container_bwa

    storeDir "${params.outdir}/ref_index"

    input:
    path ref

    output:
    tuple path("${ref.name}"),
          path("${ref.name}.amb"),
          path("${ref.name}.ann"),
          path("${ref.name}.bwt"),
          path("${ref.name}.pac"),
          path("${ref.name}.sa"), emit: bwa_indexed

    script:
    """
    bwa index ${ref}
    """
}

process SAMTOOLS_FAIDX {
    label 'cpu_medium'
    container params.container_samtools

    storeDir "${params.outdir}/ref_index"

    input:
    path ref

    output:
    path("${ref.name}.fai"), emit: fai

    script:
    """
    samtools faidx ${ref}
    """
}

workflow BUILD_BWA_INDEX {
    take:
    ref   // single path to the FASTA

    main:
    BWA_INDEX(ref)
    SAMTOOLS_FAIDX(ref)

    // Combine into a single 7-tuple consumed downstream:
    // (fasta, amb, ann, bwt, pac, sa, fai)
    ref_with_index = BWA_INDEX.out.bwa_indexed
        .combine(SAMTOOLS_FAIDX.out.fai)
        .map { fasta, amb, ann, bwt, pac, sa, fai ->
            tuple(fasta, amb, ann, bwt, pac, sa, fai)
        }

    emit:
    ref_with_index = ref_with_index
}
