#!/usr/bin/env python
"""Pack workflow outputs into <workdir>/results.zip.

Paths inside the archive are relative to the repository root, so the archive
can be unpacked straight into a clone of the repository:

    results/        all workflow outputs (tables, figures, QC reports, PICRUSt2)
    data/temp/      intermediate R objects (ps_raw.rds, seqtab*.rds, taxonomy.rds, ...)
    logs/           rule logs; logs/snakemake/ holds the Snakemake run logs
    run_info.txt    image commit, date, exit status, versions

Raw and filtered reads (data/samples/) are not included.

Usage: pack_results.py <workdir> <code dir> <snakemake exit status>
"""

import datetime
import os
import platform
import subprocess
import sys
import zipfile
from pathlib import Path

INCLUDE = ["results", "data/temp", "logs"]


def version(cmd: list[str]) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.strip()
    except Exception as e:
        return f"unknown ({e})"


def main(work: Path, code: Path, status: str) -> None:
    target = work / "results.zip"
    partial = target.with_suffix(".zip.part")
    commit = (code / "COMMIT").read_text().strip() if (code / "COMMIT").exists() else "unknown"
    info = "\n".join(
        [
            f"date: {datetime.datetime.now().astimezone().isoformat(timespec='seconds')}",
            f"image commit: {commit}",
            f"snakemake exit status: {status}",
            f"snakemake: {version(['snakemake', '--version'])}",
            f"cpus: {os.cpu_count()}",
            f"host: {platform.platform()}",
        ]
    )

    n = 0
    with zipfile.ZipFile(partial, "w", zipfile.ZIP_DEFLATED, allowZip64=True) as zf:
        for top in INCLUDE:
            for path in sorted((work / top).rglob("*")):
                if path.is_file():
                    zf.write(path, path.relative_to(work).as_posix())
                    n += 1
        for path in sorted((work / ".snakemake" / "log").glob("*.log")):
            zf.write(path, f"logs/snakemake/{path.name}")
            n += 1
        zf.writestr("run_info.txt", info + "\n")
    partial.replace(target)
    size_mb = target.stat().st_size / 2**20
    print(f"results.zip: {n} files, {size_mb:.1f} MB")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
