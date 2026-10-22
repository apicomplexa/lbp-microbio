# Shared plotting helpers. Rule scripts source this file via
# `snakemake@scriptdir` + "common/plotting.R"; notebooks and reports via its
# repo-relative path "workflow/scripts/common/plotting.R".

theme_project <- function(base_size = 11) {
  ggplot2::theme_bw(base_size = base_size) +
    ggplot2::theme(legend.position = "none", panel.grid.minor = ggplot2::element_blank())
}

save_figure <- function(plot, path, width = 4, height = 3.5) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  ggplot2::ggsave(path, plot, width = width, height = height)
}
