#!/bin/bash

# setting default arguments
BIN_VERSION="0.7.2"
MODEL_VERSION="0.7.2"
N_SHARDS=32
RUN="gpu"
SAMPLE_NAME="NA12878"
OUTPUT_DIR=./deepvariant_outputs/
VCF_OUTPUT_DIR=./deepvariant_outputs/vcf_outputs
LOGDIR=./deepvariant_outputs/logs

REF="missing"
BAM="missing"
MODEL="missing"
REGION="missing"


# handeling arguments
for i in "$@"
do
case $i in
  --help*)
  echo 
  "These are deep variant options:
    REQUIRED:
      model=<path_name> specifies model, .pkl file
      ref=<path_name> specifies reference, .fasta file
      bam=<path_name> specifies bam file, .bam file
      sample_name=<string> specifies which sample
      region=<string> specifies region to run on
          - defaults to \"\"

    OPTIONAL:
    specify output directories
      --bin_vs=<path_name> specifies the bin version 
          - defaults to \"0.7.2\"
      --model_vs=<path_name> specifies the model version 
          - defaults to \"0.7.2\"
      --output=<path_name> specifies the output directory 
          - defaults to ./friday_outputs
      --output_vcf=<path_name> specifies the output directory for vcf file 
          - defaults to ./friday_outputs/vcf_output
      --log_dir=<path_name> specifies the log directory
          - defaults to ./deepvariant_outputs/logs
      --threads=<int> specifies number of threads
          - defaults to 32 
      gpu specifies to run using gpus (default setting)
      cpu specifies to run using cpu
    "
    exit 1
    ;;
    ref=*)
    REF="${i#*=}"
    shift
    ;;
    bam=*)
    BAM="${i#*=}"
    shift
    ;;
    model=*)
    MODEL="${i#*=}"
    shift
    ;;
    sample_name=*)
    SAMPLE_NAME="${i#*=}"
    shift
    ;;
    --bin_vs=*)
    BIN_VERSION="${i#*=}"
    shift
    ;;
    --model_vs=*)
    MODEL_VERSION="${i#*=}"
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
    region=*)
    REGION="${i#*=}"
    shift 
    ;;
    gpu*)
    RUN="${i#*=}"
    shift 
    ;;
    cpu*)
    RUN="${i#*=}"
    shift 
    ;;
    *)
    UNKNOWN="${i#*=}"
    echo "unknown symbol ${UNKNOWN}"
    echo 
    "usage: deep_variant_pipeline.sh [--help] model=<path_name> ref=<path_name> bam=<path_name>
      region=<string> [sample_name=<string>] [--bin_vs=<path_name>] [--model_vs=<path_name>] 
      [--output=<path_name>] [--output_vcf=<path_name>] [--log_dir=<path_name>] [--threads=<int>]
      [gpu || cpu]"
    exit 1
    ;;
esac
done

# checking for required arguments 
if [ "$REF" = "missing" ] || [ "$BAM" = "missing" ] || [ "$MODEL" = "missing" ] || [ "$REGION" = "missing" ]
then
  echo "bam, ref, region, or model missing"
  echo 
  "usage: deep_variant_pipeline.sh [--help] model=<path_name> ref=<path_name> bam=<path_name>
    region=<string> [sample_name=<string>] [--bin_vs=<path_name>] [--model_vs=<path_name>] 
    [--output=<path_name>] [--output_vcf=<path_name>] [--log_dir=<path_name>] [--threads=<int>]
    [gpu || cpu]"
  exit 1
fi

REF_NAME="$(basename "${REF}")"
FINAL_OUTPUT_VCF=${VCF_OUTPUT_DIR}/${REF_NAME}

echo "Starting DeepVariant with the following settings"
echo "Bin version             = ${BIN_VERSION}"
echo "Model version           = ${MODEL_VERSION}"
echo "Output dir              = ${OUTPUT_DIR}"
echo "VCF Output dir          = ${VCF_OUTPUT_DIR}"
echo "Final VCF Output dir    = ${FINAL_OUTPUT_VCF}"
echo "Log dir                 = ${LOGDIR}"
echo "Region                  = ${REGION}"
echo "Reference               = ${REF}"
echo "Bam                     = ${BAM}"
echo "Model                   = ${MODEL}"
echo "Threads                 = ${N_SHARDS}"
echo "GPU/CPU                 = ${RUN}"

# initializing directories 
mkdir -p ${OUTPUT_DIR}
mkdir -p ${VCF_OUTPUT_DIR}
mkdir -p ${LOGDIR}

sudo docker pull gcr.io/deepvariant-docker/deepvariant:${BIN_VERSION}
wait;

# create images
time seq 0 $((N_SHARDS-1)) | \
  parallel --eta --halt 2 --joblog ${LOGDIR}/log --res ${LOGDIR} \
  sudo docker run \
    -v  ${HOME}:${HOME}    \
    gcr.io/deepvariant-docker/deepvariant:${BIN_VERSION} \
    /opt/deepvariant/bin/make_examples \
    --mode calling \
    --ref ${REF} \
    --reads ${BAM} \
    --sample_name ${SAMPLE_NAME} \
    --examples ${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz \
    --regions "${REGION}" \
    --task {}
wait;

# call variants
CALL_VARIANTS_OUTPUT="${OUTPUT_DIR}/call_variants_output.tfrecord.gz"
wait;

# runs on GPUs unless CPU specified 
if [ "$RUN" = "gpu" ]; then
  time sudo nvidia-docker run \
    -v /data/:/data/ \
    gcr.io/deepvariant-docker/deepvariant_gpu:"${BIN_VERSION}" \
    /opt/deepvariant/bin/call_variants \
    --outfile "${CALL_VARIANTS_OUTPUT}" \
    --examples "${OUTPUT_DIR}"/examples.tfrecord@"${N_SHARDS}".gz \
    --checkpoint "${MODEL}"
  wait;
else
  time sudo docker run \
    -v  ${HOME}:${HOME} \
    gcr.io/deepvariant-docker/deepvariant:"${BIN_VERSION}" \
    /opt/deepvariant/bin/call_variants \
    --outfile "${CALL_VARIANTS_OUTPUT}" \
    --examples "${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz" \
    --checkpoint "${MODEL}"
  wait;
fi


# postprocess variants
time sudo docker run \
   -v  ${HOME}:${HOME} \
   gcr.io/deepvariant-docker/deepvariant:"${BIN_VERSION}" \
   /opt/deepvariant/bin/postprocess_variants \
   --ref "${REF}" \
   --infile "${CALL_VARIANTS_OUTPUT}" \
   --outfile $"{FINAL_OUTPUT_VCF}"
wait;

echo "Call hap.py Script"