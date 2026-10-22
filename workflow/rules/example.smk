# Example module: a three-step DAG touching every layer of the template
# (Python rule env -> R rule env -> Quarto report). Replace it with real rules,
# then drop its include from the Snakefile and the `example:` block from the config.


rule simulate_counts:
    output:
        "<temp>/example/{sample}.tsv",
    log:
        "<logs>/simulate_counts/{sample}.log",
    conda:
        "../envs/py.yaml"
    params:
        group=sample_group,
        n_features=config["example"]["n_features"],
        seed=lambda wc: config["example"]["seed"] + SAMPLES.index.get_loc(wc.sample),
    script:
        "../scripts/simulate_counts.py"


rule summarize_counts:
    input:
        counts=expand("<temp>/example/{sample}.tsv", sample=SAMPLES.index),
        samples=config["samples"],
    output:
        table="<results>/example/summary.tsv",
        figure="<figures>/example_group_totals.pdf",
    log:
        "<logs>/summarize_counts.log",
    conda:
        "../envs/r.yaml"
    script:
        "../scripts/summarize_counts.R"


rule render_example_report:
    input:
        qmd="workflow/report/example_report.qmd",
        summary="<results>/example/summary.tsv",
    output:
        "<reports>/example_report.html",
    log:
        "<logs>/render_example_report.log",
    conda:
        "../envs/r.yaml"
    shell:
        # Quarto writes the HTML next to the .qmd; move it into results afterwards.
        """
        quarto render {input.qmd} --to html -P summary:{input.summary} >{log} 2>&1
        mv workflow/report/example_report.html {output}
        """
