# workflow/notebooks/

Exploratory work, not part of the DAG. Use the pixi `default` env kernel
(Python or R). Notebooks run from the repo root (see `.vscode/settings.json`),
so paths match those in rules.

Naming:

- `_eda_<topic>.(r.)ipynb` — exploratory analysis of results
- `_dev_<rule>.(r.)ipynb` — prototyping code that will become a rule script

When a notebook stabilises, move its code into `workflow/scripts/` and a rule;
when it becomes a deliverable, turn it into a `.qmd` in `workflow/report/`.
