library(rlang)
library(ggside)
library(vegan)

# -- private helpers -------------------------------------------------------

.pcoa_spider_df <- function(scores_df) {
  centroids <- scores_df |>
    dplyr::group_by(group) |>
    dplyr::summarise(
      cPCoA1 = mean(PCoA1),
      cPCoA2 = mean(PCoA2),
      .groups = "drop"
    )
  dplyr::left_join(scores_df, centroids, by = "group")
}

.pcoa_spider_layer <- function(spider_df) {
  geom_segment(
    data = spider_df,
    aes(xend = cPCoA1, yend = cPCoA2),
    alpha = 0.35,
    linewidth = 0.4,
    show.legend = FALSE
  )
}

.pcoa_ellipse_layer <- function() {
  # 1-SD level for bivariate normal: P = 1 - exp(-k^2/2), k=1 → ~0.394
  stat_ellipse(
    aes(fill = group),
    type = "norm",
    level = 1 - exp(-0.5),
    geom = "polygon",
    alpha = 0.12,
    linetype = "dashed",
    linewidth = 0.6,
    show.legend = FALSE
  )
}

.pcoa_marginal_layers <- function() {
  list(
    geom_xsideboxplot(
      aes(y = group, fill = group),
      orientation = "y",
      alpha = 0.7,
      outlier.size = 0.6,
      show.legend = FALSE
    ),
    geom_ysideboxplot(
      aes(x = group, fill = group),
      orientation = "x",
      alpha = 0.7,
      outlier.size = 0.6,
      show.legend = FALSE
    )
  )
}

# -- public API ------------------------------------------------------------

plot_pcoa <- function(
  phy,
  dist,
  color_condition,
  marginal = "density",
  legend_title = NULL
) {
  meta <- as.data.frame(sample_data(phy))
  sample_ids <- labels(dist)

  if (is.null(sample_ids)) {
    stop("Distance object must contain sample labels.")
  }
  if (!all(sample_ids %in% rownames(meta))) {
    stop("Sample IDs in distance matrix do not match sample_data.")
  }

  meta <- meta[sample_ids, , drop = FALSE]
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
  cols <- setNames(
    hcl.colors(length(levels(cond)), palette = "Dark 3"),
    levels(cond)
  )

  leg_title <- legend_title %||% rlang::as_label(color_condition)

  pcoa <- wcmdscale(dist, k = 2, eig = TRUE)
  eig <- pcoa$eig
  var_exp <- round(100 * eig[1:2] / sum(eig[eig > 0]), 1)

  scores_df <- as.data.frame(pcoa$points)
  colnames(scores_df) <- c("PCoA1", "PCoA2")
  scores_df$sample_id <- rownames(scores_df)
  scores_df$group <- cond

  spider_df <- .pcoa_spider_df(scores_df)

  p <- ggplot(scores_df, aes(x = PCoA1, y = PCoA2, color = group)) +
    .pcoa_spider_layer(spider_df) +
    .pcoa_ellipse_layer() +
    geom_point(size = 0.85, alpha = 0.85) +
    .pcoa_marginal_layers() +
    scale_color_manual(values = cols, name = leg_title) +
    scale_fill_manual(values = cols, name = leg_title) +
    labs(
      x = sprintf("PCoA1 [%.1f%%]", var_exp[1]),
      y = sprintf("PCoA2 [%.1f%%]", var_exp[2])
    ) +
    theme_bw() +
    theme_ggside_void() +
    theme(ggside.panel.scale = 0.2, legend.position = "bottom")

  print(p)

  invisible(list(
    pcoa = pcoa,
    scores = scores_df,
    cols = cols,
    plot = p
  ))
}
