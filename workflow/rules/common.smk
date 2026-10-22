# Shared code: config/sample-sheet validation and input helper functions.
# Imported first by the Snakefile, so everything defined here is visible to all rules.
import pandas as pd
from snakemake.utils import validate

# Fails early with a readable message on a missing key or a typo in config/config.yaml.
validate(config, schema="../schemas/config.schema.yaml")

SAMPLES = (
    pd.read_csv(config["samples"], sep="\t", dtype=str, comment="#").set_index("sample_id", drop=False).sort_index()
)
validate(SAMPLES, schema="../schemas/samples.schema.yaml")


wildcard_constraints:
    sample="|".join(SAMPLES.index),


def sample_group(wildcards):
    return SAMPLES.loc[wildcards.sample, "group"]
