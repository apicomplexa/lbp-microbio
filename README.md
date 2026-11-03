# lbp-microbio

Analysis of the correlations between the gut microbiome and the level of lipopolysaccharide-binding protein (LBP) based on targeted sequencing data of the V3-V4 region of 16S rRNA

<!-- 2–4 sentences: biological question, data, main methods. -->

## Quick start

Requires [pixi](https://pixi.sh) (`curl -fsSL https://pixi.sh/install.sh | sh`) and Linux x86-64.

```bash
git clone <repo-url> && cd lbp-microbio
pixi install                 # interactive env: Snakemake, R, Python, Quarto, tooling
# put input data / references in place — see "Data" below
pixi run dry-run             # what would be executed
pixi run workflow            # run; extra args are passed to snakemake, e.g. --cores 16
```

On another machine with only Docker: `./run-pipeline.sh /path/to/samples.tsv`
runs reads → PICRUSt2 and leaves `lbp-run/results.zip` + `lbp-run/data_temp.zip` (see [docker/README.md](docker/README.md)).

Other tasks: `pixi run dag` (job graph → `results/reports/workflow-dag.pdf`),
`pixi run sm-report`, `pixi run lint`, `pixi run fmt`; `pixi task list` shows all.

Without pixi (e.g. on a cluster): any Snakemake ≥ 9.19 with conda can run the
workflow — rule environments are pinned in `workflow/envs/`:
`snakemake --sdm conda --cores 16`.

## Data

| Input | Location | Source |
|---|---|---|
| Raw reads | `data/raw/` | <!-- SRA project / sequencing facility --> |
| Reference DB | `resources/` | <!-- URL + version --> |
| Sample sheet | `config/samples.tsv` | tracked |

<!-- Privacy: say what must never be committed (clinical metadata, etc.). -->

## Configuration

- `config/config.yaml` — analysis parameters (documented in `config/README.md`)
- `config/samples.tsv` — sample sheet
- `workflow/profiles/default/config.yaml` — cores, memory, conda; add
  `workflow/profiles/<machine>/` for other machines and run with
  `--workflow-profile workflow/profiles/<machine>`

## Pipeline

<!-- One paragraph per module: what goes in, what tool, what comes out. -->

| Step | Rules file | Main outputs |
|---|---|---|
| | `workflow/rules/….smk` | `results/…` |

## Outputs

| Path | Content |
|---|---|
| `results/` | tables |
| `results/figures/` | figures |
| `results/reports/` | rendered Quarto reports |

## Layout

```
config/            analysis parameters + sample sheet
data/{raw,temp}/   input data and intermediates (not tracked)
resources/         reference databases (not tracked)
results/ logs/     outputs and rule logs (not tracked)
workflow/
  Snakefile        entry point, `rule all`
  rules/           rule modules (*.smk)
  scripts/         R / Python scripts run by rules; common/ = shared helpers
  envs/            rule conda envs — GENERATED from pixi.toml, do not edit
  report/          Quarto reports rendered by rules
  notebooks/       exploratory notebooks (not part of the DAG)
  schemas/         JSON schemas validating config and sample sheet
  profiles/        execution profiles
```

## Software environments

All software is declared in `pixi.toml` and locked in `pixi.lock`. To add a package:

```bash
pixi add --feature r r-vegan     # or --feature py / a new feature
pixi run export-envs             # regenerate workflow/envs/
git add pixi.toml pixi.lock workflow/envs
```

## Roadmap

### Upstream & ASV inference
- [x] SRA download + primer trimming (cutadapt) + DADA2 quality filtering, with QC reports
- [ ] Contaminant removal (+ mitochondrial and plasmid DNA)
- [x] Error models + per-batch ASV calling (DADA2), batch merge, chimera removal
- [x] Taxonomy assignment (DECIPHER IdTaxa vs SILVA SSU r138.2)
- [x] Results export: ASVs sequences (fasta), ASVs counts per sample, ASV taxonomy tab, Phyloseq object (with all of them), Reads loss per step
- [ ] Prevalence/abundance filtering (core members)

### Diversity — beta
- [x] DESeq2 VST normalization + Euclidean distance matrix
- [x] PCoA ordination + sample dendrogram
- [x] PERMANOVA (adonis2) with covariates (batch, sex, age)
- [x] betadisper / PERMDISP dispersion test (required to interpret PERMANOVA correctly)
- [x] Make it on core members on
  - [x] ASV level
  - [x] Genera level

### Diversity — alpha
- [x] Alpha metrics: Observed, Shannon, Simpson, Chao1 (questionable)
- [x] Hill numbers and curves
- [x] Group tests, covariate-adjusted (case/control)
- [x] Make it on core members on
  - [x] ASV level
  - [x] Genera level
- [ ] Harden alpha/beta report to publish-ready

### Differential abundance — ASVs
- [-] DESeq2 + MaAsLin2 on raw counts for core members on ASVs level and Genera level, covariate-adjusted (case/control)
- [ ] Report, publish-ready

### Functional prediction
- [ ] PICRUSt2 pipeline → KO + pathway unstrat tables (max_nsti 2)
- [ ] NSTI QC: report weighted / per-sample NSTI
- [ ] Map KO to modules (GMM, KEGG) and pathways (especially KEGG)
- [ ] Differential abundance for KO, pathways activity
- [ ] Maybe use some signal molecules (such as SCFA) to predict impact of microbiome to host immune system
- [ ] Functional report, publish-ready

### Community structure
- [ ] DMM clustering: assign community types
  - [ ] Taxonomy level
  - [ ] Functional level
- [ ] Test community type ~ covariates
  - [ ] Taxonomy level
  - [ ] Functional level
- [ ] Construct enterotypes
- [ ] Report, publish-ready

### Covariances analysis
- [ ] Connect specific laboratory and physical metrics with specific genera and enterotype
- [ ] Map of influence (taxa -> marker)
- [ ] Report, publish-ready

### Interaction networks
- [ ] Per-group co-occurrence networks (SPIEC-EASI / SparCC, compositionality-aware)
- [ ] Differential network analysis (e.g. NetCoMi) + hub / keystone taxa
- [ ] Report, publish-ready

### Cross-cutting (publish-readiness)
- [ ] Lock covariate set (batch, sex, age; + antidepressants/PPIs/BMI/Bristol if available) and apply consistently across DA / DMM / networks
- [ ] Consistent FDR across all DA blocks; report effect sizes, not only p-values
- [ ] Fixed seeds for stochastic steps (DMM, SPIEC-EASI) + env/version locking (pixi / Apptainer) + sessionInfo
- [ ] STORMS reporting checklist
- [ ] Unified methods draft + consistent figure style

## Citation / license

<!-- How to cite; license of code and of data. -->
