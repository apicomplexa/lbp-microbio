# {{PROJECT_NAME}}

{{DESCRIPTION}}

<!-- 2–4 sentences: biological question, data, main methods. -->

## Quick start

Requires [pixi](https://pixi.sh) (`curl -fsSL https://pixi.sh/install.sh | sh`) and Linux x86-64.

```bash
git clone <repo-url> && cd {{PROJECT_NAME}}
pixi install                 # interactive env: Snakemake, R, Python, Quarto, tooling
# put input data / references in place — see "Data" below
pixi run dry-run             # what would be executed
pixi run workflow            # run; extra args are passed to snakemake, e.g. --cores 16
```

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

- [ ] …

## Citation / license

<!-- How to cite; license of code and of data. -->
