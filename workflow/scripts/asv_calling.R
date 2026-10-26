library(dada2)

err_r1 <- readRDS(snakemake@input$error_r1)
err_r2 <- readRDS(snakemake@input$error_r2)

derep_r1 <- derepFastq(snakemake@input$r1)
derep_r2 <- derepFastq(snakemake@input$r2)

dada_r1 <- dada(derep_r1, err = err_r1, pool = T, multithread = snakemake@threads)
dada_r2 <- dada(derep_r2, err = err_r2, pool = T, multithread = snakemake@threads)

merged_asv <- mergePairs(
  dada_r1,
  derep_r1,
  dada_r2,
  derep_r2,
  trimOverhang = TRUE,
  minOverlap = 12
)

if (class(merged_asv) != 'list') {
  merged_asv <- list(merged_asv)
  names(merged_asv) <- c(basename(snakemake@input$r1))
}
names(merged_asv) <- sapply(strsplit(names(merged_asv), "_"), `[`, 1)

seqtab <- makeSequenceTable(merged_asv)

saveRDS(
  seqtab,
  snakemake@output$seqtab
)
saveRDS(
  list(r1 = dada_r1, r2 = dada_r2),
  snakemake@output$dada
)
