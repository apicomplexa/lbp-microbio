rule LoadFastqBySRR:
    output:
        fq=temp(expand("<samples>/raw/{{sample}}_{n}.fastq", n=[1, 2])),
    retries: 3
    conda:
        "../envs/load-samples.yaml"
    params:
        outDir=lambda wc, output: subpath(output.fq[0], parent=True),
    shell:
        "fasterq-dump {wildcards.sample} -O {params.outDir}"


rule CompressAndRenameFastq:
    input:
        fq="<samples>/raw/{sample}_{n}.fastq",
    output:
        fq="<samples>/raw/{sample}_R{n}.fastq.gz",
    shell:
        "gzip -c {input.fq} > {output.fq}"


rule CutAdapters:
    input:
        fastq=expand("<samples>/raw/{{sample}}_R{n}.fastq.gz", n=[1, 2]),
    output:
        fastq=temp(expand("<samples>/trimmed/{{sample}}_R{n}.fastq.gz", n=[1, 2])),
        report="<reports>/qc/cutadapt/report_{sample}.json.gz",
    log:
        "<logs>/cutadapt/{sample}.log",
    conda:
        "../envs/load-samples.yaml"
    shell:
        "cutadapt "
        "-g CCTACGGGNGGCWGCAG "
        "-G GACTACHVGGGTATCTAATCC "
        "-m 215 -M 285 --discard-untrimmed "
        "-o {output.fastq[0]} -p {output.fastq[1]} "
        "{input} --json={output.report} > {log} 2>&1"


rule FilterAndTrim:
    input:
        fq=expand("<samples>/trimmed/{{sample}}_R{n}.fastq.gz", n=[1, 2]),
    output:
        fq=expand("<samples>/filtered/{{sample}}_R{n}.fastq.gz", n=[1, 2]),
        report="<reports>/qc/filterAndTrim/report_{sample}.tsv",
    conda:
        "../envs/load-samples.yaml"
    resources:
        mem_mb=1100,
    params:
        trunc_len_f=config["trimming"]["trunc_len_f"],
        trunc_len_r=config["trimming"]["trunc_len_r"],
        max_ee_f=config["trimming"]["max_ee_f"],
        max_ee_r=config["trimming"]["max_ee_r"],
    script:
        "../scripts/dada2_filter_and_trim.R"
