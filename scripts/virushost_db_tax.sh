#!/bin/bash

gunzip ../data/virushostdb.formatted.cds.faa.gz
input_file="virushostdb.formatted.cds.faa"

awk '
BEGIN { FS="[|]"; OFS="\t" }
/^>/ {
    split($1, id, " ")
    gsub(">", "", id[1])
    print id[1], $4
}
' $input_file >../data/virushostdb.formatted.cds_tax.txt