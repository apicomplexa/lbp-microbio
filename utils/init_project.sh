#!/usr/bin/env bash
# Turn a fresh copy of the template into a new project.
#
#   pixi run init <project-name> ["One-line description"] [--drop-example]
#
# * sets the workspace name in pixi.toml
# * replaces README.md with README.template.md filled with name/description
# * with --drop-example removes the example module, its scripts, report and config
# * installs git hooks; removes this script
set -euo pipefail

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

drop_example=false
args=()
for a in "$@"; do
    case "$a" in
        --drop-example) drop_example=true ;;
        -h|--help) usage ;;
        *) args+=("$a") ;;
    esac
done
[[ ${#args[@]} -ge 1 ]] || usage
name=${args[0]}
desc=${args[1]:-"TODO: one-line description of the project."}
[[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "project name may only contain letters, digits, '.', '_' and '-'" >&2; exit 1; }

cd "$(dirname "$0")/.."
[[ -f README.template.md ]] || { echo "README.template.md not found — project already initialised?" >&2; exit 1; }

# escape for the sed replacement side
esc() { printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'; }

sed -i.bak "s|^name = \".*\"|name = \"$(esc "$name")\"|" pixi.toml && rm pixi.toml.bak
sed -e "s|{{PROJECT_NAME}}|$(esc "$name")|g" -e "s|{{DESCRIPTION}}|$(esc "$desc")|g" \
    README.template.md > README.md
rm README.template.md

if $drop_example; then
    rm -f workflow/rules/example.smk workflow/scripts/simulate_counts.py \
          workflow/scripts/summarize_counts.R workflow/report/example_report.qmd
    sed -i.bak '/include: "rules\/example.smk"/d; s|"<reports>/example_report.html",|# TODO: final targets|' workflow/Snakefile
    # drop the `example:` block (and its comment line) from config + schema
    sed -i.bak '/^# Parameters of the example module/,$d' config/config.yaml
    python - <<'PY'
import re, pathlib
p = pathlib.Path("workflow/schemas/config.schema.yaml")
p.write_text(re.sub(r"  example:\n(?:    .*\n)+", "", p.read_text()))
PY
    rm -f workflow/Snakefile.bak config/config.yaml.bak
    echo "example module removed — add your rules and targets in workflow/Snakefile"
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
    pre-commit install >/dev/null && echo "pre-commit hooks installed"
fi

rm -- "$0"
echo "initialised '$name'. Next: review README.md, then 'pixi run dry-run'."
