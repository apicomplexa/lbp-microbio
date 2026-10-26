library(dada2)
library(DECIPHER)

load(snakemake@input$silva)

seqtab.nochim <- readRDS(snakemake@input$seqtab_nochim)

fa <- DNAStringSet(getSequences(seqtab.nochim))

ids <- IdTaxa(
  fa,
  trainingSet,
  strand = "top",
  threshold = 60,
  processors = snakemake@threads,
  verbose = FALSE
)

ranks <- c("domain", "phylum", "class", "order", "family", "genus", "species")
taxid <- t(sapply(ids, function(x) {
  m <- match(ranks, x$rank)
  taxa <- x$taxon[m]
  taxa[startsWith(taxa, "unclassified_")] <- NA
  taxa
}))

colnames(taxid) <- ranks
rownames(taxid) <- getSequences(seqtab.nochim)

saveRDS(taxid, snakemake@output$tax)
