"""Validate project SQL against marketingdb_v2 in Docker."""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCKER = [
    "docker",
    "exec",
    "-i",
    "hexlet-marketingdb",
    "psql",
    "-U",
    "postgres",
    "-d",
    "marketingdb_v2",
    "-v",
    "ON_ERROR_STOP=1",
]


def run_sql(sql: str) -> None:
    proc = subprocess.run(
        DOCKER,
        input=sql.encode("utf-8"),
        capture_output=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.decode("utf-8", errors="replace"))


def split_dashboard_queries(text: str) -> list[str]:
    parts = re.split(r"(?m)^-- \d+\.", text)
    queries: list[str] = []
    for part in parts[1:]:
        match = re.search(r"(?is)\b(with|select)\b.*", part)
        if not match:
            continue
        q = match.group(0).strip()
        if not q.endswith(";"):
            q += ";"
        queries.append(q)
    return queries


def main() -> int:
    for name in ("last_paid_click.sql", "aggregate_last_paid_click.sql"):
        print(f"Validating {name}...")
        run_sql((ROOT / name).read_text(encoding="utf-8"))

    dashboard = (ROOT / "dashboard.sql").read_text(encoding="utf-8")
    queries = split_dashboard_queries(dashboard)
    print(f"Validating dashboard.sql ({len(queries)} queries)...")
    for i, q in enumerate(queries, 1):
        run_sql(q)
        print(f"  query {i} OK")

    if not (ROOT / "presentation.pdf").exists():
        print("Missing presentation.pdf")
        return 1

    print("All checks passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(exc)
        raise SystemExit(1)