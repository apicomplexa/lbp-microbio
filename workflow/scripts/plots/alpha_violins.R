library(ggplot2)
library(ggpubr)
library(patchwork)

plot_alpha_violins <- function(df, x, y, plot_file = NULL) {
  y_metrics <- if (length(y) == 1) y else y

  build_single_plot <- function(metric) {
    groups <- unique(df[[x]])
    comp <- combn(groups, 2, simplify = F)

    ggviolin(
      df,
      x = x,
      y = metric,
      fill = x,
      palette = hcl.colors(length(groups), palette = "Dark 3"),
      add = "boxplot"
    ) +
      stat_compare_means(
        method = "wilcox.test",
        comparisons = comp,
        label.y.npc = 0.95
      ) +
      labs(title = metric) +
      theme(plot.title = element_text(hjust = 0.5, size = 12, face = "bold"))
  }

  plots <- lapply(y_metrics, build_single_plot)

  p <- if (length(plots) == 1) plots[[1]] else wrap_plots(plots, nrow = 1)

  plot(p)

  if (!is.null(plot_file) && plot_file != "") {
    width <- if (length(plots) == 1) 12 else 5 * length(plots)
    height <- if (length(plots) == 1) 12 else 5
    ggsave(plot_file, plot = p, width = width, height = height, dpi = 300)
    cat(sprintf("\nPlot saved to: %s\n", plot_file))
  }
}
