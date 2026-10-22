# Summarise per-sample totals and plot them by group (example rule).
log <- file(snakemake@log[[1]], open = "wt")
sink(log)
sink(log, type = "message")

suppressPackageStartupMessages(library(tidyverse))
source(file.path(snakemake@scriptdir, "common", "plotting.R"))

samples <- read_tsv(snakemake@input[["samples"]], comment = "#", show_col_types = FALSE)

summary <- snakemake@input[["counts"]] |>
  unlist() |>
  map(read_tsv, show_col_types = FALSE) |>
  list_rbind() |>
  summarise(total = sum(count), n_features = n(), .by = sample_id) |>
  left_join(samples, by = "sample_id")

write_tsv(summary, snakemake@output[["table"]])

p <- ggplot(summary, aes(group, total, colour = group)) +
  geom_jitter(width = 0.1, size = 3) +
  labs(x = NULL, y = "Total counts") +
  theme_project()
save_figure(p, snakemake@output[["figure"]])

sessionInfo()
