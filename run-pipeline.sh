#!/usr/bin/env bash
# Run the heavy part of the workflow (reads -> PICRUSt2) in Docker with one command:
#
#   ./run-pipeline.sh /path/to/samples.tsv [extra snakemake args, e.g. --cores 16]
#
# Builds the image on first use, works in ./lbp-run/ (override: LBP_WORKDIR=/big/disk/run)
# and leaves the result in <workdir>/results.zip. Rerunning the same command
# resumes an interrupted run. Details: docker/README.md.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORKDIR=${LBP_WORKDIR:-$REPO/lbp-run}

die() {
    echo "ОШИБКА: $*" >&2
    exit 1
}

[[ $# -ge 1 ]] || die "укажите файл с образцами: $0 /путь/к/samples.tsv"
SAMPLES=$1
shift
[[ -f $SAMPLES ]] || die "файл не найден: $SAMPLES"
SAMPLES=$(cd "$(dirname "$SAMPLES")" && pwd)/$(basename "$SAMPLES")

if command -v docker >/dev/null; then
    ENGINE=docker
    USER_ARGS=(--user "$(id -u):$(id -g)")
elif command -v podman >/dev/null; then
    ENGINE=podman
    USER_ARGS=(--userns=keep-id)
else
    die "не найден docker (https://docs.docker.com/engine/install/)"
fi

COMMIT=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)
IMAGE=lbp-microbio:$COMMIT

if ! $ENGINE image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "=== Сборка образа $IMAGE (только при первом запуске, ~20-40 мин) ==="
    $ENGINE build --build-arg GIT_COMMIT="$COMMIT" -t "$IMAGE" "$REPO"
fi

mkdir -p "$WORKDIR"
echo "=== Рабочая папка: $WORKDIR ==="

TTY_ARGS=()
[[ -t 0 && -t 1 ]] && TTY_ARGS=(-it)

# --stop-timeout: time for snakemake to stop and for results.zip to be packed
exec $ENGINE run --rm --init --stop-timeout 300 "${TTY_ARGS[@]}" "${USER_ARGS[@]}" \
    -v "$WORKDIR:/work:z" \
    -v "$SAMPLES:/input/samples.tsv:ro,z" \
    "$IMAGE" "$@"
