#!/usr/bin/env python
"""Pack workflow outputs into two archives in <workdir>.

Paths inside the archives are relative to the repository root, so both can be
unpacked straight into a clone of the repository:

    results.zip
        results/        all workflow outputs (tables, figures, QC reports, PICRUSt2)
        logs/           rule logs; logs/snakemake/ holds the Snakemake run logs
        run_info.txt    image commit, date, exit status, versions
    data_temp.zip
        data/temp/      intermediate R objects (ps_raw.rds, seqtab*.rds, taxonomy.rds, ...)

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

# archive name -> directories of the workdir it holds
ARCHIVES = {
    "results.zip": ["results", "logs"],
    "data_temp.zip": ["data/temp"],
}


def version(cmd: list[str]) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.strip()
    except Exception as e:
        return f"unknown ({e})"


def pack(work: Path, name: str, dirs: list[str], extra: dict[str, Path | str]) -> None:
    """Write work/name from dirs plus extra {archive path: file or text}; atomic via a .part file."""
    target = work / name
    partial = target.with_suffix(".zip.part")
    n = 0
    with zipfile.ZipFile(partial, "w", zipfile.ZIP_DEFLATED, allowZip64=True) as zf:
        for top in dirs:
            for path in sorted((work / top).rglob("*")):
                if path.is_file():
                    zf.write(path, path.relative_to(work).as_posix())
                    n += 1
        for arcname, src in extra.items():
            if isinstance(src, Path):
                zf.write(src, arcname)
            else:
                zf.writestr(arcname, src)
            n += 1
    partial.replace(target)
    size_mb = target.stat().st_size / 2**20
    print(f"{name}: {n} files, {size_mb:.1f} MB")


def main(work: Path, code: Path, status: str) -> None:
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
    results_extra: dict[str, Path | str] = {"run_info.txt": info + "\n"}
    for path in sorted((work / ".snakemake" / "log").glob("*.log")):
        results_extra[f"logs/snakemake/{path.name}"] = path
    for name, dirs in ARCHIVES.items():
        pack(work, name, dirs, results_extra if name == "results.zip" else {})


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
