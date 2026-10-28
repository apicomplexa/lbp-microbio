library(rlang)
library(ggplot2)
library(vegan)

# -- private helpers -------------------------------------------------------

.hill_long_df <- function(hill, groups) {
  hill <- as.data.frame(hill)
  q_values <- as.numeric(colnames(hill))
  hill$sample_id <- rownames(hill)

  long_df <- data.frame(
    sample_id = rep(hill$sample_id, times = length(q_values)),
    q = rep(q_values, each = nrow(hill)),
    hill = unlist(hill[, seq_along(q_values)], use.names = FALSE)
  )
  long_df$group <- groups[long_df$sample_id]
  long_df
}

.hill_summary_df <- function(long_df) {
  long_df |>
    dplyr::group_by(group, q) |>
    dplyr::summarise(hill = median(hill), .groups = "drop")
}

# -- public API ------------------------------------------------------------

plot_hill_curves <- function(
  phy,
  color_condition,
  q = seq(0, 4, by = 0.25),
  summary = TRUE,
  log_y = TRUE,
  legend_title = NULL
) {
  meta <- as.data.frame(sample_data(phy))
  meta$sample_id <- rownames(meta)
  color_condition <- rlang::enquo(color_condition)

  cond <- rlang::eval_tidy(color_condition, data = meta)

  if (length(cond) != nrow(meta)) {
    stop("Condition must return one value per sample.")
  }
  if (is.matrix(cond) || is.data.frame(cond)) {
    stop("Condition must return a vector.")
  }

  cond <- factor(cond)
  groups <- setNames(cond, meta$sample_id)
  cols <- setNames(
    hcl.colors(length(levels(cond)), palette = "Dark 3"),
    levels(cond)
  )

  leg_title <- legend_title %||% rlang::as_label(color_condition)

  otu <- as(otu_table(phy), "matrix")
  if (taxa_are_rows(phy)) {
    otu <- t(otu)
  }

  hill <- renyi(otu, scales = q, hill = TRUE)
  long_df <- .hill_long_df(hill, groups)

  p <- ggplot(long_df, aes(x = q, y = hill, color = group)) +
    geom_line(
      aes(group = sample_id),
      linewidth = 0.3,
      alpha = if (summary) 0.35 else 0.8
    )

  if (summary) {
    p <- p +
      geom_line(
        data = .hill_summary_df(long_df),
        linewidth = 1.3
      )
  }

  if (log_y) {
    p <- p + scale_y_log10()
  }

  p <- p +
    scale_color_manual(values = cols, name = leg_title) +
    labs(x = "Order q", y = expression("Hill number "^q * D)) +
    theme_bw() +
    theme(legend.position = "bottom")

  print(p)

  invisible(list(
    hill = hill,
    long = long_df,
    cols = cols,
    plot = p
  ))
}
