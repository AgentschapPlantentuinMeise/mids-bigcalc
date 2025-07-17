mkdir -p match_groups

awk '{
  file_idx = int(($1 - 2) / 10000000) + 1
  local_line = (($1 - 2) % 10000000) + 2
  printf "%d\n", local_line >> ("match_groups/file_" sprintf("%d", file_idx) ".txt")
}' 821cc27a-e3bb-4bc5-ac34-89ada245069d.txt

