rule FunctionalAnalysis:
    input:
        fa="<results>/ASVs.fa",
        counts="<results>/ASVs_counts.tsv",
    output:
        path="<results>/picrust2/pathways_out/path_abun_unstrat.tsv.gz",
        ko="<results>/picrust2/KO_metagenome_out/pred_metagenome_unstrat.tsv.gz",
    conda:
        "../envs/func.yaml"
    threads: 10
    resources:
        mem_mb=10000,
    params:
        outdir=lambda wc, output: subpath(output.path, ancestor=2),
        nsti=2,
    shell:
        """
        rm -rf {params.outdir}
        picrust2_pipeline.py \
            -s {input.fa} \
            -i {input.counts} \
            -o {params.outdir} \
            -p {threads} \
            --max_nsti {params.nsti} \
            --verbose
        """
