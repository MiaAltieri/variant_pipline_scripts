#!/bin/bash

# default arguments
FRIDAY_PATH="./software/friday"
OUTPUT_DIR="./friday_outputs"
VCF_OUTPUT_DIR="./friday_outputs/vcf_output"
CHR_NAME="1-22,X,Y"
GPU_MODE=1
N_SHARDS=64
BATCH_SIZE=1024
DOWNLOAD_FRIDAY="no"

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
	"These are friday options used in various situations:
		REQUIRED:
			model=<path_name> specifies model, .pkl file
			ref=<path_name> specifies reference, .fasta file
			bam=<path_name> specifies bam file, .bam file
			sample_name=<string> specifies which sample

		OPTIONAL:
		specify output directories
			--friday_location=<path_name> specifies where friday is stored on your computer
		   		- assumes ./software/friday	
			--output=<path_name> specifies the output directory 
		   		- defaults to ./friday_outputs
		   	--output_vcf=<path_name> specifies the output directory for vcf file 
		   		- defaults to ./friday_outputs/vcf_output
		   	--threads=<int> specifies number of threads
		   		- defaults to 32	
		   	--chr_name=<int> specifies chromsomes to run on
		   		- defaults to 1-22,X,Y
		   	--gpu_mode=<int> specifies the gpu mode to run on
		   		- defaults to 1
		   	--batch_size=<int> specifies the batch size
		   		- defaults to 1024
            --download_friday=<yes|no> specifies whether or not to download and build friday
                - \"no\"
	"
		exit 1
	;;
    --friday_location=*)
    FRIDAY_PATH="${i#*=}"
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
    --chr_name=*)
    CHR_NAME="${i#*=}"
    shift
    ;;
    --gpu_mode=*)
    GPU_MODE="${i#*=}"
    shift
    ;;
    --sample_name=*)
    SAMPLE_NAME="${i#*=}"
    shift
    ;;
    --batch_size=*)
    BATCH_SIZE="${i#*=}"
    shift
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
    threads=*)
    N_SHARDS="${i#*=}"
    shift 
    ;;
    --download_friday=*)
    DOWNLOAD_FRIDAY="${i#*=}"
    shift 
    ;;
    
    *)
    echo 
    "usage: friday_pipeline [--help] ref=<path_name> bam=<path_name> model=<path_name> 
        sample_name=<string> [--friday_location=<path_name>] [--output=<path_name>]
        [--output_vcf=<path_name>] [chr_name=<string>] [threads=<path_name>] 
        [--batch_size=<int>] [--download_friday=<yes|no>]"
    exit 1
    ;;
esac
done

# checking for required arguments 
if [ "$REF" = 'missing' ] || [ "$BAM" = 'missing' ] || [ "$MODEL" = 'missing' ] || [ "$SAMPLE_NAME" = 'missing' ]
then
	echo "bam, ref, model, or sample missing"
    echo 
    "usage: friday_pipeline [--help] ref=<path_name> bam=<path_name> model=<path_name> 
        sample_name=<string> [--friday_location=<path_name>] [--output=<path_name>]
        [--output_vcf=<path_name>] [chr_name=<string>] [threads=<path_name>] 
        [--batch_size=<int>] [--download_friday=<yes|no>]"
    exit 1
fi

echo "Starting Friday with the following settings:"
echo "FRIDAY location 		= ${FRIDAY_PATH}"
echo "Output dir     		= ${OUTPUT_DIR}"
echo "VCF Output dir 		= ${VCF_OUTPUT_DIR}"
echo "Chromosome regions 	= ${CHR_NAME}"
echo "Reference				= ${REF}"
echo "Model					= ${MODEL}"
echo "Threads				= ${N_SHARDS}"
echo "GPU mode 				= ${GPU_MODE}"
echo "Sample name 			= ${SAMPLE_NAME}"
echo "Threads 				= ${N_SHARDS}"
echo "Batch size 			= ${BATCH_SIZE}"
echo "Download FRIDAY       = ${DOWNLOAD_FRIDAY}"


if [ "$DOWNLOAD_FRIDAY" = 'true' ]; then
    # set up cmake
    wget --no-check-certificate https://cmake.org/files/v3.12/cmake-3.12.0-Linux-x86_64.tar.gz
    tar -xvf cmake-3.12.0-Linux-x86_64.tar.gz
    mv cmake-3.12.0-Linux-x86_64 cmake-install
    PATH=$(pwd)/cmake-install:$(pwd)/cmake-install/bin:$PATH
    # check cmake version to be 3.12
    cmake --version

    # considering python3 is installed
    # htslib dependencies
    sudo apt-get install python3-dev gcc g++ make autoconf python3-pip libcurl4-openssl-dev
    sudo apt-get install autoconf automake make gcc perl zlib1g-dev libbz2-dev liblzma-dev libcurl4-gnutls-dev libssl-dev
    python3 -m pip install h5py graphviz pandas

    # install the proper version of pytorch from https://pytorch.org/
    git clone https://github.com/kishwarshafin/friday.git
    cd friday
    ./build.sh
fi






# generate image
time seq 0 $((N_SHARDS-1)) | time parallel --ungroup python3 ${FRIDAY_PATH}/generate_images.py \
    --bam ${BAM} \
    --fasta ${REF}\
    --threads ${N_SHARDS} \
    --chromosome_name ${CHR_NAME} \
    --sample_name ${SAMPLE_NAME} \
    --output_dir ${OUTPUT_DIR} \
    --thread_id {}
wait;

# CSV PROCESSING
# THIS IS EMBARASSING, NEED TO HANDLE THIS INSIDE IMAGE GENERATION :-(
mkdir -p ${OUTPUT_DIR}
cd ${OUTPUT_DIR}

for i in `seq 1 22`;
do
  cat ${i}_*.csv > ${i}.csv
done
cat X_* > X.csv
cat Y_* > Y.csv
rm -rf X_*
rm -rf Y_*
wait;

# variant calling
time python3 call_variants.py \
	--csv_dir ${OUTPUT_DIR} \
	--bam_file ${BAM} \
	--chromosome_name ${CHR_NAME} \
	--batch_size ${BATCH_SIZE} \
	--num_workers ${N_SHARDS} \
	--model_path ${MODEL} \
	--gpu_mode ${GPU_MODE} \
	--output_dir ${VCF_OUTPUT_DIR}
wait;

echo "Call hap.py Script"
