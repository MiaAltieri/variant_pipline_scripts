#!/bin/bash

# setting default arguments
BIN_VERSION="0.7.2"
N_SHARDS=32
MODE="GPU"
OUTPUT_DIR=./deepvariant_outputs/
VCF_OUTPUT_DIR=./deepvariant_outputs/vcf_outputs
LOGDIR=./deepvariant_outputs/logs
REGION="none"
MOUNT="/data/:/data/"

REF="missing"
BAM="missing"
MODEL="missing"
SAMPLE_NAME="missing"


# handeling arguments
for i in "$@"
do
case $i in
  --help*)
  echo 
  "These are deep variant options:
    REQUIRED:
      --model=<path_name> specifies model, .pkl file
      --ref=<path_name> specifies reference, .fasta file
      --bam=<path_name> specifies bam file, .bam file
      --sample_name=<string> specifies which sample

    OPTIONAL:
    specify output directories
      --bin_version=<path_name> specifies the bin and model version 
          - defaults to \"0.7.2\"
      --output=<path_name> specifies the output directory 
          - defaults to ./friday_outputs
      --output_vcf=<path_name> specifies the output directory for vcf file 
          - defaults to ./friday_outputs/vcf_output
      --log_dir=<path_name> specifies the log directory
          - defaults to ./deepvariant_outputs/logs
      --threads=<int> specifies number of threads
          - defaults to 32 
      --region=<string> specifies region to run on
          - defaults to \"none\"
      --mode=<string> specifies to run using GPU or CPU
          - defaults to GPU
      --mount=<string> specifies the mount point 
          - defaults to /data/:/data/
    "
    exit 1
    ;;
    --ref=*)
    REF="${i#*=}"
    shift
    ;;
    --bam=*)
    BAM="${i#*=}"
    shift
    ;;
    --model=*)
    MODEL="${i#*=}"
    shift
    ;;
    --sample_name=*)
    SAMPLE_NAME="${i#*=}"
    shift
    ;;
    --bin_version=*)
    BIN_VERSION="${i#*=}"
    shift
    ;;
    --output=*)
    OUTPUT_DIR="${i#*=}"
    shift
    ;;
    --output_vcf=*)
    VCF_OUTPUT_DIR="${i#*=}"
    shift
    ;;
    --log_dir=*)
    LOGDIR="${i#*=}"
    shift
    ;;
    --threads=*)
    N_SHARDS="${i#*=}"
    shift 
    ;;
    --region=*)
    REGION="${i#*=}"
    shift 
    ;;
    --mode=*)
    MODE="${i#*=}"
    shift 
    ;;
    --mount=*)
    MOUNT="${i#*=}"
    shift 
    ;;
    *)
    UNKNOWN="${*}"
    echo "unknown symbol ${UNKNOWN}"
    echo 
    "usage: deep_variant_pipeline.sh [--help] --model=<path_name> --ref=<path_name> 
      --bam=<path_name> --sample_name=<string> [--region=<string>] [--bin_version=<path_name>] 
      [--output=<path_name>] [--output_vcf=<path_name>] [--log_dir=<path_name>] [--threads=<int>]
      [--mode=<string>] [--mount=<string>]"
    exit 1
    ;;
esac
done

# checking for required arguments 
if [ "$REF" = "missing" ] || [ "$BAM" = "missing" ] || [ "$MODEL" = "missing" ]
then
  echo "bam, model, or ref missing"
  echo 
  "usage: deep_variant_pipeline.sh [--help] --model=<path_name> --ref=<path_name> 
    --bam=<path_name> --sample_name=<string> [--region=<string>] [--bin_version=<path_name>] 
    [--output=<path_name>] [--output_vcf=<path_name>] [--log_dir=<path_name>] [--threads=<int>]
    [--mode=<string>] [--mount=<string>]"
  exit 1
fi

REF_NAME="$(basename "${REF}" .fasta)"
FINAL_OUTPUT_VCF=${VCF_OUTPUT_DIR}/${REF_NAME}.vcf/gz

echo "Starting DeepVariant with the following settings"
echo "Bin version             = ${BIN_VERSION}"
echo "Output dir              = ${OUTPUT_DIR}"
echo "VCF Output dir          = ${VCF_OUTPUT_DIR}"
echo "Final VCF output file   = ${FINAL_OUTPUT_VCF}"
echo "Log dir                 = ${LOGDIR}"
echo "Region                  = ${REGION}"
echo "Reference               = ${REF}"
echo "Bam                     = ${BAM}"
echo "Model                   = ${MODEL}"
echo "Threads                 = ${N_SHARDS}"
echo "Mode                    = ${MODE}"
echo "Mount point             = ${MODE}"

# initializing directories 
mkdir -p ${OUTPUT_DIR}
mkdir -p ${VCF_OUTPUT_DIR}
mkdir -p ${LOGDIR}

sudo docker pull gcr.io/deepvariant-docker/deepvariant:${BIN_VERSION}
wait;

# create images
if [ "$REGION" = "none" ]; then
  time seq 0 $((N_SHARDS-1)) | \
    parallel --eta --halt 2 --joblog ${LOGDIR}/log --res ${LOGDIR} \
    sudo docker run \
      -v ${MOUNT}    \
      gcr.io/deepvariant-docker/deepvariant:${BIN_VERSION} \
      /opt/deepvariant/bin/make_examples \
      --mode calling \
      --ref ${REF} \
      --reads ${BAM} \
      --sample_name ${SAMPLE_NAME} \
      --examples ${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz \
      --task {}
else
  time seq 0 $((N_SHARDS-1)) | \
    parallel --eta --halt 2 --joblog ${LOGDIR}/log --res ${LOGDIR} \
    sudo docker run \
      -v ${MOUNT}    \
      gcr.io/deepvariant-docker/deepvariant:${BIN_VERSION} \
      /opt/deepvariant/bin/make_examples \
      --mode calling \
      --ref ${REF} \
      --reads ${BAM} \
      --sample_name ${SAMPLE_NAME} \
      --examples ${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz \
      --regions "${REGION}" \
      --task {}
fi
wait;

# call variants
CALL_VARIANTS_OUTPUT="${OUTPUT_DIR}/call_variants_output.tfrecord.gz"
wait;

# runs on GPUs unless CPU specified 
if [ "$MODE" = "GPU" ]; then
  time sudo nvidia-docker run \
    -v ${MOUNT} \
    gcr.io/deepvariant-docker/deepvariant_gpu:"${BIN_VERSION}" \
    /opt/deepvariant/bin/call_variants \
    --outfile "${CALL_VARIANTS_OUTPUT}" \
    --examples "${OUTPUT_DIR}"/examples.tfrecord@"${N_SHARDS}".gz \
    --checkpoint "${MODEL}"
else
  time sudo docker run \
    -v ${MOUNT} \
    gcr.io/deepvariant-docker/deepvariant:"${BIN_VERSION}" \
    /opt/deepvariant/bin/call_variants \
    --outfile "${CALL_VARIANTS_OUTPUT}" \
    --examples "${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz" \
    --checkpoint "${MODEL}"
fi
wait;


# postprocess variants
time sudo docker run \
   -v ${MOUNT} \
   gcr.io/deepvariant-docker/deepvariant:"${BIN_VERSION}" \
   /opt/deepvariant/bin/postprocess_variants \
   --ref "${REF}" \
   --infile "${CALL_VARIANTS_OUTPUT}" \
   --outfile "${FINAL_OUTPUT_VCF}"
wait;

echo "Call hap.py script"
