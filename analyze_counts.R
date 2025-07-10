library(tidyverse)

# Simulated input as character vector (replace with readLines("yourfile.txt") if needed)
lines <- readLines("all_counts.txt",warn=F)
# Convert to tibble
df <- read_table(paste(lines, collapse = "\n"), col_names = FALSE)

# Rename columns
colnames(df) <- c("colname", "value_type", "count")

# Keep only rows where value_type is 0 or 1
df_filtered <- df %>% 
  filter(value_type %in% c("0", "1")) %>%
  mutate(count = as.numeric(count),
         value_type = factor(value_type, levels = c("0", "1")))

df_names = df %>%
  filter(value_type!="1",value_type!="0")

df_all = df_filtered %>%
  left_join(df_names,by=c("colname")) %>%
  mutate(value_type.y = str_wrap(gsub("mids:MIDS*","",value_type.y),width=5),
         count.x = count.x/1000000)

wrap_hard_hyphen <- function(x, width = 10) {
  vapply(x, function(s) {
    # Split at hard width, insert hyphens
    parts <- substring(s, seq(1, nchar(s), by = width), seq(width, nchar(s) + width - 1, by = width))
    paste0(paste0(parts, ifelse(nchar(parts) == width, "-", "")), collapse = "\n")
  }, character(1))
}
# Plot
ggplot(df_all, aes(x = value_type.y, y = count.x, fill = value_type.x)) +
  labs(x = "", y = "Specimens (millions)", fill = "MIDS element met") +
  geom_bar(stat = "identity", position = "dodge") +
  scale_x_discrete(labels = function(x) wrap_hard_hyphen(x)) +
  theme(axis.text=element_text(size=12))
