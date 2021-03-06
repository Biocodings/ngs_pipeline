############
#       STAR
############
rule STAR_TPM:
	input:  R=lambda wildcards: FQ[wildcards.sample],
		ref=config["reference"],
		gtf1=config['GTF']['UCSC'],
	output:
		temp("{subject}/{TIME}/{sample}/{sample}.star_UCSC.bam"),
		"{subject}/{TIME}/{sample}/{sample}_ucsc.SJ.out.tab"
	version: config["STAR"]
	params:
		rulename  = "STAR",
		batch     = config[config['host']]['job_STAR_TPM'],
		star_ref  = config['STAR_ref'],
		awk       = NGS_PIPELINE + "/scripts/SJDB.awk",
		home      = WORK_DIR,
	shell: """
	#######################
	module load STAR/{version}
	cd ${{LOCAL}}/
	# run 1st pass
	STAR --outTmpDir STEP1 \
		--genomeDir {params.star_ref} \
		--readFilesIn {input.R[0]} {input.R[1]} \
		--readFilesCommand zcat\
		--outSAMtype BAM SortedByCoordinate\
		--outFileNamePrefix {wildcards.sample} \
		--runThreadN ${{THREADS}} \
		--outFilterMismatchNmax 2
	echo "Finished Step 1"

	# make splice junctions database file out of SJ.out.tab, filter out non-canonical junctions
	mkdir GenomeForPass2
	awk -f {params.awk} {wildcards.sample}SJ.out.tab > GenomeForPass2/{wildcards.sample}.out.tab.Pass1.sjdb
	echo "Finished Step 2"

	# generate genome with junctions from the 1st pass
	STAR --outTmpDir STEP2\
		--genomeDir GenomeForPass2\
		--runMode genomeGenerate\
		--genomeSAindexNbases 8\
		--genomeFastaFiles {input.ref}\
		--sjdbFileChrStartEnd GenomeForPass2/{wildcards.sample}.out.tab.Pass1.sjdb\
		--sjdbOverhang 100\
		--runThreadN ${{THREADS}}
	echo "Finished Step 3"

	# run 2nd pass with the new genome
	STAR --outTmpDir STEP3\
		--genomeDir GenomeForPass2\
		--runThreadN ${{THREADS}}\
		--outSAMattributes All\
		--readFilesIn {input.R[0]} {input.R[1]}\
		--outSAMtype BAM SortedByCoordinate\
		--sjdbGTFfile {input.gtf1}\
		--readFilesCommand zcat\
		--outFileNamePrefix {wildcards.sample}_ucsc
	mv -f {wildcards.sample}_ucscAligned.sortedByCoord.out.bam {params.home}/{wildcards.subject}/{TIME}/{wildcards.sample}/{wildcards.sample}.star_UCSC.bam
	mv -f {wildcards.sample}_ucscSJ.out.tab {params.home}/{wildcards.subject}/{TIME}/{wildcards.sample}/{wildcards.sample}_ucsc.SJ.out.tab
	echo "Finished Step 4"
	#######################
	"""
############
# featureCounts
#############
rule FeatureCounts:
	input:
		bam="{base}/{TIME}/{sample}/{sample}.star_UCSC.bam",
		ref=lambda wildcards: config['GTF'][wildcards.gtf],
		script=NGS_PIPELINE + "/scripts/featureCounts.R",
	output:
		gene="{base}/{TIME}/{sample}/TPM_{gtf}/{sample}_counts.Gene.txt",
	version: config['version_R']
	params:
		rulename   = "featureCounts",
		batch      =config[config['host']]['job_featCount'],
		work_dir =  WORK_DIR
	shell: """
	#######################
	module load R/{version}
	cd ${{LOCAL}}
	{input.script} --nt ${{THREADS}} --lib="{wildcards.sample}" --targetFile="{params.work_dir}/{input.bam}" --referenceGTF="{input.ref}" --countOut="{params.work_dir}/{wildcards.base}/{wildcards.TIME}/{wildcards.sample}/TPM_{wildcards.gtf}/{wildcards.sample}_counts" --fpkmOut="{params.work_dir}/{wildcards.base}/{wildcards.TIME}/{wildcards.sample}/TPM_{wildcards.gtf}/{wildcards.sample}_fpkm"
	#######################
	"""
