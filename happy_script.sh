#!/bin/bash

# setting default args
TRUTH_VCF="missing "
FINAL_OUTPUT_VCF="missing"
CONFIDENT_BED="missing"
REF="missing"
HAPPY_OUTPUT="missing"

N_SHARDS=32
REGION="none"
MOUNT="/data/:/data/"

# handeling arguments
for i in "$@"
do
case $i in
  --help*)
  echo 
  "These are deep variant options:
    REQUIRED:
      --ref=<path_name> specifies reference, .fasta file
      --truth_vcf=<path_name> specifies the truth vcf directory
      --final_output_vcf=<path_name> specifies the final vcf file 
      --confident_bed=<path_name> specifies the confident bed directory 
      --output=<path_name> specifies the output directory for hap.py 

    OPTIONAL:
      --region=<string> specifies region to run on
          - defaults to \"none\"
      --mount=<string> specifies the mount point 
          - defaults to /data/:/data/
      --threads=<int> specifies number of threads
          - defaults to 32 
    "
    exit 1
    ;;
    --ref=*)
    REF="${i#*=}"
    shift
    ;;
    --truth_vcf=*)
    TRUTH_VCF="${i#*=}"
    shift
    ;;
    --final_output_vcf=*)
    FINAL_OUTPUT_VCF="${i#*=}"
    shift
    ;;
    --confident_bed=*)
    CONFIDENT_BED="${i#*=}"
    shift
    ;;
    --happy_output=*)
    HAPPY_OUTPUT="${i#*=}"
    shift
    ;;
    --region=*)
    REGION="${i#*=}"
    shift 
    ;;
    --mount=*)
    MOUNT="${i#*=}"
    shift 
    ;;
    --threads=*)
    N_SHARDS="${i#*=}"
    shift 
    ;;
    *)
    UNKNOWN="${i}"
    echo "unknown symbol ${UNKNOWN}"
    echo 
    "usage: happy_script.sh [--help] --ref=<path_name> [--truth_vcf=<path_name>] [--final_output_vcf=<path_name>]
      [--confident_bed=<path_name>] [--happy_output=<path_name>] [--mount=<string>] [--region=<string>]
      [--threads=<int>]"
    exit 1
    ;;
esac
done

# checking for required arguments 
if [ "$REF" = "missing" ]  || [ "$TRUTH_VCF" = "missing" ] || [ "$FINAL_OUTPUT_VCF" = "missing" ] || [ "$CONFIDENT_BED" = "missing" ] || [ "$HAPPY_OUTPUT" = "missing" ]
then
  echo "ref, truth vcf, final output, confident_bed, or output missing"
  echo
  "usage: happy_script.sh [--help] --ref=<path_name> [--truth_vcf=<path_name>] [--final_output_vcf=<path_name>]
    [--confident_bed=<path_name>] [--happy_output=<path_name>] [--mount=<string>] [--region=<string>]
    [--threads=<int>]"
  exit 1
fi


CHR_NAME="$(basename "${FINAL_OUTPUT_VCF}" .vcf.gz)"

# hap.py code 
sudo docker pull pkrusche/hap.py
mkdir -p ${HAPPY_OUTPUT}

if [ "$REGION" = "none" ]; then
  time sudo docker run -it -v ${MOUNT} \
    pkrusche/hap.py /opt/hap.py/bin/hap.py \
    ${TRUTH_VCF} \
    "${FINAL_OUTPUT_VCF}" \
    -f "${CONFIDENT_BED}" \
    -r "${REF}" \
    -o "${HAPPY_OUTPUT}/chr20" \
    --engine=vcfeval \
    --threads=${N_SHARDS}
else 
  time sudo docker run -it -v ${MOUNT} \
    pkrusche/hap.py /opt/hap.py/bin/hap.py \
    ${TRUTH_VCF} \
    "${FINAL_OUTPUT_VCF}" \
    -f "${CONFIDENT_BED}" \
    -r "${REF}" \
    -o "${HAPPY_OUTPUT}/${CHR_NAME}" \
    --engine=vcfeval \
    --threads=${N_SHARDS} \
    -l "${REGION}"
fi
wait;
