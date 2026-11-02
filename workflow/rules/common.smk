# Shared code: config/sample-sheet validation and input helper functions.
# Imported first by the Snakefile, so everything defined here is visible to all rules.
from pathlib import Path
import pandas as pd
from snakemake.utils import validate

# Fails early with a readable message on a missing key or a typo in config/config.yaml.
validate(config, schema="../schemas/config.schema.yaml")

samples_sheet = Path(config["samples"])
if samples_sheet.is_file():

    SAMPLES = (
        pd.read_csv(samples_sheet, sep="\t", dtype=str, comment="#")
        .set_index(config["samples_index_col"], drop=False)
        .sort_index()
    )

    validate(SAMPLES, schema="../schemas/samples.schema.yaml")

    wildcard_constraints:
        sample="|".join(SAMPLES.index),
        batch="|".join(SAMPLES["batch"].unique()),

else:
    SAMPLES = []


def sample_group(wildcards):
    return SAMPLES.loc[wildcards.sample, "batch"]


def samples_by_group(wildcards):
    return SAMPLES[SAMPLES["batch"] == wildcards.batch]
