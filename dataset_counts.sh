for col in $(seq 1 18); do
  awk -v col="$col" -F'\t' '{c[$col]++} END {for (v in c) print "col"col, v, c[v]}' all_matched_row*.tsv >> dataset_selected_counts.txt
done
