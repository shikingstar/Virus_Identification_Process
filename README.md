# Virus_Identification_Process

## Softwares and Databases

### Softwares

- **[Bowtie2](http://bowtie-bio.sourceforge.net/bowtie2/index.shtml)**: v2.5.4 
- **[Megahit](https://github.com/voutcn/megahit)**: v1.2.9 
- **[Diamond](https://www.diamondsearch.org/)**: v2.1.8 
- **[SeqKit](https://bioinf.shenwei.me/seqkit/)**: v2.9.0 
- **[Palmscan](https://github.com/MennoMens/palm)**: v2.0 
- **[EMBOSS](https://emboss.sourceforge.io/)**: v6.6.0.0 
### Databases

- **SILVA_138.2_NR99**
- **VirusHost Protein Database**

## Steps

### Part 0. Software installation & Database deployment

#### Installation of other Softwares

- Using conda or mamba (**recommended**):
  ```bash
  conda create -c bioconda -c conda-forge -n virus emboss fastp diamond seqkit megahit unzip gxx_linux-64 bowtie2 -y
  conda activate virus
  ```

#### Installation of Palmscan

- Using git:
  ```bash
  git clone https://github.com/MennoMens/palmscan.git
  cd palmscan/src
  make
  ```

#### Build the database of VirusHost protein

```bash
diamond makedb --in ./virushostdb.formatted.cds.faa -d ./db_diamond/virushostdb_protein
```

#### Build the database of rRNA

```bash
cat ./SILVA_138.2_LSURef_NR99_tax_silva.fasta ./SILVA_138.2_SSURef_NR99_tax_silva.fasta > SILVA_138.2_Ref_NR99.fasta
bowtie2-build ./SILVA_138.2_Ref_NR99.fasta ./bowtie2/rRNA
```

### Part 1. Quality Control and Preprocessing

#### Step 1.1: Quality Control with Fastp

- **Purpose**: To detect adapter sequences, remove duplicates, filter low-quality sequences, and perform other quality control measures.
  ```bash
  fastp --detect_adapter_for_pe \
        --dedup \
        --dup_calc_accuracy 3 \
        --dont_eval_duplication \
        --qualified_quality_phred 20 \
        --n_base_limit 5 \
        --average_qual 20 \
        --length_required 50 \
        --low_complexity_filter \
        --correction \
        --thread 8 \
        -i ${fq1} \
        -o ${seqID}_r1.fastp.fq.gz \
        -I ${fq2} \
        -O ${seqID}_r2.fastp.fq.gz \
        --json ${seqID}.json \
        --html ${seqID}.html
  ```

#### Step 1.2: Remove rRNA with Bowtie2

- **Purpose**: To align the cleaned reads against the rRNA database and remove rRNA sequences.
  ```bash
  bowtie2 --local --threads 8 -1 ${seqID}_r1.fastp.fq.gz -2 ${seqID}_r2.fastp.fq.gz -x ./bowtie2/rRNA -S ${seqID}.rRNA.sam --un-conc-gz ${seqID}
  mv ${seqID}.1 ${seqID}.cleanreads.1.fq.gz
  mv ${seqID}.2 ${seqID}.cleanreads.2.fq.gz
  rm -f ${seqID}.rRNA.sam
  ```

### Part 2. Assembly

#### Step 2.1: Assembly with Megahit

- **Purpose**: To assemble the rRNA-removed reads into contigs.
  ```bash
  megahit --memory 20000000000 --min-contig-len 300 -t 12 --out-dir ./megahit --out-prefix ${seqID} -1 ${seqID}.cleanreads.1.fq.gz -2 ${seqID}.cleanreads.2.fq.gz
  perl -pe 's/^>/>${seqID}-/' ./megahit/${seqID}.contigs.fa > ./megahit/${seqID}_addname.fna
  ```

### Part 3. Identification of RDRP Sequences

#### Step 3.1: Scan for RDRP with Palmscan

- **Purpose**: To identify the RNA-dependent RNA polymerase (RDRP) sequences, which are indicative of viral genomes.
```bash
palmscan=../bin/palmscan2
getorf -sequence ./megahit/${seqID}_addname.fna -outseq ./megahit/${seqID}_addname.faa -minsize 600
mkdir palmscan_results
${palmscan} -search_pssms ./megahit/${seqID}_addname.faa \
    -tsv palmscan_results/${seqID}.tsv \
    -fev palmscan_results/${seqID}.fev \
    -fasta palmscan_results/${seqID}.pp.fasta \
    -core palmscan_results/${seqID}.core.fasta \
    -report_pssms palmscan_results/${seqID}.report.txt
```

### Part 4. BLASTp against VirusHost Protein Database

#### Step 4.1: BLASTp for Functional Annotation

- **Purpose**: To perform a BLASTp search of the assembled contigs against the VirusHost protein database to identify potential viral proteins.
```bash
diamond blastp -q palmscan_results/${seqID}.core.fasta -d ./db_diamond/virushostdb_protein.dmnd -o blastp_results.txt --evalue 1e-5 --top 5
```

## Script Explanation

The integrated script is in `scripts/virus_indentification.sh`.

## Input File Format

The input file (`sample.txt`) should contain three columns separated by spaces or tabs. Each row represents a sample with the following fields:

1. `fq1`: Path to the first FASTQ file (forward reads).
2. `fq2`: Path to the second FASTQ file (reverse reads).
3. `seqID`: Sample identifier.

### Example of `sample.txt`
```txt
path/to/sample1_R1.fastq.gz /path/to/sample1_R2.fastq.gz sample1
/path/to/sample2_R1.fastq.gz /path/to/sample2_R2.fastq.gz sample2
/path/to/sample3_R1.fastq.gz /path/to/sample3_R2.fastq.gz sample3

```

Comments: leave a blank line at the end.

## Output File Format
```txt
scripts/
├── sample1.sh
├── sample2.sh
└── sample3.sh

1 directory, 3 files

```