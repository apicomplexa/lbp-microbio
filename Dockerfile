# Heavy part of the workflow (SRA reads -> DADA2 -> taxonomy -> PICRUSt2) as a
# self-contained image. Usage: ./run-pipeline.sh /path/to/samples.tsv (see docker/README.md).
#
# The image contains code and software only. Never add data to it: the sample
# sheet is mounted at run time, SILVA is downloaded by the workflow itself into
# the working directory. .dockerignore whitelists what may enter the build
# context, and the last RUN fails the build if anything sensitive slipped in.
FROM ghcr.io/prefix-dev/pixi:0.81.0-noble

ARG GIT_COMMIT=unknown
WORKDIR /opt/lbp-microbio

# 1. Orchestration env (Snakemake + conda), exactly as in pixi.lock
COPY pixi.toml pixi.lock ./
RUN pixi install --locked --environment runner \
    && pixi shell-hook --locked --environment runner > activate.sh \
    && rm -rf /root/.cache/rattler

# 2. Workflow code
COPY workflow/ workflow/
COPY config/config.yaml config/config.yaml
COPY docker/config.docker.yaml docker/config.docker.yaml

# 3. Pre-build the rule conda envs into /opt/snakemake-conda (the docker profile's
#    conda-prefix), so the target machine does not solve or download them.
#    Snakemake needs a DAG for that; a fake two-sample sheet provides one.
RUN set -eu \
    && . ./activate.sh \
    && mkdir -p /tmp/envbuild/config /input \
    && cp config/config.yaml /tmp/envbuild/config/ \
    && printf 'Run\tbatch\tlpb_tertile\nSRR0000001\tB1\tНизкий ЛПБ\nSRR0000002\tB1\tВысокий ЛПБ\n' > /input/samples.tsv \
    && cd /tmp/envbuild \
    && snakemake --snakefile /opt/lbp-microbio/workflow/Snakefile \
        --workflow-profile /opt/lbp-microbio/workflow/profiles/docker \
        --configfile /opt/lbp-microbio/docker/config.docker.yaml \
        --conda-create-envs-only --cores 1 \
    && conda clean --all --yes \
    && cd / && rm -rf /tmp/envbuild /input /root/.cache \
    && chmod -R a+rX /opt/snakemake-conda /opt/lbp-microbio

# Run-time scripts last: editing them does not invalidate the env layer above
COPY docker/ docker/
RUN echo "$GIT_COMMIT" > COMMIT

# 4. Guard: no sample sheets, clinical tables, reference DBs or secrets in the image
#    (software envs are skipped: R packages ship their own example .xlsx etc.)
RUN found=$(find /opt/lbp-microbio /tmp /root /input -path /opt/lbp-microbio/.pixi -prune -o \
        \( -name 'samples*.tsv' -o -name '*.dta' -o -name '*.xlsx' -o -name '*.RData' \
        -o -name 'SraRunTable*' -o -name 'ids_map*' -o -name '.env' \) -print 2>/dev/null || true) \
    && if [ -n "$found" ]; then echo "Sensitive files in the image:"; echo "$found"; exit 1; fi

# `docker run --init` (tini): forward `docker stop` to snakemake as well, not only
# to the entry point, so it stops gracefully and results.zip is still packed
ENV TINI_KILL_PROCESS_GROUP=1
ENTRYPOINT ["/opt/lbp-microbio/docker/entrypoint.sh"]
