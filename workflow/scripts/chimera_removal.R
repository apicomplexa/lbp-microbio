library(dada2)
seqtab <- readRDS(snakemake@input$seqtab)
seqtab.nochim <- removeBimeraDenovo(seqtab, verbose = T, multithread = snakemake@threads)
saveRDS(
  seqtab.nochim,
  file = snakemake@output$seqtab_nochim,
)
