library(ggplot2)
library(tibble)
library(tidyr)
library(rlang)

source("workflow/scripts/plots/plots_pallet.R")

plot_reads_loss <- function(
  metadata_df,
  color_condition,
  reads_loss_file = params$i_reads_loss,
  plot_file = NULL,
  red_zone_file = NULL
) {
  sample_names_vec <- rownames(metadata_df)

  group_condition <- rlang::enquo(color_condition)
  group <- rlang::eval_tidy(
    group_condition,
    data = metadata_df
  )
  group <- factor(group)
  group_levels <- levels(group)
  group_colors <- setNames(my_palette(length(group_levels)), group_levels)

  reads_loss_data <- read.csv(reads_loss_file, sep = "\t", row.names = 1)
  stages <- c("input", "filtered", "merged", "nochim", "nochim_nozero")

  group_df <- data.frame(
    sample = sample_names_vec,
    group = group,
    stringsAsFactors = FALSE
  )

  reads_loss_long <- reads_loss_data[stages] |>
    rownames_to_column("sample") |>
    pivot_longer(
      cols = all_of(stages),
      names_to = "stage",
      values_to = "read_count"
    ) |>
    mutate(stage = factor(stage, levels = stages)) |>
    arrange(sample, stage) |>
    left_join(group_df, by = "sample")

  plot <- ggplot(reads_loss_long, aes(x = stage, y = read_count, group = sample, color = group)) +
    geom_hline(yintercept = 1000, linetype = "dashed", color = "red", linewidth = 0.8, alpha = 0.7) +
    geom_hline(yintercept = 10000, linetype = "dashed", color = "orange", linewidth = 0.8, alpha = 0.7) +
    geom_line(alpha = 0.5, linewidth = 0.6) +
    geom_point(alpha = 0.6, size = 2) +
    scale_color_manual(values = group_colors) +
    scale_y_log10() +
    labs(
      x = "Processing Stage",
      y = "Read Count (log10)",
      title = "Read Loss Across Processing Stages",
      subtitle = "Red dashed line: 1,000 reads threshold | Orange dashed line: 10,000 reads threshold",
      color = "Group"
    ) +
    annotate("text", x = 5.3, y = 1000, label = "1K", size = 3, color = "red", alpha = 0.7) +
    annotate("text", x = 5.3, y = 10000, label = "10K", size = 3, color = "orange", alpha = 0.7) +
    theme_minimal() +
    theme(
      panel.grid.major = element_line(color = "gray90"),
      panel.grid.minor = element_line(color = "gray95"),
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "right"
    )

  print(plot)

  if (!is.null(plot_file) && plot_file != "") {
    ggsave(plot_file, plot = plot, width = 12, height = 7, dpi = 300)
    cat(sprintf("\nPlot saved to: %s\n", plot_file))
  }

  red_zone_samples <- reads_loss_data[stages] |>
    apply(1, min) %>%
    {
      names(.[. < 1000])
    }

  cat("\n=== RED ZONE SAMPLES (min reads < 1,000) ===\n")
  cat(sprintf("Total: %d samples\n\n", length(red_zone_samples)))
  if (length(red_zone_samples) > 0) {
    print(red_zone_samples)
  } else {
    cat("No samples in red zone\n")
  }

  if (!is.null(red_zone_file) && red_zone_file != "") {
    cat(red_zone_samples, file = red_zone_file, sep = "\n")
    cat(sprintf("Red zone samples list saved to: %s\n", red_zone_file))
  }
}
