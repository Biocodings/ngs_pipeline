############
#	seq2HLA
############
rule seq2HLA:
	input:	R=lambda wildcards: FQ[wildcards.sample],
		script=NGS_PIPELINE + "/seq2HLA/seq2HLA.py"
	output:
		"{base}/{TIME}/{sample}/HLA/seq2HLA/{sample}-ClassI.HLAgenotype4digits"
	params:
		rulename= "seq2HLA",
		python  = config["version_python"],
		R	= config['version_R'],
		bowtie	= config['bowtie'],
		batch	= config[config['host']]["job_annovar"],
		HLA	= config['HLA']
	shell: """
	#######################
	module load bowtie/{params.bowtie} python/{params.python} R/{params.R}
	python {input.script} {params.HLA}/seq2HLA/ -1 {input.R[0]} -2 {input.R[1]}  -p 2 -r {wildcards.base}/{wildcards.TIME}/{wildcards.sample}/HLA/seq2HLA/{wildcards.sample}
	#######################
	"""
############
#	HLAminer
############
rule HLAminer:
	input:	R=lambda wildcards: FQ[wildcards.sample],
		script=NGS_PIPELINE+"/HLAminer_v1.3.1/bin/HPTASRwgs_classI.sh"
	output: "{base}/{TIME}/{sample}/HLA/HLAminer/HLAminer_HPTASR.csv"
	params:
		rulename="HLAminer",
		batch	=config[config['host']]["job_annovar"],
		HLA	=config['HLA'],
		location=NGS_PIPELINE
	shell: """
	#######################
	echo {input.R[0]} >{wildcards.base}/{wildcards.TIME}/{wildcards.sample}/HLA/HLAminer/patient.fof
	echo {input.R[1]} >>{wildcards.base}/{wildcards.TIME}/{wildcards.sample}/HLA/HLAminer/patient.fof
	
	sh {input.script} {params.location}/HLAminer_v1.3.1/bin/ {wildcards.base}/{wildcards.TIME}/{wildcards.sample}/HLA/HLAminer/
	#######################
	"""
############
#	VEP4pVACSeq
############
rule VEP:
	input:
		files=lambda wildcards: UNION_SOM_MUT[wildcards.sample],
		HLA  =lambda wildcards: HLA[wildcards.sample],
		tool =NGS_PIPELINE + "/scripts/consensusSomaticVCF.pl",
		merge=NGS_PIPELINE + "/scripts/consensusHLA.pl"
	output: 
		vcf	="{base}/{TIME}/{sample}/NeoAntigen/{sample}.final.vcf",
	params:
		rulename = "VEP",
		VEP	 = config['VEP'],
		normal	 = lambda wildcards: config['sample_references'][wildcards.sample][0],
		batch    = config[config['host']]["job_VEP"],
	shell: """
	#######################
	module load vcftools VEP/{params.VEP} perl
	perl {input.tool} -vcf {wildcards.base}/{wildcards.TIME}/{wildcards.sample}/calls/{wildcards.sample}.strelka.indels.raw.vcf,{wildcards.base}/{wildcards.TIME}/{wildcards.sample}/calls/{wildcards.sample}.strelka.snvs.raw.vcf,{wildcards.base}/{wildcards.TIME}/{wildcards.sample}/calls/{wildcards.sample}.MuTect.raw.vcf -order {params.normal},{wildcards.sample} -filter REJECT |vcf-subset -u -c {wildcards.sample} >{output.vcf}.tmp
	variant_effect_predictor.pl -i {output.vcf}.tmp --plugin Downstream --plugin Wildtype --terms SO --offline --cache --dir_cache $VEPCACHEDIR --assembly GRCh37 --output_file {output.vcf} --vcf --force_overwrite
	rm -rf {output.vcf}.tmp
	
	perl {input.merge} {input.HLA[0]} {input.HLA[1]} | sort > {wildcards.base}/{wildcards.TIME}/{params.normal}/HLA/{params.normal}.Calls.txt
	#######################
	"""
############
##       pVACSeq
#############
rule pVACseq:
	input:
		"{base}/{TIME}/{sample}/NeoAntigen/{sample}.final.vcf"
	output:
		"{base}/{TIME}/{sample}/NeoAntigen/MHC_Class_I/{sample}.final.tsv"
	params:
		rulename = "pVACSeq",
		python   = config["version_python"],
		normal   = lambda wildcards: config['sample_references'][wildcards.sample][0],
		tool 	 = NGS_PIPELINE + "/scripts/process_pVACSeq.pl",
		IEDB	 = config['IEDB'],
		batch    = config[config['host']]["job_VEP"],
		host	 = config['host']
	shell: """
	#######################
	allele=`grep -v -P "\\tNotCalled\\t" {wildcards.base}/{wildcards.TIME}/{params.normal}/HLA/{params.normal}.Calls.txt |cut -f1 |grep -v Allele|tr '\\n' ',' |sed -e 's/,$//g'`
	
	module load pvacseq python/{params.python}
	pvacseq run --iedb-install-directory {params.IEDB} -e 8,9,10,11 --fasta-size=200 {input} {wildcards.sample} ${{allele}} {{NNalign,NetMHC,NetMHCIIpan,NetMHCcons,NetMHCpan,PickPocket,SMM,SMMPMBEC,SMMalign}} {wildcards.base}/{wildcards.TIME}/{wildcards.sample}/NeoAntigen/
	perl {params.tool} {output} |sort |uniq >{wildcards.base}/{wildcards.TIME}/{wildcards.sample}/NeoAntigen/{wildcards.sample}.final.txt
	#######################
	"""
