#!/bin/bash
#SBATCH --job-name=watkins_nf
#SBATCH --output=slurm_logs/%x_%j.out
#SBATCH --error=slurm_logs/%x_%j.err
#SBATCH --time=20-00:00:00
#SBATCH -c 4
#SBATCH --mem=32G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=luk24miz@nbi.ac.uk
#SBATCH --partition=jic-long

set -euo pipefail

# -----------------------------
# Contigs to analyse
# -----------------------------

if [[ $# -gt 0 ]]; then
    CONTIGS="$1"
else
    CONTIGS=$(printf "%s," \
        1A 1B 1D \
        2A 2B 2D \
        3A 3B 3D \
        4A 4B 4D \
        5A 5B 5D \
        6A 6B 6D \
        7A 7B 7D | sed 's/,$//')
fi

echo "Using contigs: $CONTIGS"


# -----------------------------
# Work directory
# -----------------------------
cd /jic/scratch/platforms/informatics/luk24miz/nextflow/watkins_pbgatk_nextflow

# -----------------------------
# Create dirs early (important for SLURM logging)
# -----------------------------
mkdir -p slurm_logs results singularity_cache

# -----------------------------
# Conda (SLURM-safe activation)
# -----------------------------
source $(conda info --base)/etc/profile.d/conda.sh
conda activate nf-env

# -----------------------------
# Nextflow environment
# -----------------------------
export NXF_OFFLINE=true
export NXF_SINGULARITY_CACHEDIR=$PWD/singularity_cache
export NXF_OPTS="-Xms4g -Xmx24g"

# optional but useful for debugging/resume stability
export NXF_WORK=$PWD/work

# -----------------------------
# Run pipeline
# -----------------------------

nextflow run main.nf \
  -profile slurm,singularity_offline \
  -resume \
  --local_container_dir $PWD/containers \
  --samplesheet $PWD/samplesheet.csv \
  --ref /jic/scratch/platforms/informatics/reference_genomes/Triticum_aestivum-Julius_EnsemblPlants_release63/Triticum_aestivum_julius.PGSBv2.1.dna.toplevel.fa \
  ${CONTIGS:+--contig_subset "$CONTIGS"} \
  --outdir results

