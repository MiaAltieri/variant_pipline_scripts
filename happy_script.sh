#!/bin/bash

# setting default args
TRUTH_VCF=""
FINAL_OUTPUT_VCF=""
CONFIDENT_BED=""
REF="missing"
HAPPY_OUTPUT=""
N_SHARDS=32
REGION="none"

# handeling arguments
for i in "$@"
do
case $i in
  --help*)
  echo 
  "These are deep variant options:
    REQUIRED:
      ref=<path_name> specifies reference, .fasta file

    OPTIONAL:
    specify output directories
      --truth_vcf=<path_name> specifies the truth vcf directory
          - defaults to 
      --final_output_vcf=<path_name> specifies the final output vcf directory 
          - defaults to 
      --confident_bed=<path_name> specifies the confident bed directory 
          - defaults to 
      --happy_output=<path_name> specifies the output directory for hap.py 
          - defaults to ./friday_outputs/vcf_output
      --region=<string> specifies region to run on
          - defaults to \"none\"
      --threads=<int> specifies number of threads
          - defaults to 32 
    "
    exit 1
    ;;
    ref=*)
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
    --threads=*)
    N_SHARDS="${i#*=}"
    shift 
    ;;
    *)
    UNKNOWN="${i}"
    echo "unknown symbol ${UNKNOWN}"
    echo 
    "usage: happy_script.sh [--help] ref=<path_name> [--truth_vcf=<path_name>] [--final_output_vcf=<path_name>]
      [--confident_bed=<path_name>] [--happy_output=<path_name>] [--region=<string>] [--threads=<int>]"
    exit 1
    ;;
esac
done

# checking for required arguments 
if [ "$REF" = "missing" ]
then
  echo "ref missing"
  echo 
  "usage: happy_script.sh [--help] ref=<path_name> [--truth_vcf=<path_name>] [--final_output_vcf=<path_name>]
    [--confident_bed=<path_name>] [--happy_output=<path_name>] [--region=<string>] [--threads=<int>]"
  exit 1
fi

# hap.py code 
sudo docker pull pkrusche/hap.py
mkdir -p ${HAPPY_OUTPUT}

if [ "$REGION" = "none" ]; then
  time sudo docker run -it -v  /data/:/data/ \
    pkrusche/hap.py /opt/hap.py/bin/hap.py \
    ${TRUTH_VCF} \
    "${FINAL_OUTPUT_VCF}" \
    -f "${CONFIDENT_BED}" \
    -r "${REF}" \
    -o "${HAPPY_OUTPUT}/chr20" \
    --engine=vcfeval \
    --threads=${N_SHARDS} \
else 
  time sudo docker run -it -v  /data/:/data/ \
    pkrusche/hap.py /opt/hap.py/bin/hap.py \
    ${TRUTH_VCF} \
    "${FINAL_OUTPUT_VCF}" \
    -f "${CONFIDENT_BED}" \
    -r "${REF}" \
    -o "${HAPPY_OUTPUT}/chr20" \
    --engine=vcfeval \
    --threads=${N_SHARDS} \
    -l "${REGION}"
fi
wait;
