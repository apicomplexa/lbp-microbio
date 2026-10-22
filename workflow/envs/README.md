# workflow/envs/ — generated, do not edit

Every `*.yaml` / `*.pin.txt` here is exported from `pixi.toml` + `pixi.lock`
by `pixi run export-envs` (also run automatically before `pixi run workflow`
and by the pre-commit hook). Rules reference them as `conda: "../envs/<env>.yaml"`.

To change an environment: edit `pixi.toml` (or `pixi add --feature <env> <pkg>`),
then `pixi run export-envs` and commit `pixi.toml`, `pixi.lock` and `workflow/envs/`.
