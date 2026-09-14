"""
build_sqlite.py

Purpose: convert canon.xlsx's runtime/game-data tabs into a real SQLite database
         with ENFORCED foreign keys, not just the custom Python validator's
         hand-written checks. This is a second, independent verification method:
         if SQLite's own PRAGMA foreign_key_check agrees the data is clean, that's
         confirmation from a completely different mechanism than canon_validate.py.

Scope:   writer-reference and meta tabs are excluded on purpose -- they document
         design intent, they are not queryable game state. Excluded: README,
         validation, calendar, the_claimant, roster_gaps, epilogue_generation,
         christian_allegory, naming_reference, prologue_tuning.

Known limitation, not fixed here: pipe-delimited multi-value fields
(recruits_unit_ids, forced_deploy_ids, speaker_ids, depends_on_units,
depends_on_flags) are a 1NF violation carried over from the xlsx as-is. Proper
fix is junction tables; that's a real schema decision for whenever an actual
game build exists, not made unprompted here.

Author: drafted for Nick Kogan, 2026-08-21.
"""

import sqlite3
from pathlib import Path

from openpyxl import load_workbook

ROOT = Path(__file__).parent
SRC = ROOT / "canon.xlsx"
OUT = ROOT / "canon.db"

EXCLUDE = {
    "README", "validation", "calendar", "the_claimant", "roster_gaps",
    "epilogue_generation", "christian_allegory", "naming_reference",
    "prologue_tuning", "enums",  # enums handled separately, normalized
}

# tab -> (id_column, id_prefix). Same convention canon_validate.py uses to tell
# real data rows from trailing note text parked in column A.
PK = {
    "sects": ("sect_id", "sect_"), "classes": ("class_id", "cls_"),
    "growths": ("profile_id", "gp_"), "units": ("unit_id", "u_"),
    "maps": ("map_id", "map_"), "chapters": ("chapter_id", "ch_"),
    "epithets": ("epithet_id", "ep_"), "npcs": ("npc_id", "npc_"),
    "scenes": ("scene_id", "sc_"), "regions": ("region_id", "rgn_"),
    "named": ("named_id", "nmd_"), "states": ("state_id", "st_"),
    "defections": ("defection_id", "def_"), "locations": ("location_id", "loc_"),
    "polities": ("polity_id", "pol_"), "settlements": ("settlement_id", "set_"),
    "eras": ("era_id", "era_"), "flashbacks": ("flashback_id", "fb_"),
    "prologue_roster": ("punit_id", "pu_"),
    "prologue_structures": ("structure_id", "str_"),
    "forges": ("forge_id", "frg_"), "materials": ("material_id", "mat_"),
    "ascension_signals": ("signal_id", "sig_"), "endings": ("ending_id", "end_"),
    "signs": ("sign_id", "sgn_"), "practices": ("practice_id", "prc_"),
    "canon_flags": ("flag_id", "flag_"),
    "terrain_costs": ("terrain_id", "ter_"),
    "deputy_ledger": (None, None),  # no natural id -- 'factor' is descriptive text
}

# numeric columns per tab, everything else defaults to TEXT
NUMERIC = {
    "growths": {"hp", "str", "mag", "dex", "spd", "lck", "def", "res", "total_check"},
    "maps": {"width", "height", "turn_limit", "min_solution_units",
             "boss_gated_until_turn", "deploy_slots"},
    "chapters": {"number"},
    "prologue_roster": {"move", "hp", "dmg_vs_statue", "deploy_row", "deploy_col"},
    "prologue_structures": {"turns_to_destroy", "hp", "defence"},
    "deputy_ledger": {"weight"},
    "terrain_costs": {
        "move_infantry", "move_armor", "move_riding", "move_flying",
        "move_infantry_wet", "move_armor_wet",
    },
}

# explicit foreign keys: (table, column) -> (ref_table, ref_column)
# chapters.map_id is kept as the enforced direction; maps.chapter_id is the
# same relationship stored redundantly in reverse (verified identical, not
# contradictory) and is left as a plain unenforced column rather than
# creating a mutual FK dependency neither table could be inserted first under.
FKS = {
    ("classes", "promotes_from"): ("classes", "class_id"),
    ("units", "base_class_id"): ("classes", "class_id"),
    ("units", "growth_profile_id"): ("growths", "profile_id"),
    ("units", "join_chapter_id"): ("chapters", "chapter_id"),
    ("chapters", "map_id"): ("maps", "map_id"),
    ("chapters", "sect_id"): ("sects", "sect_id"),
    ("scenes", "chapter_id"): ("chapters", "chapter_id"),
    ("regions", "claimed_by_sect_id"): ("sects", "sect_id"),
    ("regions", "named_id"): ("named", "named_id"),
    ("named", "region_id"): ("regions", "region_id"),
    ("states", "court_sect_id"): ("sects", "sect_id"),
    ("defections", "unit_id"): ("units", "unit_id"),
    ("locations", "region_id"): ("regions", "region_id"),
    ("polities", "region_id"): ("regions", "region_id"),
    ("settlements", "polity_id"): ("polities", "polity_id"),
    ("settlements", "region_id"): ("regions", "region_id"),
    ("flashbacks", "era_id"): ("eras", "era_id"),
    ("materials", "named_id"): ("named", "named_id"),
    ("materials", "forge_id"): ("forges", "forge_id"),
    ("practices", "sect_id"): ("sects", "sect_id"),
}


def read_rows(ws, prefix):
    headers = [c.value for c in ws[1]]
    rows = []
    for raw in ws.iter_rows(min_row=2, values_only=True):
        key = raw[0]
        if not isinstance(key, str):
            continue
        if prefix and not key.startswith(prefix):
            continue
        rows.append(raw[:len(headers)])
    return headers, rows


wb = load_workbook(SRC, data_only=True)
con = sqlite3.connect(OUT)
con.execute("PRAGMA foreign_keys = OFF")  # off while building, on to verify after
cur = con.cursor()

# ---- normalized enum lookup table (2 columns, not the xlsx's transposed shape)
ews = wb["enums"]
ehdrs = [c.value for c in ews[1]]
cur.execute("CREATE TABLE enums (category TEXT NOT NULL, value TEXT NOT NULL, "
            "PRIMARY KEY (category, value))")
seen = set()
for row in ews.iter_rows(min_row=2, values_only=True):
    for cat, val in zip(ehdrs, row):
        if val and (cat, val) not in seen:
            cur.execute("INSERT INTO enums VALUES (?, ?)", (cat, val))
            seen.add((cat, val))

built = ["enums"]
for name in wb.sheetnames:
    if name in EXCLUDE or name not in PK:
        continue
    id_col, prefix = PK[name]
    ws = wb[name]
    headers, rows = read_rows(ws, prefix)
    numeric = NUMERIC.get(name, set())

    cols_sql = []
    for h in headers:
        t = "INTEGER" if h in numeric else "TEXT"
        pk_sql = " PRIMARY KEY" if h == id_col else ""
        cols_sql.append(f'"{h}" {t}{pk_sql}')

    fk_sql = []
    for (tbl, col), (rtbl, rcol) in FKS.items():
        if tbl == name:
            fk_sql.append(f'FOREIGN KEY ("{col}") REFERENCES "{rtbl}"("{rcol}")')

    ddl = f'CREATE TABLE "{name}" ({", ".join(cols_sql + fk_sql)})'
    cur.execute(ddl)

    placeholders = ", ".join("?" * len(headers))
    cur.executemany(f'INSERT INTO "{name}" VALUES ({placeholders})', rows)
    built.append(name)

con.commit()

# ---- verify with SQLite's OWN foreign key engine, independent of canon_validate.py
cur.execute("PRAGMA foreign_keys = ON")
violations = cur.execute("PRAGMA foreign_key_check").fetchall()

con.commit()
con.close()
print(f"built {len(built)} tables: {built}")
print(f"foreign_key_check violations: {len(violations)}")
for v in violations:
    print("  ", v)
