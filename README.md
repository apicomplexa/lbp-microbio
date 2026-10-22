# snakemake-pixi-template

Template repository for bioinformatics analyses built on **Snakemake + R +
Python**, with **pixi** as the single package manager. One lock file describes
every environment — the interactive one you use in notebooks and the per-rule
conda environments Snakemake runs — so a project moves between laptop,
workstation and cluster without "works on my machine" drift.

The layout follows Snakemake's
[standardized structure](https://snakemake.readthedocs.io/en/stable/snakefiles/deployment.html#distribution-and-reproducibility),
so workflows built from it can be deployed with `snakedeploy` and listed in the
Snakemake workflow catalog.

> This README explains the **template**. `README.template.md` is the skeleton
> for the **project** README; `pixi run init` swaps them.

---

## Starting a new project

1. Create the repository
   - GitHub: mark this repo as a *Template repository* (Settings → General) and
     press **Use this template**, or `gh repo create my-project --template <owner>/snakemake-pixi-template --private --clone`
   - locally: `git clone --depth 1 <template-url> my-project && cd my-project && rm -rf .git && git init`
2. Install pixi once per machine: `curl -fsSL https://pixi.sh/install.sh | sh`
3. Initialise:

   ```bash
   pixi install                                         # default env (~ a few minutes)
   pixi run init my-project "16S analysis of ..."       # name, README, git hooks
   pixi run workflow                                    # run the bundled example end-to-end
   ```

   The example (`workflow/rules/example.smk`) is a three-rule DAG — Python
   rule → R rule → Quarto report — that exercises every layer of the template.
   Open `results/reports/example_report.html` to check that everything works,
   then remove it with `pixi run init ... --drop-example` (at init time) or by
   hand: delete `rules/example.smk`, its scripts/report, its `include:` and the
   `example:` config block.
4. Add your packages (see [Environments](#environments)), rules, scripts.

---

## Layout

```
.
├── pixi.toml / pixi.lock      all software: features, environments, tasks
├── pyproject.toml             ruff + snakefmt config only (no dependencies)
├── air.toml  .lintr           R formatter / linter
├── .pre-commit-config.yaml    git hooks
├── _quarto.yml                Quarto project settings for every .qmd
├── .gitignore .gitattributes
├── .vscode/                   VS Code + Positron settings, recommended extensions
├── README.md                  ← this file (template docs)
├── README.template.md         skeleton for the project README
│
├── config/                    WHAT to analyse — the only place users edit
│   ├── config.yaml            parameters + pathvars
│   ├── samples.tsv            sample sheet
│   └── README.md              key-by-key documentation
├── data/{raw,temp}/           inputs and intermediates (not tracked)
├── resources/                 reference DBs, external metadata (not tracked)
├── results/  logs/            outputs (not tracked; created by Snakemake)
├── utils/                     repo maintenance: export_envs.py, init_project.sh
└── workflow/
    ├── Snakefile              entry point, `rule all`
    ├── rules/*.smk            rule modules; common.smk = validation + helpers
    ├── scripts/               R / Python scripts for `script:` rules
    │   └── common/            shared helpers, source()d / imported by scripts
    ├── envs/                  GENERATED rule conda envs (yaml + pin.txt)
    ├── report/*.qmd           Quarto reports rendered by rules
    ├── notebooks/             exploratory notebooks (_eda_*, _dev_*)
    ├── schemas/               JSON schemas for config + sample sheet
    └── profiles/default/      HOW to run: cores, memory, conda
```

---

## Where configuration lives

Configs are split by **who reads them**, not by convenience:

| Location | Contents | Rule |
|---|---|---|
| **repo root** | `pixi.toml`, `pyproject.toml`, `air.toml`, `.lintr`, `_quarto.yml`, `.pre-commit-config.yaml`, `.git*`, `.vscode/` | Tool configs. Tools discover them from the project root; moving them breaks auto-discovery (or requires env vars per tool). Nobody edits them during an analysis. |
| **`config/`** | `config.yaml`, `samples.tsv` | *What* to analyse: scientific parameters, sample sheet, directory layout (pathvars). Validated by `workflow/schemas/`. The only directory a workflow user is expected to touch. |
| **`workflow/profiles/`** | `default/config.yaml`, `<machine>/config.yaml` | *How* to run: cores, memory, conda, cluster executor. Machine-specific, never affects results. |

Consequences:

- Changing a value in `config/` may change results → it is part of the
  analysis record. Changing a profile never should.
- A new machine or cluster = a new `workflow/profiles/<name>/config.yaml`, run
  with `--workflow-profile workflow/profiles/<name>`.
- Paths in rules use [pathvars](https://snakemake.readthedocs.io/) from
  `config.yaml` (`"<results>/table.tsv"`), so the directory layout is defined once.

---

## Environments

### Design

`pixi.toml` is the **only** place packages are declared. It is split into
[features](https://pixi.prefix.dev/latest/workspace/multi_environment/) that
are combined into environments:

| Environment | Features | Used by |
|---|---|---|
| `default` | default (snakemake, conda, python, pandas, graphviz) + `r` + `py` + `dev` | you: terminal, notebooks, editors, Quarto preview, `pixi run …` tasks |
| `r` | `r` | rules with `conda: "../envs/r.yaml"` |
| `py` | `py` | rules with `conda: "../envs/py.yaml"` |

`pixi run export-envs` (`utils/export_envs.py`) writes, for every environment
except `default`:

- `workflow/envs/<env>.yaml` — readable spec with version ranges;
- `workflow/envs/<env>.linux-64.pin.txt` — conda *explicit* spec with exact
  package URLs and md5 sums, taken from `pixi.lock`.

Snakemake automatically prefers `<env>.<platform>.pin.txt` next to the yaml,
so rule envs are installed **exactly** as locked.

All environments share `solve-group = "main"`: a package that appears in
several environments gets the same version everywhere, so code you prototype in
a notebook (`default`) behaves identically inside a rule (`r`/`py`).

### Why this design (and not the alternatives)

| Option | Verdict |
|---|---|
| **pixi multi-env → exported `workflow/envs/` (chosen)** | One lock file; reproducible to the package hash; the workflow stays a standard Snakemake workflow that runs with plain conda (clusters, `snakedeploy`, catalog) without pixi. Cost: an export step — automated via task dependency + pre-commit hook. |
| Rules point to `.pixi/envs/<env>` directly (`conda:` accepts an env path) | No export, but the workflow only works where pixi has installed the envs; breaks on clusters without a shared FS and for anyone deploying the workflow without pixi. |
| One monolithic pixi env + hand-written `workflow/envs/*.yaml` | Simplest, but two sources of truth: versions in pixi and in the yaml drift apart, and the rule envs are not locked. |

### Everyday operations

```bash
# add a package to an existing rule env (+ default, which includes the feature)
pixi add --feature r bioconductor-phyloseq
pixi run export-envs
git add pixi.toml pixi.lock workflow/envs

# a new rule env for a tool with heavy/conflicting deps, e.g. QC
pixi add --feature qc fastqc multiqc          # creates [feature.qc.dependencies]
#   then in pixi.toml [environments]:
#   qc = { features = ["qc"], no-default-feature = true, solve-group = "main" }
#   and add "qc" to `default` features if you want it interactively too
pixi run export-envs                          # -> workflow/envs/qc.yaml (+ pin)
#   in the rule:  conda: "../envs/qc.yaml"

# a tool that cannot share versions (e.g. PICRUSt2 pinning an old Python):
#   picrust2 = { features = ["picrust2"], no-default-feature = true }   # no solve-group

# dev-only tools (never exported)
pixi add --feature dev r-styler
```

Other platforms: add e.g. `"osx-arm64"` to `platforms` in `pixi.toml`; the
export will then also write `<env>.osx-arm64.pin.txt` (check that all bioconda
packages exist for it).

`pixi run workflow` / `dry-run` always run `export-envs` first (cached on
`pixi.lock`), and the pre-commit hook fails a commit if `workflow/envs/` is out
of sync with the lock — just `git add workflow/envs` and commit again.

---

## Tasks

`pixi task list` shows all. Extra arguments are passed through, e.g.
`pixi run workflow --cores 16 results/example/summary.tsv`.

| Task | What it does |
|---|---|
| `workflow` / `dry-run` | run Snakemake / dry run (export envs first) |
| `unlock` | remove a stale Snakemake lock |
| `dag` | job DAG → `results/reports/workflow-dag.pdf` |
| `sm-report` | Snakemake run report → `results/reports/snakemake-report.html` |
| `export-envs` | regenerate `workflow/envs/` from the lock |
| `fmt` | format Python (ruff), Snakemake (snakefmt), R (air) |
| `lint` | ruff + snakefmt --check + `snakemake --lint` + lintr; non-zero on findings |
| `hooks` | install git pre-commit hooks |
| `init` | one-off project initialisation (removes itself) |

---

## Conventions

- **Run from the repo root.** `configfile:`, pathvars, Quarto `execute-dir:
  project` and notebook working dir all assume it.
- **Every rule has a `log:`.** R scripts redirect with `sink()`, Python
  scripts with `logging` (see the example scripts); R scripts end with
  `sessionInfo()`.
- **Scripts read everything from the `snakemake` object** — no hard-coded paths.
  Shared code goes to `workflow/scripts/common/`.
- **Validate config**: when adding a key to `config.yaml`, add it to
  `workflow/schemas/config.schema.yaml` and to `config/README.md`.
- **Notebooks** (`workflow/notebooks/`): `_eda_*` for exploration, `_dev_*` for
  prototyping a rule script; promote stable code to `scripts/` + a rule,
  deliverables to `report/*.qmd`.
- **Reports**: Quarto `.qmd` in `workflow/report/`, rendered by a rule into
  `results/reports/` as a self-contained HTML (see `render_example_report`).
  PDF output needs TeX: `pixi run quarto install tinytex`.
- **Secrets** (API keys, `TG_BOT_TOKEN`) go to environment variables or an
  untracked `.env`, never to config or envs.

---

## Tooling

| Language | Formatter | Linter | Config |
|---|---|---|---|
| Python | ruff format | ruff check | `pyproject.toml` |
| Snakemake | snakefmt | `snakemake --lint` | `pyproject.toml` |
| R | air | lintr | `air.toml`, `.lintr` |

Pre-commit (`pixi run hooks` once per clone) runs the formatters, basic
hygiene checks (large files, private keys, merge markers, YAML/TOML syntax)
and the `workflow/envs` sync check. Local hooks call tools via `pixi run`, so
their versions come from `pixi.lock`.

### Editors (VS Code / Positron)

Open the folder, install the recommended extensions (`.vscode/extensions.json`)
and run `pixi install`.

- Python: the *pixi-code* extension exposes pixi envs to the Python extension;
  `default` is preselected.
- R in VS Code: `r.rpath`/`r.libPaths` point to `.pixi/envs/default`.
- R in Positron: choose the interpreter from `.pixi/envs/default` in the
  interpreter picker (Positron also scans `positron.r.customRootFolders`).
- Formatting on save: ruff for Python, air for R.
- Jupyter kernels: Python and R (IRkernel) from the `default` env; notebooks
  run from the repo root.

---

## Optional: Telegram notifications

`workflow/rules/notify.smk` sends a message on start, success and failure (with
the log tail). Enable with `notify: {telegram: true}` in `config/config.yaml`
and export `TG_BOT_TOKEN` and `TG_CHAT_ID`. Missing variables only produce a
warning.

---

## Updating a project from the template

The template is not a dependency: projects copy it once. To pull later
improvements, add it as a remote and cherry-pick or diff selected files:

```bash
git remote add template <template-url> && git fetch template
git diff HEAD template/main -- .pre-commit-config.yaml utils/export_envs.py
```
