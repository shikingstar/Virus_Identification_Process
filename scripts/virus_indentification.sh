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
# Tax Script directory
tax_Script="./blastp_tax.py"
# Tax Script directory
tax_file="./virushostdb.formatted.cds_tax.txt"
# Create output directory
mkdir -p ${output_dir}

# Read input file and generate scripts
while read -r fq1 fq2 seqID; do
  script_file="${output_dir}/${seqID}.sh"
  echo "#!/bin/bash

# Create sample-specific output directory

mkdir -p ./${seqID}

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
      -o ./${seqID}/${seqID}_r1.fastp.fq.gz \\
      -I ${fq2} \\
      -O ./${seqID}/${seqID}_r2.fastp.fq.gz \\
      --json ./${seqID}/${seqID}.json \\
      --html ./${seqID}/${seqID}.html
seqkit stats ./${seqID}/${seqID}_r*.fastp.fq.gz >./${seqID}/${seqID}_fastap_stats.txt

# Step 1.2: Remove rRNA with Bowtie2
bowtie2 --local --threads 8 -1 ./${seqID}/${seqID}_r1.fastp.fq.gz -2 ./${seqID}/${seqID}_r2.fastp.fq.gz -x ${rRNA_bowtie2_path}/rRNA -S ./${seqID}/${seqID}.rRNA.sam --un-conc-gz ./${seqID}/${seqID}
mv ./${seqID}/${seqID}.1 ./${seqID}/${seqID}.cleanreads.1.fq.gz
mv ./${seqID}/${seqID}.2 ./${seqID}/${seqID}.cleanreads.2.fq.gz
rm ./${seqID}/${seqID}_r1.fastp.fq.gz
rm ./${seqID}/${seqID}_r2.fastp.fq.gz
rm -f ./${seqID}/${seqID}.rRNA.sam
seqkit stats ./${seqID}/${seqID}.cleanreads.*.fq.gz >./${seqID}/${seqID}_cleanreads_stats.txt

# Step 2.1: Assembly with Megahit
megahit --memory 20000000000 --min-contig-len 300 -t 12 --out-dir ./${seqID}/megahit --out-prefix ${seqID} -1 ./${seqID}/${seqID}.cleanreads.1.fq.gz -2 ./${seqID}/${seqID}.cleanreads.2.fq.gz
perl -pe 's/^>/>${seqID}-/' ./${seqID}/megahit/${seqID}.contigs.fa > ./${seqID}/megahit/${seqID}_addname.fna
seqkit stats ./${seqID}/megahit/${seqID}.contigs.fa >./${seqID}/${seqID}_contigs_stats.txt

# Step 3.1: Scan for RDRP with Palmscan
getorf -sequence ./${seqID}/megahit/${seqID}_addname.fna -outseq ./${seqID}/megahit/${seqID}_addname.faa -minsize 600

${palmscan} -search_pssms ./${seqID}/megahit/${seqID}_addname.faa \\
      -tsv ./${seqID}/palmscan_results/${seqID}.tsv \\
      -fev ./${seqID}/palmscan_results/${seqID}.fev \\
      -fasta ./${seqID}/palmscan_results/${seqID}.pp.fasta \\
      -core ./${seqID}/palmscan_results/${seqID}.core.fasta \\
      -report_pssms ./${seqID}/palmscan_results/${seqID}.report.txt

# Step 4.1: BLASTP for Functional Annotation
diamond blastp -q ./${seqID}/palmscan_results/${seqID}.core.fasta -d ${virushostdb}/virushostdb_protein.dmnd -o ./${seqID}/blastp_results.txt --evalue 1e-5 --top 5
python ${tax_Script} -tax ${tax_file} -i ./${seqID}/blastp_results.txt -o ./${seqID}/blastp_results_tax.txt" > ${script_file}

  # Make the script executable
  chmod +x ${script_file}
done < ${input_file}