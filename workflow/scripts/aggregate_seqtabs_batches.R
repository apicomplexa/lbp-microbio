library(dada2)
if (length(snakemake@input$batches_seqtab) < 2) {
  seqtab <- readRDS(snakemake@input$batches_seqtab[[1]])
} else {
  seqtab <- mergeSequenceTables(tables = snakemake@input$batches_seqtab)
}
saveRDS(seqtab, snakemake@output$seqtab)
