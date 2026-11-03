# resources/

Reference data the workflow reads but does not produce: reference databases,
genomes, annotation files, external metadata. Everything here except this
README is git-ignored.

Document every file you put here (source URL, version, date, checksum) in the
table below — or better, download it with a rule so the workflow can rebuild it.

| File | Source / version | Obtained |
|---|---|---|
| `SILVA_SSU_r138.2_v2.RData` | DECIPHER IdTaxa training set, SILVA SSU r138.2 ([decipher.codes/Downloads](https://decipher.codes/Downloads.html), Google Drive). Downloaded by rule `DownloadSilva`; SHA-256 in `config/config.yaml` | automatically |
