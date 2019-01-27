# variant_pipline_scripts

If you type friday_pipeline without the correct specifications this appears

usage: friday_pipeline [--help] [--friday-location=<path_name>] [--output=<path_name>]
					   [--output-vcf=<path_name>] [--chromosome-start=<int>] 
					   [--chromosome-start=<int>] ref=<path_name> bam=<path_name>
					   model=<path_name> threads=<path_name>


When you do friday_pipeline --help you get:

These are friday options used in various situations:
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
   							- defaults to 22	  


