library(dada2)
library(ggplot2)

err_model <- learnErrors(
  snakemake@input,
  multithread = snakemake@threads
)

p <- plotErrors(err_model, nominalQ = TRUE)
p <- p + ggtitle(snakemake@params$band)

ggsave(
  snakemake@output$error_model_plot,
  p,
  width = 6,
  height = 4
)

saveRDS(
  err_model,
  snakemake@output$error_model
)
