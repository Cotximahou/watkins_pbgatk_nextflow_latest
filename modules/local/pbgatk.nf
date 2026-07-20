process PBGATK_GERMLINE {

    publishDir "${params.outdir}/cram", mode: 'copy', pattern: '*.cram'
    // raw per-sample VCF is kept only as an internal intermediate for compression/indexing
    // and is not published to results/vcf.

    // queue and clusterOptions are set in nextflow.config under withName: PBGATK_GERMLINE
    // to keep resource config centralised and avoid duplication.

    input:
    tuple val(sample_id), path(read1), path(read2), val(gpu_profile)
    tuple path(ref), path(ref_amb), path(ref_ann), path(ref_bwt), path(ref_pac), path(ref_sa), path(ref_fai)

    output:
    tuple val(sample_id), path("${sample_id}.cram"), emit: cram
    tuple val(sample_id), path("${sample_id}.vcf"),  emit: vcf

    script:
    def gpus = (gpu_profile ==~ /[124]gpu/)
            ? gpu_profile.replace('gpu', '') as int
            : (params.call_default_gpus as int)

    def runPartition = gpus > 1 ? '--run-partition' : ''

    def r1List  = (read1  instanceof List) ? read1  : [read1]
    def r2List  = (read2  instanceof List) ? read2  : [read2]

    if (r1List.size() != r2List.size()) {
        error "Sample ${sample_id}: read1/read2 count mismatch (${r1List.size()} vs ${r2List.size()})"
    }

    def sortedR1 = r1List.sort { it.name }
    def sortedR2 = r2List.sort { it.name }

    def inFqArgs = (0..<sortedR1.size()).collect { i ->
        "--in-fq ${sortedR1[i]} ${sortedR2[i]}"
    }.join(' ')

    """
    set -euo pipefail
    set -x

    echo "========== ENV =========="
    echo "HOSTNAME=\$(hostname)"
    echo "SLURM_JOB_ID=\${SLURM_JOB_ID:-UNSET}"
    echo "SLURM_LOCAL_SCRATCH=\${SLURM_LOCAL_SCRATCH:-UNSET}"
    echo "SLURM_TMPDIR=\${SLURM_TMPDIR:-UNSET}"
    echo "TMPDIR=\${TMPDIR:-UNSET}"
    nvidia-smi || true
    echo "========================="

    SCRATCH_BASE="\${SLURM_LOCAL_SCRATCH:-\${SLURM_TMPDIR:-\${TMPDIR:-/tmp}}}"
    SCRATCH_DIR="\${SCRATCH_BASE}/pbgatk_${sample_id}"

    mkdir -p "\$SCRATCH_DIR"
    echo "Using scratch: \$SCRATCH_DIR"

    # Check available scratch space before copying (fail fast with a clear message)
    AVAIL_KB=\$(df -k "\$SCRATCH_BASE" | awk 'NR==2{print \$4}')
    AVAIL_GB=\$(( AVAIL_KB / 1048576 ))
    echo "Available scratch: \${AVAIL_GB} GB"
    if [[ \$AVAIL_GB -lt 200 ]]; then
        echo "ERROR: Less than 200 GB of scratch space available (\${AVAIL_GB} GB). Aborting."
        exit 1
    fi

    cp -f ${ref}     "\$SCRATCH_DIR/${ref.name}"
    cp -f ${ref_amb} "\$SCRATCH_DIR/${ref.name}.amb"
    cp -f ${ref_ann} "\$SCRATCH_DIR/${ref.name}.ann"
    cp -f ${ref_bwt} "\$SCRATCH_DIR/${ref.name}.bwt"
    cp -f ${ref_pac} "\$SCRATCH_DIR/${ref.name}.pac"
    cp -f ${ref_sa}  "\$SCRATCH_DIR/${ref.name}.sa"
    cp -f ${ref_fai} "\$SCRATCH_DIR/${ref.name}.fai"

    echo "Reference copied to scratch."

    pbrun germline \\
        --ref            "\$SCRATCH_DIR/${ref.name}" \\
        ${inFqArgs} \\
        --out-bam        "\$SCRATCH_DIR/${sample_id}.cram" \\
        --tmp-dir        "\$SCRATCH_DIR" \\
        --out-variants   "\$SCRATCH_DIR/${sample_id}.vcf" \\
        ${runPartition} \\
        --num-gpus       ${gpus} \\
        --num-htvc-threads ${params.call_htvc_threads} \\
        --read-group-sm  ${sample_id} \\
        --read-group-pl  ILLUMINA \\
        --read-group-id-prefix ${sample_id} \\
        --x3

    ls -lh "\$SCRATCH_DIR"

    cp "\$SCRATCH_DIR/${sample_id}.cram" .
    cp "\$SCRATCH_DIR/${sample_id}.vcf"  .
    """
}
