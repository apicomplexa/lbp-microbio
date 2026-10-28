library("DESeq2")
library(phyloseq)

vst_normalization <- function(ps) {
  dds <- phyloseq_to_deseq2(ps, ~1)
  dds <- estimateSizeFactors(dds, type = "poscounts")
  dds_vst <- varianceStabilizingTransformation(dds)

  vst_trans_count_tab <- assay(dds_vst)
  euc_dist <- dist(t(vst_trans_count_tab))

  ps_vst <- phyloseq(
    otu_table(vst_trans_count_tab, taxa_are_rows = T),
    sample_data(ps),
    tax_table(ps)
  )

  return(list(
    ps_vst = ps_vst,
    euclidean_dist = euc_dist
  ))
}
