#!/usr/bin/env python3
"""Export canon.db tables to game/data/*.json so Godot/GDScript can read them.

canon.db has no native GDScript driver without a third-party binary addon, so
the game reads plain JSON instead -- one file per table, loaded generically
by scripts/canon.gd. Run this any time canon.xlsx changes:

    python build_sqlite.py
    python export_canon_json.py
"""
import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).parent
DB_PATH = ROOT / "canon.db"
OUT_DIR = ROOT / "game" / "data"


def export() -> None:
    if not DB_PATH.exists():
        sys.exit(f"{DB_PATH} not found -- run build_sqlite.py first")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute(
        "select name from sqlite_master where type='table' and name not like 'sqlite_%'"
    )
    tables = sorted(row[0] for row in cur.fetchall())

    for table in tables:
        cur.execute(f"select * from {table}")
        rows = [dict(row) for row in cur.fetchall()]
        out_path = OUT_DIR / f"{table}.json"
        out_path.write_text(json.dumps(rows, indent=2, ensure_ascii=False))
        print(f"  {table}: {len(rows)} rows -> {out_path.relative_to(ROOT)}")

    conn.close()
    print(f"Exported {len(tables)} tables to {OUT_DIR}")


if __name__ == "__main__":
    export()
