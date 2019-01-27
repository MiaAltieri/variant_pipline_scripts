#!/bin/bash

# default arguements
FRIDAY="./software/friday"
OUTPUT="./friday_outputs"
OUTPUTVCF="./friday_outputs/vcf_output"
CHRSTART=1
CHREND=22
REF="missing"
BAM="missing"
MODEL="missing"
THREADS=32

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
			sample-name=<string> specifies which sample

		OPTIONAL:
		specify output directories
			--friday-location=<path_name> specifies where friday is stored on your computer
		   		- assumes ./software/friday	
			--output=<path_name> specifies the output directory 
		   		- defaults to ./friday_outputs
		   	--output-vcf=<path_name> specifies the output directory for vcf file 
		   		- defaults to ./friday_outputs/vcf_output
		   	--threads=<int> specifies number of threads
		   		- defaults to 32	
		   	--chromosome-start=<int> specifies the start chromosome
		   		- defaults to 1
		   	--chromosome-end=<int> specifies the start chromosome
		   		- defaults to 22"
		exit 1
	;;
    --friday-location=*)
    FRIDAY="${i#*=}"
    shift # past argument=value
    ;;
    --output=*)
    OUTPUT="${i#*=}"
    shift # past argument=value
    ;;
    --output-vcf=*)
    OUTPUTVCF="${i#*=}"
    shift # past argument=value
    ;;
    --chromosome-start=*)
    CHRSTART="${i#*=}"
    shift # past argument=value
    ;;
    --chromosome-end=*)
    CHREND="${i#*=}"
    shift # past argument=value
    ;;
    ref=*)
    REF="${i#*=}"
    shift # past argument=value
    ;;
    bam=*)
    BAM="${i#*=}"
    shift # past argument=value
    ;;
   	model=*)
    MODEL="${i#*=}"
    shift # past argument=value
    ;;
    threads=*)
    THREADS="${i#*=}"
    shift # past argument=value
    ;;
    # any other argument
    *)
    echo "usage: friday_pipeline [--help] [--friday-location=<path_name>] [--output=<path_name>]
                   [--output-vcf=<path_name>] [--chromosome-start=<int>] 
                   [--chromosome-end=<int>] ref=<path_name> bam=<path_name>
                   model=<path_name> threads=<path_name>"
    exit 1
    ;;
esac
done

 
if [ $REF == 'missing' ] || [ $BAM == 'missing' ] || [ $MODEL == 'missing' ]
then
	echo "bam, ref, or model missing"
    echo "usage: friday_pipeline [--help] [--friday-location=<path_name>] [--output=<path_name>]
               [--output-vcf=<path_name>] [--chromosome-start=<int>] 
               [--chromosome-end=<int>] ref=<path_name> bam=<path_name>
               model=<path_name> threads=<path_name>"
    exit 1
fi

echo "Starting Friday with the following settings"
echo "FRIDAY location 	= ${FRIDAY}"
echo "Output dir     		= ${OUTPUT}"
echo "VCF Output dir 		= ${OUTPUTVCF}"
echo "Starting chromosome 	= ${CHRSTART}"
echo "Ending chromosome 	= ${CHREND}"
echo "Reference		= ${REF}"
echo "Model			= ${MODEL}"
echo "Threads			= ${THREADS}"

