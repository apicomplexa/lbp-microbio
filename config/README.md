# Configuration

Everything a user of this workflow is expected to edit lives here.

| File | Purpose |
|---|---|
| `config.yaml` | Analysis parameters and directory layout (`pathvars`). Validated against `workflow/schemas/config.schema.yaml`. |
| `samples.tsv` | Sample sheet, one row per sample. Validated against `workflow/schemas/samples.schema.yaml`. |

## `config.yaml` keys

| Key | Description |
|---|---|
| `samples` | Path to the sample sheet. |
| `pathvars.*` | Directories referenced in rules as `<name>` (e.g. `<results>/table.tsv`). |
| `notify.telegram` | Send start/success/failure messages to Telegram (needs `TG_BOT_TOKEN`, `TG_CHAT_ID`). |
| `example.*` | Parameters of the example module — remove together with it. |

## `samples.tsv` columns

| Column | Description |
|---|---|
| `sample_id` | Unique sample name (letters, digits, `_`, `-`); becomes the `{sample}` wildcard. |
| `group` | Experimental group. |

Execution settings (cores, memory, conda, cluster executor) are **not**
configured here — see `workflow/profiles/`.
