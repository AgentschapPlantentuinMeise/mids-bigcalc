for col in $(seq 1 19); do
  awk -v col="$col" -F'\t' '{c[$col]++} END {for (v in c) print "col"col, v, c[v]}' outputs/sql_*.txt >> all_counts.txt
done
