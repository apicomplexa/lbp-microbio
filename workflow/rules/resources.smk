# Reference data downloaded over HTTP(S) via snakemake-storage-plugin-http.
# The plugin does not verify checksums, so outputs are checked with ensure(sha256=...).


storage:
    provider="http",


rule DownloadSilva:
    input:
        # ancient(): an already downloaded copy is not fetched again when the remote file is newer
        ancient(storage.http(config["resources"]["silva_db_url"])),
    output:
        ensure(config["resources"]["silva_db"], sha256=config["resources"]["silva_db_sha256"]),
    shell:
        "cp {input} {output}"
