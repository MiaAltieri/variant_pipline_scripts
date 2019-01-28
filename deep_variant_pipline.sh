#!/bin/bash



# default args
BIN_VERSION="0.7.2"
MODEL_VERSION="0.7.2"

OUTPUT_DIR=./deepvariant_outputs/
VCF_OUTPUT_DIR=./deepvariant_outputs/vcf_outputs
LOGDIR=./deepvariant_outputs/logs

REF="missing"
BAM="missing"
MODEL="missing"

REGION=""
N_SHARDS=32
RUN="gpu"
SAMPLE_NAME="NA12878"

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
      --region=<string> specifies region to run on
          - defaults to \"\" 
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
    echo "usage: deep_variant_pipeline.sh [--help] model=<path_name> ref=<path_name> bam=<path_name>
          [sample_name=<string>] [--bin_vs=<path_name>] [--model_vs=<path_name>] 
          [--output=<path_name>] [--output_vcf=<path_name>] [--log_dir=<path_name>] 
          [--threads=<int>] [--region=<string>] [gpu || cpu]"
    exit 1
    ;;
esac
done

 
if [ $REF == 'missing' ] || [ $BAM == 'missing' ] || [ $MODEL == 'missing' ]
then
  echo "bam, ref, or model missing"
  echo "usage: deep_variant_pipeline.sh [--help] model=<path_name> ref=<path_name> bam=<path_name>
    [sample_name=<string>] [--bin_vs=<path_name>] [--model_vs=<path_name>] 
    [--output=<path_name>] [--output_vcf=<path_name>] [--log_dir=<path_name>] 
    [--threads=<int>] [--region=<string>] [gpu || cpu]"
  exit 1
fi



REF_NAME="${basename ${REF}}"
FINAL_OUTPUT_VCF=${VCF_OUTPUT_DIR}/{REF_NAME}

echo "Starting DeepVariant with the following settings"
echo "Bin version      = ${BIN_VERSION}"
echo "Model version    = ${MODEL_VERSION}"
echo "Output dir         = ${OUTPUT_DIR}"
echo "VCF Output dir      = ${VCF_OUTPUT_DIR}"
echo "Final VCF Output dir    = ${FINAL_OUTPUT_VCF}"
echo "Log dir            = ${LOGDIR}"
echo "Region            = ${REGION}"
echo "Reference      = ${REF}"
echo "Bam        = ${BAM}"
echo "Model        = ${MODEL}"
echo "Threads         = ${N_SHARDS}"
echo "GPU/CPU        = ${RUN}"


mkdir -p ${OUTPUT_DIR}
mkdir -p ${VCF_OUTPUT_DIR}
mkdir -p ${LOGDIR}


echo "============== docker pull ============== "
sudo docker pull gcr.io/deepvariant-docker/deepvariant:${BIN_VERSION}
wait;
echo "============== docker pull end ============== "


echo "============== create image ============== "
# create images
time seq 0 $((N_SHARDS-1)) | \
  parallel --eta --halt 2 --joblog ${LOGDIR}/log --res ${LOGDIR} \
  sudo docker run \
    -v /data/:/data/ \
    gcr.io/deepvariant-docker/deepvariant:${BIN_VERSION} \
    /opt/deepvariant/bin/make_examples \
    --mode calling \
    --ref ${REF} \
    --reads ${BAM} \
    --sample_name ${SAMPLE_NAME} \
    --examples ${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz \
    --regions '"ch20:10,000,000-10,010,000"' \
    --task {}
wait;
echo "============== create image end ============== "

echo "============== calling call variant output ============== "
CALL_VARIANTS_OUTPUT=${OUTPUT_DIR}/call_variants_output.tfrecord.gz
wait;

time sudo docker run \
  -v /data/:/data/ \
  gcr.io/deepvariant-docker/deepvariant:${BIN_VERSION} \
  /opt/deepvariant/bin/call_variants \
 --outfile ${CALL_VARIANTS_OUTPUT} \
 --examples ${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz \
 # --regions "chr20:10,000,000-10,010,000" \
 --checkpoint ${MODEL}
wait;
echo "============== calling call variant output end ============== "

echo "============== 1 ============== "
time sudo docker run \
   -v /data/:/data/ \
   gcr.io/deepvariant-docker/deepvariant:${BIN_VERSION} \
   /opt/deepvariant/bin/postprocess_variants \
   --ref ${REF} \
   --infile ${CALL_VARIANTS_OUTPUT} \
   # --regions "chr20:10,000,000-10,010,000" \
   --outfile ${FINAL_OUTPUT_VCF}
wait;
echo "============== 1 end ============== "

echo "============== 2 ============== "
# HAP.PY code
sudo docker pull pkrusche/hap.py
TRUTH_VCF=/data/users/common/vcf/HG001_GRCh37.vcf.gz
CONFIDENT_BED=/data/users/common/bed/HG001_GRCh37.bed
HAPPY_OUTPUT=/data/users/mgaltier/deepvariant_outputs/happy_output/pfda_hg001_grch37
mkdir -p ${HAPPY_OUTPUT}
echo "============== 2 end ============== "

echo "============== 3 ============== "
time sudo docker run -it -v /data/:/data/ \
  pkrusche/hap.py /opt/hap.py/bin/hap.py \
  ${TRUTH_VCF} \
  ${FINAL_OUTPUT_VCF} \
  -f ${CONFIDENT_BED} \
  -r ${REF} \
  -o ${HAPPY_OUTPUT}/deepvariant_hg001_grch37 \
   # --regions "chr20:10,000,000-10,010,000" \
  --engine=vcfeval \
  --threads=${N_SHARDS} \
  -l 19
wait;
echo "============== 3 end ============== "