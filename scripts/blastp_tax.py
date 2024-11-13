import sys
import argparse

def load_taxonomy(tax_file):
    tax_map = {}
    with open(tax_file, 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) == 2:
                tax_map[parts[0]] = parts[1]
    return tax_map

def add_taxonomy_to_blastp(blastp_file, output_file, tax_map):
    with open(blastp_file, 'r') as bf, open(output_file, 'w') as of:
        for line in bf:
            parts = line.strip().split('\t')
            if len(parts) > 1:
                id = parts[1]
                taxonomy = tax_map.get(id, "Unknown")
                of.write(line.strip() + '\t' + taxonomy + '\n')

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add taxonomy information to BLASTP results.")
    parser.add_argument('-tax', '--taxonomy', required=True, help="Path to the taxonomy file (tax.txt)")
    parser.add_argument('-i', '--input', required=True, help="Path to the input BLASTP results file")
    parser.add_argument('-o', '--output', required=True, help="Path to the output file")

    args = parser.parse_args()

    tax_file = args.taxonomy
    blastp_file = args.input
    output_file = args.output

    tax_map = load_taxonomy(tax_file)
    add_taxonomy_to_blastp(blastp_file, output_file, tax_map)