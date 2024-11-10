#!/bin/bash

# Input file
input_file="sample.txt"

# Database paths
rRNA_bowtie2_path="./bowtie2"
virushostdb="./db_diamond"
# Software paths
palmscan="../bin/palmscan2"
# Output directory
output_dir="./scripts"

# Create output directory
mkdir -p ${output_dir}

# Read input file and generate scripts
while read -r fq1 fq2 seqID; do
  script_file="${output_dir}/${seqID}.sh"
  echo "#!/bin/bash

# Step 1.1: Clean reads with fastp
fastp --detect_adapter_for_pe \\
      --dedup \\
      --dup_calc_accuracy 3 \\
      --dont_eval_duplication \\
      --qualified_quality_phred 20 \\
      --n_base_limit 5 \\
      --average_qual 20 \\
      --length_required 50 \\
      --low_complexity_filter \\
      --correction \\
      --thread 8 \\
      -i ${fq1} \\
      -o ${seqID}_r1.fastp.fq.gz \\
      -I ${fq2} \\
      -O ${seqID}_r2.fastp.fq.gz \\
      --json ${seqID}.json \\
      --html ${seqID}.html

# Step 1.2: Remove rRNA with Bowtie2

bowtie2 --local --threads 8 -1 ${seqID}_r1.fastp.fq.gz -2 ${seqID}_r2.fastp.fq.gz -x ${rRNA_bowtie2_path}/rRNA -S ${seqID}.rRNA.sam --un-conc-gz ${seqID}
mv ${seqID}.1 ${seqID}.cleanreads.1.fq.gz
mv ${seqID}.2 ${seqID}.cleanreads.2.fq.gz
rm ${seqID}_r1.fastp.fq.gz
rm ${seqID}_r2.fastp.fq.gz
rm -f ${seqID}.rRNA.sam

# Step 2.1: Assembly with Megahit
megahit --memory 20000000000 --min-contig-len 300 -t 12 --out-dir ./megahit --out-prefix ${seqID} -1 ${seqID}.cleanreads.1.fq.gz -2 ${seqID}.cleanreads.2.fq.gz
perl -pe 's/^>/>${seqID}-/' ./megahit/${seqID}.contigs.fa > ./megahit/${seqID}_addname.fna

# Step 3.1: Scan for RDRP with Palmscan

getorf -sequence ./megahit/${seqID}_addname.fna -outseq ./megahit/${seqID}_addname.faa -minsize 600

${palmscan} -search_pssms ./megahit/${seqID}_addname.faa \\
      -tsv palmscan_results/${seqID}.tsv \\
      -fev palmscan_results/${seqID}.fev \\
      -fasta palmscan_results/${seqID}.pp.fasta \\
      -core palmscan_results/${seqID}.core.fasta \\
      -report_pssms palmscan_results/${seqID}.report.txt

# Step 4.1: BLASTP for Functional Annotation
diamond blastp -q palmscan_results/${seqID}.core.fasta -d ${virushostdb}/virushostdb_protein.dmnd -o blastp_results.txt --evalue 1e-5 --top 5" > ${script_file}

  # Make the script executable
  chmod +x ${script_file}
done < ${input_file}