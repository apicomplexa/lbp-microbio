rule LearnErrors:
    input:
        lambda wc: expand("<samples>/filtered/{run}_R{n}.fastq.gz", run=SAMPLES.index, n=wc.n),
    output:
        error_model="<temp>/err_model_R{n}.rds",
        error_model_plot="<figures>/dada2_error_model_R{n}.png",
    conda:
        "../envs/dada2-pipe.yaml"
    threads: 6
    params:
        band="R{n}",
    script:
        "../scripts/learn_error.R"


rule AVSCalling:
    input:
        r1=lambda wc: expand("<samples>/filtered/{run}_R1.fastq.gz", run=samples_by_group(wc).index),
        r2=lambda wc: expand("<samples>/filtered/{run}_R2.fastq.gz", run=samples_by_group(wc).index),
        error_r1="<temp>/err_model_R1.rds",
        error_r2="<temp>/err_model_R2.rds",
    output:
        seqtab=temp("<temp>/batch/{batch}/seqtab.rds"),
        dada2=temp("<temp>/batch/{batch}/dada2.rds"),
    conda:
        "../envs/dada2-pipe.yaml"
    threads: 8
    resources:
        mem_mb=10000,
    script:
        "../scripts/asv_calling.R"


rule AggregateBatches:
    input:
        batches_seqtab=lambda wc: expand("<temp>/batch/{batch}/seqtab.rds", batch=SAMPLES["batch"].unique()),
    output:
        seqtab="<temp>/seqtab.rds",
    conda:
        "../envs/dada2-pipe.yaml"
    script:
        "../scripts/aggregate_seqtabs_batches.R"


rule ChimeraRemoval:
    input:
        seqtab="<temp>/seqtab.rds",
    output:
        seqtab_nochim="<temp>/seqtab_nochim.rds",
    conda:
        "../envs/dada2-pipe.yaml"
    threads: 8
    resources:
        mem_mb=10000,
    script:
        "../scripts/chimera_removal.R"


rule AssignTaxonomy:
    input:
        seqtab_nochim="<temp>/seqtab_nochim.rds",
        silva=config["resources"]["silva_db"],
    output:
        tax="<temp>/taxonomy.rds",
    conda:
        "../envs/dada2-pipe.yaml"
    threads: 8
    script:
        "../scripts/assign_taxonomy.R"


rule SaveResults:
    input:
        seqtab="<temp>/seqtab.rds",
        seqtab_nochim="<temp>/seqtab_nochim.rds",
        filterAndTrimReports=lambda wc: expand("<reports>/qc/filterAndTrim/report_{sra_run}.tsv", sra_run=SAMPLES.index),
        taxa="<temp>/taxonomy.rds",
        metadata=config["samples"],
    output:
        reads_loss_summary="<results>/reads_loss_summary.tsv",
        fa="<results>/ASVs.fa",
        counts="<results>/ASVs_counts.tsv",
        tax="<results>/ASVs_taxa.tsv",
        reads_loss_plot="<figures>/reads_loss_plot.png",
        red_zone_samples="<results>/red_zone_samples.txt",
        ps_raw="<temp>/ps_raw.rds",
    conda:
        "../envs/dada2-save.yaml"
    script:
        "../scripts/save_dada2_results.R"
