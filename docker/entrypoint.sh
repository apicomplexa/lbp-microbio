#!/usr/bin/env bash
# Container entry point: runs the workflow (reads -> PICRUSt2) in /work and
# packs everything needed to continue the analysis into /work/results.zip
# and /work/data_temp.zip.
#
#   /opt/lbp-microbio   code (read-only, from the image)
#   /input/samples.tsv  sample sheet (mounted read-only)
#   /work               working directory: data, resources (SILVA), results, logs,
#                       Snakemake state; survives restarts, so a rerun resumes
#
# Arguments are passed to snakemake (e.g. `--cores 16`, `--dry-run`).
set -euo pipefail

CODE=/opt/lbp-microbio
WORK=/work
SAMPLES=/input/samples.tsv

die() {
    echo "ОШИБКА: $*" >&2
    exit 1
}

[[ -f $SAMPLES ]] || die "не найден файл с образцами ($SAMPLES). Запускайте через ./run-pipeline.sh /путь/к/samples.tsv"
[[ -w $WORK ]] || die "рабочая папка $WORK недоступна для записи"

# The container may run under an arbitrary host uid without a home directory;
# conda, R and sra-tools want a writable $HOME.
if [[ -z ${HOME:-} || ! -w ${HOME:-/} ]]; then
    export HOME=$WORK/.home
fi
mkdir -p "$HOME" "$WORK/config"
export XDG_CACHE_HOME=$HOME/.cache

# `configfile: "config/config.yaml"` in the Snakefile is resolved against the
# working directory: always take the copy shipped with this image.
cp "$CODE/config/config.yaml" "$WORK/config/config.yaml"
# Some scripts source helpers by repo-relative paths (workflow/scripts/plots/...)
ln -sfn "$CODE/workflow" "$WORK/workflow"

cd "$WORK"
# Activation script of the pixi `runner` env, generated at build time
# shellcheck disable=SC1091
source "$CODE/activate.sh"

snakemake_cmd=(
    snakemake
    --snakefile "$CODE/workflow/Snakefile"
    --workflow-profile "$CODE/workflow/profiles/docker"
    --configfile "$CODE/docker/config.docker.yaml"
)

# A previous run killed hard (power loss, docker kill) leaves a lock behind
"${snakemake_cmd[@]}" --unlock >/dev/null 2>&1 || true

echo "=== lbp-microbio: запуск пайплайна (ядер: $(nproc)) ==="
status=0
"${snakemake_cmd[@]}" "$@" || status=$?

# --dry-run / --help etc.: nothing to pack
for arg in "$@"; do
    case $arg in -n | --dry-run | --dryrun | -h | --help | --unlock | --version) exit $status ;; esac
done

python "$CODE/docker/pack_results.py" "$WORK" "$CODE" "$status"

if [[ $status -eq 0 ]]; then
    echo "=== Готово. Результат: results.zip и data_temp.zip в рабочей папке ==="
else
    echo "=== Пайплайн завершился с ошибкой (код $status). results.zip и data_temp.zip содержат то, что успело посчитаться, и логи. ===" >&2
    echo "=== Повторный запуск той же командой продолжит с места остановки. ===" >&2
fi
exit $status
