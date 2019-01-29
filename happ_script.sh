# default args
TRUTH_VCF="missing"
FINAL_OUTPUT_VCF=""
CONFIDENT_BED="missing"
REF="missing"
HAPPY_OUTPUT=""
N_SHARDS=32
REGION=""



# handeling arguments
for i in "$@"
do
case $i in
  --help*)
  echo 
  "These are deep variant options:
    REQUIRED:
      ref=<path_name> specifies reference, .fasta file
      --truth_vcf=<path_name> specifies the truth vcf file, (.vcf.gz)
      --confident_bed=<path_name> specifies the confident bed file (.bed)

    OPTIONAL:
      --final_ouput_vcf=<path_name> specifies the final output vcf directory 
          - defaults to 
      --happy_output=<path_name> specifies the output directory for hap.py 
          - defaults to ./friday_outputs/vcf_output
      --threads=<int> specifies number of threads
          - defaults to 32 
      --region=<string> specifies region to run on
          - defaults to \"\" 
    "
    exit 1
    ;;
    ref=*)
    REF="${i#*=}"
    shift
    ;;
    --truth_vcft=*)
    TRUTH_VCF="${i#*=}"
    shift
    ;;
    --final_ouput_vcf=*)
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
    region=*)
    REGION="${i#*=}"
    shift 
    ;;
    --threads=*)
    N_SHARDS="${i#*=}"
    shift 
    ;;
    *)
    UNKNOWN="${i#*=}"
    echo "unknown symbol ${UNKNOWN}"
	echo "usage: happy_script.sh [--help] ref=<path_name> --truth_vcf=<path_name> --confident_bed=<path_name> 
	[--final_ouput_vcf=<path_name>] [--happy_output=<path_name>] [--threads=<int>] [--region=<string>"
    exit 1
    ;;
esac
done

 
if [ $REF == 'missing' ] || [ $TRUTH_VCF == 'missing' ] || [ $CONFIDENT_BED == 'missing' ]
then
  echo "bam, truth vcf, or confident bed missing"
  echo "usage: happy_script.sh [--help] ref=<path_name> --truth_vcf=<path_name> --confident_bed=<path_name> 
  [--final_ouput_vcf=<path_name>] [--happy_output=<path_name>] [--threads=<int>] [--region=<string>"
  exit 1
fi



# HAP.PY code
sudo docker pull pkrusche/hap.py
mkdir -p ${HAPPY_OUTPUT}

echo "============== 3 ============== "
time sudo docker run -it -v /data/:/data/ \
  pkrusche/hap.py /opt/hap.py/bin/hap.py \
  ${TRUTH_VCF} \
  ${FINAL_OUTPUT_VCF} \
  -f ${CONFIDENT_BED} \
  -r ${REF} \
  -o ${HAPPY_OUTPUT} \
  --engine=vcfeval \
  --threads=${N_SHARDS} \
  -l chr20:10000000-10010000
wait;
echo "============== 3 end ============== "