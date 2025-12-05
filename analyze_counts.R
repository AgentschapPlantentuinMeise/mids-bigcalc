library(tidyverse)
library(scales)

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

inf_elements = df_all %>%
  filter(!duplicated(value_type.y)) %>%
  pull(value_type.y)

cutof1 = grep("1",inf_elements)[1] - 0.5
cutof2 = grep("2",inf_elements)[1] - 0.5
cutof3 = grep("3",inf_elements)[1] - 0.5
# Plot
ggplot(df_all, aes(x = value_type.y, y = count.x, fill = value_type.x)) +
  labs(x = "", y = "% of Specimens achieving the MIDS element", fill = "MIDS element achieved") +
  geom_bar(stat = "identity", position = "fill") +
  scale_x_discrete(labels = function(x) wrap_hard_hyphen(x)) +
  scale_y_continuous(labels = percent_format()) +
  theme(axis.text=element_text(size=12)) +
  scale_fill_discrete(labels = c("No",
                                 "Yes")) +
  geom_hline(yintercept=0.50,linetype="dotted") +
  geom_hline(yintercept=0.75,linetype="dotted") +
  geom_hline(yintercept=0.25,linetype="dotted") +
  geom_vline(xintercept=cutof1,linetype="dashed",linewidth=1) +
  geom_vline(xintercept=cutof2,linetype="dashed",linewidth=1) +
  geom_vline(xintercept=cutof3,linetype="dashed",linewidth=1)
