library(rlang)

# -- private helpers -------------------------------------------------------

# Row pitch inside a legend, in character heights. Base R's default of 1 leaves
# a full blank line between keys; this is as tight as the keys go before the
# labels themselves start to collide (they touch outright at about 0.5, where
# the swatches are flush but the text is unreadable).
.legend_leading <- 0.65

.legend_size <- function(...) {
  # Size the legend would take, in inches, measured on an empty frame where
  # the plot region spans the current user range.
  box <- legend(0, 0, ..., plot = FALSE)$rect
  usr <- par("usr")
  c(
    w = box$w * par("pin")[1] / (usr[2] - usr[1]),
    h = box$h * par("pin")[2] / (usr[4] - usr[3])
  )
}

.fit_legend <- function(candidates, max_w, max_h, cex, ...) {
  # A legend with many keys runs off the figure unless it is folded into
  # columns, and past some number of keys no folding is enough. Try each
  # candidate column count, keep the one that can be drawn at the largest
  # text size, and shrink the text if even that one overflows -- a legend
  # ends up small rather than over the edge. `candidates` is in order of
  # preference, which settles ties.
  sizes <- lapply(candidates, function(n) .legend_size(..., ncol = n, cex = cex))
  scales <- vapply(
    sizes,
    function(size) min(1, max_w / size[["w"]], max_h / size[["h"]]),
    numeric(1)
  )

  i <- which.max(scales)
  size <- sizes[[i]]
  if (scales[i] < 1) {
    cex <- cex * scales[i]
    size <- .legend_size(..., ncol = candidates[i], cex = cex)
  }

  list(ncol = candidates[i], cex = cex, w = size[["w"]], h = size[["h"]])
}

.condition_colors <- function(cond) {
  setNames(
    hcl.colors(length(levels(cond)), palette = "Dark 3"),
    levels(cond)
  )
}

.taxa_composition <- function(phy, rank, n_taxa, sample_order) {
  ps_rank <- phy |>
    microbiome::transform("compositional") |>
    tax_glom(rank, NArm = FALSE)

  abund <- as(otu_table(ps_rank), "matrix")
  if (!taxa_are_rows(ps_rank)) {
    abund <- t(abund)
  }
  abund <- abund[, sample_order, drop = FALSE]

  taxa_labels <- as.vector(tax_table(ps_rank)[, rank])

  # Taxa unassigned at `rank` never enter the legend, but they keep their
  # share of every bar: whatever the legend does not name ends up in the
  # blank "Other" block, so bars stay comparable across samples.
  ranking <- rowSums(abund)
  ranking[is.na(taxa_labels)] <- -Inf
  top <- head(order(ranking, decreasing = TRUE), n_taxa)

  mat <- abund[top, , drop = FALSE]
  rownames(mat) <- taxa_labels[top]

  rbind(mat, Other = pmax(0, 1 - colSums(mat)))
}

.plot_dendrogram_panel <- function(dend, dist_label) {
  plot(dend, ylab = dist_label, leaflab = "none")
}

.condition_rows <- function(row_heights) {
  # Row centres, top down, in the coordinates the strip and legend panels
  # share: rows are as tall as their legend needs, so a wrapped legend gets
  # the room instead of spilling over its neighbours.
  sum(row_heights) - cumsum(row_heights) + row_heights / 2
}

.plot_condition_panel <- function(conds, cols, leaf_order, row_heights, band, cex) {
  n <- length(leaf_order)
  centres <- .condition_rows(row_heights)

  # Same x range as the dendrogram (leaves at 1..n), so every cell sits under
  # the tip it describes.
  plot.new()
  plot.window(xlim = c(0.5, n + 0.5), ylim = c(0, sum(row_heights)))

  for (j in seq_along(conds)) {
    half <- min(band, row_heights[j] * 0.8) / 2

    rect(
      seq_len(n) - 0.5,
      centres[j] - half,
      seq_len(n) + 0.5,
      centres[j] + half,
      col = cols[[j]][as.character(conds[[j]][leaf_order])],
      border = NA
    )
    mtext(
      names(conds)[j],
      side = 2,
      at = centres[j],
      las = 1,
      adj = 1,
      line = 0.4,
      cex = cex
    )
  }
}

.plot_taxa_panel <- function(mat, cols) {
  # `space = 0` over xlim c(0, n) puts bar centres at the same relative
  # positions as the dendrogram leaves (drawn over xlim c(0.5, n + 0.5)),
  # so every bar stays under the tip it belongs to.
  # "Other" is drawn rather than left blank, so the white block is really
  # white on any device background and matches its key in the legend.
  barplot(
    mat,
    space = 0,
    border = NA,
    col = c(cols, Other = "white"),
    names.arg = rep("", ncol(mat)),
    xlim = c(0, ncol(mat)),
    # Reversed: bars hang from the 0% line at the top, which puts the
    # coloured part right under the strips and the tree it belongs to.
    ylim = c(1, 0),
    axes = FALSE,
    ylab = "Relative abundance"
  )
  axis(2, at = seq(0, 1, 0.25), labels = paste0(seq(0, 100, 25), "%"), las = 1)
}

.plot_condition_legends <- function(cols, fits, row_heights) {
  centres <- .condition_rows(row_heights)

  plot.new()
  plot.window(xlim = c(0, 1), ylim = c(0, sum(row_heights)))

  for (j in seq_along(cols)) {
    legend(
      x = 0,
      y = centres[j],
      xjust = 0,
      yjust = 0.5,
      legend = names(cols[[j]]),
      fill = cols[[j]],
      border = NA,
      bty = "n",
      ncol = fits[[j]]$ncol,
      x.intersp = 0.6,
      y.intersp = .legend_leading,
      cex = fits[[j]]$cex
    )
  }
}

.taxa_legend_keys <- function(cols) {
  # "Other" leads the legend: it is the block the bars leave white, and
  # without a key nothing says what that space stands for. Only that key gets
  # an outline -- a white swatch is invisible otherwise.
  list(
    legend = c("Other", names(cols)),
    fill = c("white", unname(cols)),
    border = c("grey40", rep(NA, length(cols)))
  )
}

.plot_taxa_legend <- function(cols, rank, fit) {
  keys <- .taxa_legend_keys(cols)
  plot.new()
  legend(
    x = 0,
    y = 1,
    xjust = 0,
    yjust = 1,
    title = rank,
    legend = keys$legend,
    fill = keys$fill,
    border = keys$border,
    bty = "n",
    ncol = fit$ncol,
    y.intersp = .legend_leading,
    cex = fit$cex
  )
}

# -- public API ------------------------------------------------------------

#' Sample dendrogram with metadata strips and community composition
#'
#' Draws, top to bottom on the current device: a vertical dendrogram of the
#' samples (`hclust(dist, method = "ward.D2")`), one colour strip per metadata
#' variable, and -- when `taxa_rank` is given -- a stacked bar of relative
#' abundances. Every panel is drawn in the leaf order of the tree, so a column
#' is the same sample in all of them. Legends sit in a column on the right,
#' each strip's legend on the strip's own row.
#'
#' Legends are fitted to the space they have: many keys fold into several
#' columns (and the strip they belong to gets a taller row), and text is scaled
#' down if folding alone is not enough, so a legend is never drawn past the edge
#' of the figure. A wider figure is still the better fix when they get cramped.
#'
#' Base graphics: the plot goes to the current device and `par()` is restored on
#' exit. Panels are sized as shares of the figure, so the figure's own size is
#' the only thing to tune -- `fig-width`/`fig-height` in Quarto,
#' `options(repr.plot.width = , repr.plot.height = )` in Jupyter.
#'
#' @param dist A `dist` over samples. Its labels must all appear in
#'   `rownames(sample_data(phy))`; order does not matter.
#' @param phy A phyloseq object. Supplies the metadata for the strips, and the
#'   counts and taxonomy for the composition panel. When `taxa_rank` is used it
#'   must hold **counts, not normalized values** (they are turned into
#'   per-sample proportions internally, which a VST table would break); the
#'   distance itself may of course come from normalized data.
#' @param ... One or more conditions, each drawn as its own strip, in the order
#'   given. A condition is a bare column of `sample_data(phy)`
#'   (`depr_or_control`), a named one whose name becomes the strip's label
#'   (`Group = depr_or_control`), or any expression evaluated against the sample
#'   data (`paste(depr_or_control, season)`,
#'   `cut(d_age_hc, c(0, 40, 60, Inf))`). Each is passed through `factor()`, so
#'   bin continuous variables first unless a colour per distinct value is what
#'   you want. Levels are coloured with `hcl.colors(n, "Dark 3")`.
#' @param taxa_rank Rank to aggregate the composition panel to, one of
#'   `rank_names(phy)` (e.g. `"genus"`, `"family"`). `NULL` (default) draws the
#'   tree and the strips only.
#' @param n_taxa How many taxa the composition legend names (default 10). They
#'   are the most abundant taxa **assigned at `taxa_rank`**, ranked over all
#'   samples. Everything else -- lesser taxa and reads unassigned at that rank
#'   alike -- goes into the white `Other` block, which leads the legend as its
#'   first key: the blank part of a bar is exactly the share the legend does not
#'   name, and bars stay comparable between samples.
#' @param dist_label Y-axis label of the tree; name the distance that `dist`
#'   actually holds.
#' @param bar_width Thickness of the strips, as a multiple of the default.
#' @param taxa_height Height of the composition panel relative to the tree
#'   (0.8 by default, i.e. slightly shorter than the tree).
#' @param cex Text size of the strip labels and legends.
#'
#' @return Invisibly, a list with `dendrogram` (the `dendrogram` object),
#'   `conditions` (the factors behind the strips), `cols` (their colour maps)
#'   and, when drawn, `taxa` (`abundance`, the plotted proportion matrix in leaf
#'   order with an `Other` row, and `cols`).
#'
#' @examples
#' # tree plus a single strip
#' plot_dendrogram(euc_dist, ps_core, depr_or_control)
#'
#' # several strips, with custom labels and derived variables
#' plot_dendrogram(
#'     euc_dist, ps_core,
#'     Group = depr_or_control, batch, season,
#'     Age = cut(d_age_hc, c(0, 40, 60, Inf), labels = c("<40", "40-60", "60+"))
#' )
#'
#' # genus composition under the tree, 10 genera named
#' plot_dendrogram(
#'     euc_dist, ps_core, depr_or_control,
#'     taxa_rank = "genus", n_taxa = 10
#' )
#'
#' # a distance that is not VST Euclidean, on an object without a tax_table
#' plot_dendrogram(
#'     ko_dist, phy_func, depr_or_control,
#'     dist_label = "KO robust Aitchison dist."
#' )
plot_dendrogram <- function(
  dist,
  phy,
  ...,
  taxa_rank = NULL,
  n_taxa = 10,
  dist_label = "VST Euc. dist.",
  bar_width = 1,
  taxa_height = 0.8,
  cex = 0.8
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

  color_conditions <- rlang::enquos(...)

  if (length(color_conditions) == 0) {
    stop("At least one condition must be given.")
  }

  given_names <- names(color_conditions)
  auto_names <- vapply(color_conditions, rlang::as_label, character(1))
  names(color_conditions) <- ifelse(given_names == "", auto_names, given_names)

  conds <- lapply(color_conditions, function(color_condition) {
    cond <- rlang::eval_tidy(color_condition, data = meta)

    if (length(cond) != nrow(meta)) {
      stop("Condition must return one value per sample.")
    }

    if (is.matrix(cond) || is.data.frame(cond)) {
      stop("Condition must return a vector.")
    }

    factor(cond)
  })
  cols <- lapply(conds, .condition_colors)

  hc <- hclust(dist, method = "ward.D2")
  dend <- as.dendrogram(hc)
  leaf_order <- order.dendrogram(dend)

  taxa <- NULL
  if (!is.null(taxa_rank)) {
    taxa_mat <- .taxa_composition(
      phy,
      taxa_rank,
      n_taxa,
      sample_ids[leaf_order]
    )
    taxa <- list(
      abundance = taxa_mat,
      cols = setNames(
        hcl.colors(nrow(taxa_mat) - 1, palette = "Dark 3"),
        head(rownames(taxa_mat), -1)
      )
    )
  }

  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par), add = TRUE)

  # An empty frame to measure the legends against; the first panel reuses this
  # page (`new = TRUE`), so nothing is drawn twice.
  plot.new()
  din <- par("din")
  label_in <- max(strwidth(names(conds), units = "inches", cex = cex))

  # Everything is laid out as a share of the figure rather than in margin
  # lines: notebook front-ends record the plot on one device and replay it on
  # a canvas of a different size, which stretches user-space distances (the
  # spacing inside a legend, for one) while leaving text at its point size.
  # Proportional panels survive that, absolute margins do not.
  max_legend_w <- 0.38 * din[1]
  row_in <- 0.05 * din[2] * bar_width
  band_in <- row_in * 0.7

  # One row per condition, laid out as a single row of keys where that fits
  # and folded into more rows where it does not.
  cond_fits <- lapply(cols, function(x) {
    .fit_legend(
      candidates = rev(seq_along(x)),
      max_w = max_legend_w,
      max_h = 0.45 * din[2] / length(cols),
      cex = cex,
      legend = names(x),
      fill = x,
      border = NA,
      bty = "n",
      x.intersp = 0.6,
      y.intersp = .legend_leading
    )
  })
  row_heights <- pmax(
    row_in,
    vapply(cond_fits, function(fit) fit$h * 1.15, numeric(1))
  )
  strip_frac <- min(0.5, sum(row_heights) / din[2])
  row_heights <- row_heights * strip_frac * din[2] / sum(row_heights)

  rest <- 1 - strip_frac
  taxa_frac <- if (is.null(taxa)) 0 else rest * taxa_height / (1 + taxa_height)
  dend_frac <- rest - taxa_frac

  taxa_fit <- NULL
  if (!is.null(taxa)) {
    keys <- .taxa_legend_keys(taxa$cols)
    taxa_fit <- .fit_legend(
      candidates = seq_along(keys$legend),
      max_w = max_legend_w,
      # The panel's own margins are not available to the legend, and
      # the last key should not sit flush against the figure edge.
      max_h = 0.92 * (taxa_frac * din[2] - 1.9 * par("csi")),
      cex = cex,
      legend = keys$legend,
      fill = keys$fill,
      border = keys$border,
      title = taxa_rank,
      bty = "n",
      y.intersp = .legend_leading
    )
  }

  legend_in <- max(
    vapply(cond_fits, function(fit) fit$w, numeric(1)),
    if (is.null(taxa)) 0 else taxa_fit$w
  )
  legend_frac <- min(0.45, legend_in / din[1] + 0.02)

  panel_x <- c(0, 1 - legend_frac)
  legend_x <- c(1 - legend_frac, 1)
  taxa_y <- c(0, taxa_frac)
  strip_y <- c(taxa_frac, taxa_frac + strip_frac)
  dend_y <- c(taxa_frac + strip_frac, 1)

  mar <- par("mar")
  mar[2] <- max(mar[2], label_in / par("csi") + 1)

  par(
    fig = c(panel_x, dend_y),
    mar = c(0, mar[2], mar[3], 0),
    new = TRUE
  )
  .plot_dendrogram_panel(dend, dist_label)

  par(fig = c(panel_x, strip_y), mar = c(0, mar[2], 0, 0), new = TRUE)
  .plot_condition_panel(conds, cols, leaf_order, row_heights, band_in, cex)

  par(fig = c(legend_x, strip_y), mar = c(0, 0.5, 0, 0), new = TRUE)
  .plot_condition_legends(cols, cond_fits, row_heights)

  if (!is.null(taxa)) {
    par(fig = c(panel_x, taxa_y), mar = c(1.1, mar[2], 0.8, 0), new = TRUE)
    .plot_taxa_panel(taxa$abundance, taxa$cols)

    par(fig = c(legend_x, taxa_y), mar = c(1.1, 0.5, 0.8, 0), new = TRUE)
    .plot_taxa_legend(taxa$cols, taxa_rank, taxa_fit)
  }

  invisible(
    list(
      dendrogram = dend,
      conditions = conds,
      cols = cols,
      taxa = taxa
    )
  )
}
