// FIX: input is now the .fai file only (not the full 7-tuple ref channel).
// The script uses awk on the staged .fai directly instead of a glob,
// which is more robust and avoids staging the entire reference FASTA
// just to read a small index file.

process GET_CONTIGS {
    label 'cpu_small'
    container params.container_bcftools

    input:
    path fai   // just the .fai — passed as: ref_fa.map { it[6] }

    output:
    path 'contigs.txt', emit: contigs

    script:
    """
    awk '{print \$1}' ${fai} > contigs.txt
    """
}
