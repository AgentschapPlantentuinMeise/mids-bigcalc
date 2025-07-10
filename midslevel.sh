awk -F'\t' '{count[$19]++} END {for (v in count) print count[v], v}' sql_*.txt | sort -nr -> midslevel.txt
