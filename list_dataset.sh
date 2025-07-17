mkdir -p extracted_rows

for i in $(seq 1 27); do
  tsv_file="outputs/sql_results_${i}_excl_ids.txt"
  line_file="match_groups/file_${i}.txt"

  if [[ -f "$line_file" ]]; then
    awk '
      BEGIN {
        while ((getline l < "'$line_file'") > 0) {
          lines[l] = 1
        }
        close("'$line_file'")
      }
      (NR in lines) {
        print
      }
    ' "$tsv_file" > "extracted_rows/matched_${i}.tsv"
  fi
done

head -n 1 "outputs/sql_results_1_excl_ids.txt"> all_matched_rows.tsv

if compgen -G "extracted_rows/matched_*.tsv" > /dev/null; then
  cat extracted_rows/matched_*.tsv >> all_matched_rows.tsv
fi
