library(dada2)

if (!exists("snakemake")) {
  Snakemake <- setClass(
    "Snakemake",
    slots = c(
      input = "list",
      output = "list",
      config = "list"
    )
  )
  snakemake <- Snakemake(
    input = list(
      fq = c('data/raw/fastq/trimmed/SRR32393053_R1.fastq.gz', 'data/raw/fastq/trimmed/SRR32393053_R2.fastq.gz')
    ),
    output = list(
      report = 'results/reports/qc/filterAndTrim/report_SRR32393053.tsv',
      fq = c('data/raw/fastq/filtered/SRR32393053_R1.fastq.gz', 'data/raw/fastq/filtered/SRR32393053_R2.fastq.gz')
    ),
    config = list(
      "pathvars" = list(
        "data_initial" = 'data/initial',
        "data_raw" = 'data/raw',
        "samples" = 'data/raw/fastq',
        "samples_filter" = 'data/raw/fastq/filtered',
        "temp" = 'data/temp',
        "reports" = 'results/reports',
        "figures" = 'results/figures'
      )
    )
  )
}

extract_oneside_reads <- function(reads_list, reverse = F) {
  filter_regexp <- '_R1\\.'
  if (reverse) {
    filter_regexp <- '_R2\\.'
  }
  return(
    reads_list[grepl(filter_regexp, reads_list)] |>
      as.character()
  )
}

forward_reads <- extract_oneside_reads(snakemake@input$fq, F)
reverse_reads <- extract_oneside_reads(snakemake@input$fq, T)

forward_reads_filtered <- extract_oneside_reads(snakemake@output$fq, F)
reverse_reads_filtered <- extract_oneside_reads(snakemake@output$fq, T)

filter_sats <- filterAndTrim(
  forward_reads,
  forward_reads_filtered,
  reverse_reads,
  reverse_reads_filtered,
  maxEE = c(snakemake@params$max_ee_f, snakemake@params$max_ee_r),
  rm.phix = TRUE,
  minLen = 100,
  truncLen = c(snakemake@params$trunc_len_f, snakemake@params$trunc_len_r),
  multithread = FALSE
)

write.table(
  filter_sats,
  snakemake@output$report,
  sep = "\t",
  quote = F,
)
