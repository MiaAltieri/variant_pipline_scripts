 ________________________________________
|                                        |
|    DeepVariant Instructions            |
|________________________________________|

-To get an idea of how to run this DeepVariant pipeline, we suggest you follow the instructions below
-These instructions are essentially the instructions in https://github.com/google/deepvariant/blob/master/docs/deepvariant-quick-start.md
-You may need to download some files, so visit that link as necessary


1. First set the following variables:

BIN_VERSION="0.7.2"
MODEL_VERSION="0.7.2"

MODEL_NAME="DeepVariant-inception_v3-${MODEL_VERSION}+data-wgs_standard"
MODEL_HTTP_DIR="https://storage.googleapis.com/deepvariant/models/DeepVariant/${MODEL_VERSION}/${MODEL_NAME}"
DATA_HTTP_DIR="https://storage.googleapis.com/deepvariant/quickstart-testdata"

OUTPUT_DIR=${HOME}/quickstart-output
REF=${HOME}/quickstart-testdata/ucsc.hg19.chr20.unittest.fasta
BAM=${HOME}/quickstart-testdata/NA12878_S1.chr20.10_10p1mb.bam
MODEL="${HOME}/${MODEL_NAME}/model.ckpt"

FINAL_OUTPUT_VCF="${OUTPUT_DIR}/output.vcf.gz"

2. Then call the deep variant pipeline
bash deep_variant_pipline.sh \
	model=“${MODEL}” \
	ref=${REF} \
	bam=${BAM} \
	region=chr20:10000000-10010000 \
	sample_name=NA12878 \
	--bin_vs=${BIN_VERSION} \
	--model_vs=${MODEL_VERSION} \
	--output=${OUTPUT_DIR} \
	--output_vcf="${OUTPUT_DIR}/output.vcf.gz" \
	--log_dir=${HOME}/logs \
	--threads=3 \
	cpu 

3. To evaluate the results call the hap.py pipeline as follows
bash happy_script.sh  \
	--truth_vcf=${HOME}/quickstart-testdata/test_nist.b37_chr20_100kbp_at_10mb.vcf.gz  \
	--final_ouput_vcf=${FINAL_OUTPUT_VCF}  \
	--confident_bed=${HOME}/quickstart-testdata/test_nist.b37_chr20_100kbp_at_10mb.bed  \
	--happy_output=${OUTPUT_DIR}/happy.output \
	--threads=3 \
	ref=${REF}  


 ________________________________________
|                                        |
|    FRIDAY Instructions                 |
|________________________________________|

-To get an idea of how to run the FRIDAY pipeline, we suggest you follow the instructions below


