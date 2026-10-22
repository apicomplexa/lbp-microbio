"""Simulate a toy feature-count table for one sample (example rule)."""

import logging

import numpy as np
import pandas as pd

logging.basicConfig(filename=snakemake.log[0], level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

rng = np.random.default_rng(snakemake.params.seed)
mean = 120 if snakemake.params.group == "case" else 100
counts = rng.poisson(mean, size=snakemake.params.n_features)

table = pd.DataFrame(
    {
        "sample_id": snakemake.wildcards.sample,
        "feature": [f"F{i:03d}" for i in range(1, len(counts) + 1)],
        "count": counts,
    }
)
table.to_csv(snakemake.output[0], sep="\t", index=False)
logging.info("wrote %d features for %s", len(table), snakemake.wildcards.sample)
