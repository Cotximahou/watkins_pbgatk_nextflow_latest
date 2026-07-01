nextflow.enable.dsl = 2

include { PBGATK_GERMLINE }                                                    from './modules/local/pbgatk'
include { COMPRESS_AND_INDEX_VCF }                                             from './modules/local/compress_vcf'
include { GET_CONTIGS }                                                        from './modules/local/contigs'
include { EXTRACT_CONTIG_SAMPLE; MERGE_CONTIG_CHUNK;
          MERGE_CONTIG_FINAL; CONCAT_ALL_CONTIGS }                             from './modules/local/merge_contigs'
include { FLAGSTAT_CRAM }                                                      from './modules/local/flagstat'
include { PRECHECK_GPU_PROFILE_COUNTS }                                        from './modules/local/preflight'
include { BUILD_BWA_INDEX }                                                    from './modules/local/bwa_index'

params.samplesheet       = params.samplesheet       ?: null
params.ref               = params.ref               ?: null
params.outdir            = params.outdir            ?: 'results'
params.contig_subset     = params.contig_subset     ?: ''
params.merge_chunk_size  = (params.merge_chunk_size ?: 250) as int
params.run_flagstat      = (params.run_flagstat     ?: false) as boolean

workflow {

    if (!params.samplesheet) error "Missing --samplesheet"
    if (!params.ref)         error "Missing --ref"

    samplesheet_path = file(params.samplesheet, checkIfExists: true)

    PRECHECK_GPU_PROFILE_COUNTS(samplesheet_path)

    ref_file     = file(params.ref, checkIfExists: true)
    ref_indexed  = BUILD_BWA_INDEX(ref_file)

    // Full 7-tuple: (fasta, amb, ann, bwt, pac, sa, fai)
    ref_fa = ref_indexed.ref_with_index.first()

    // ---------------------------
    // SAMPLESHEET CHANNEL
    // ---------------------------
    ch_samples = Channel
        .fromPath(samplesheet_path)
        .splitCsv(header: true)
        .map { row ->
            tuple(
                row.sample_id.trim(),
                file(row.read1.trim(), checkIfExists: true),
                file(row.read2.trim(), checkIfExists: true),
                row.gpu_profile?.trim() ?: '1gpu'
            )
        }
        .groupTuple(by: 0)
        .map { sampleId, r1s, r2s, gpuProfiles ->
            tuple(sampleId, r1s, r2s, gpuProfiles[0])
        }
        .view { x -> "DEBUG CH_SAMPLES = ${x}" }

    // ---------------------------
    // GPU STEP
    // ---------------------------
    pbgatk_out     = PBGATK_GERMLINE(ch_samples, ref_fa)
    compressed_out = COMPRESS_AND_INDEX_VCF(pbgatk_out.vcf)

    compressed_out.vcfgz.view { "DEBUG COMPRESSED = ${it}" }

    // ---------------------------
    // CONTIG EXTRACTION
    // ---------------------------

    // FIX: GET_CONTIGS only needs the .fai (index 6 of the tuple).
    // Previously the full 7-tuple was passed but the process declared
    // a single `path ref` input, so only the FASTA was staged and
    // the *.fai glob in the script found nothing.
    contig_file = GET_CONTIGS(ref_fa.map { it[6] })

    ch_contigs = contig_file.contigs
        .splitText()
        .map  { it.trim() }
        .filter { it }

    if (params.contig_subset) {
        def allowed = params.contig_subset.split(/\s*,\s*/)
        ch_contigs = ch_contigs.filter { allowed.contains(it) }
    }

    // ---------------------------
    // CONTIG-SAMPLE CROSS
    // ---------------------------
    ch_contig_sample = ch_contigs
        .combine(compressed_out.vcfgz)
        .map { contig, sample_id, vcfgz, csi ->
            tuple(contig, sample_id, vcfgz, csi)
        }

    extracted = EXTRACT_CONTIG_SAMPLE(ch_contig_sample)

    // ---------------------------
    // CHUNK MERGING
    // ---------------------------
    ch_chunks = extracted.contig_vcfgz
        .groupTuple()
        .flatMap { contig, vcfList, csiList ->

            def pairs = [vcfList, csiList].transpose()

            pairs.collate(params.merge_chunk_size)
                .withIndex()
                .collect { chunk, idx ->
                    def vcfs = chunk.collect { it[0] }
                    def csis = chunk.collect { it[1] }
                    tuple(contig, idx + 1, vcfs.size(), vcfs, csis)
                }
        }

    chunk_out = MERGE_CONTIG_CHUNK(ch_chunks)

    // FIX: preserve CSI files through to MERGE_CONTIG_FINAL.
    // Previously csis were silently dropped in the .map(), which meant
    // MERGE_CONTIG_FINAL received un-indexed VCFs and bcftools merge failed.
    final_in = chunk_out.chunk_vcfgz
        .groupTuple()
        .map { contig, vcfs, csis ->
            // Sort both lists together so VCF/CSI pairs stay aligned
            def sorted = [vcfs, csis].transpose().sort { a, b -> a[0].name <=> b[0].name }
            tuple(contig, sorted.collect { it[0] }, sorted.collect { it[1] })
        }

    final_out = MERGE_CONTIG_FINAL(final_in)

    // FIX: channel was consumed twice (once for vcfs, once for csis).
    // In Nextflow DSL2 a channel can only be consumed once; the second
    // .map() on the same channel produced an empty channel, so
    // CONCAT_ALL_CONTIGS received no CSIs.
    // Collect all (contig, vcf, csi) tuples first, then split.
    ch_for_concat = final_out.contig_vcf.collect()

    vcfs_to_concat = ch_for_concat.map { tuples -> tuples.collect { it[1] } }
    csis_to_concat = ch_for_concat.map { tuples -> tuples.collect { it[2] } }

    CONCAT_ALL_CONTIGS(vcfs_to_concat, csis_to_concat)

    if (params.run_flagstat)
        FLAGSTAT_CRAM(pbgatk_out.cram)
}
