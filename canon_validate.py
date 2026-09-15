"""
canon_validate.py

Purpose:  Referential and structural integrity check over fodlan_canon.xlsx.
          Covers the checks a spreadsheet formula cannot express: pipe-delimited
          foreign keys, chapter-ordering (a scene cannot name a unit who has not
          joined yet), matrix coverage, and objective-verb monotony.

Context:  The workbook is the source of truth. Prose is generated FROM it. This
          script is what makes "keep it coherent" a test rather than a hope.

Rules:    Read-only by construction. It never writes to the workbook. Its only
          output is a violations CSV, which is the reviewable artifact.
          Severity: blocking = the corpus contradicts itself and generation
          should stop; warning = probably wrong, human decides; info = a count
          worth eyeballing.

Usage:    python canon_validate.py fodlan_canon.xlsx [--out violations.csv]
Env:      none. Requires openpyxl.
Provenance: drafted 2026-08-03 for Nick Kogan. No approvals required, read-only.
"""

import argparse
import csv
import sys
from collections import Counter, defaultdict

from openpyxl import load_workbook

# Which column on which tab is the primary key, and what prefix its IDs must use.
PRIMARY_KEYS = {
    "sects": ("sect_id", "sect_"),
    "classes": ("class_id", "cls_"),
    "growths": ("profile_id", "gp_"),
    "units": ("unit_id", "u_"),
    "maps": ("map_id", "map_"),
    "chapters": ("chapter_id", "ch_"),
    "epithets": ("epithet_id", "ep_"),
    "npcs": ("npc_id", "npc_"),
    "canon_flags": ("flag_id", "flag_"),
    "scenes": ("scene_id", "sc_"),
    "regions": ("region_id", "rgn_"),
    "forges": ("forge_id", "frg_"),
    "materials": ("material_id", "mat_"),
    "christian_allegory": ("sect_id", "sect_"),  # reuses sects' id space by design
    "endings": ("ending_id", "end_"),
    "naming_reference": ("ref_id", "ref_"),
    "ascension_signals": ("signal_id", "sig_"),
    "named": ("named_id", "nmd_"),
    "polities": ("polity_id", "pol_"),
    "settlements": ("settlement_id", "set_"),
    "eras": ("era_id", "era_"),
    "flashbacks": ("flashback_id", "fb_"),
    "states": ("state_id", "st_"),
    "defections": ("defection_id", "def_"),
    "locations": ("location_id", "loc_"),
    "terrain_costs": ("terrain_id", "ter_"),
    "guest_units": ("guest_id", "gst_"),
}

# Art x movement cells that are gaps ON PURPOSE. Anything else missing is a bug.
DECLARED_GAPS = {
    ("brawl", "riding"): "permanent: no mounted brawling tradition",
    ("brawl", "flying"): "permanent: no aerial brawling tradition",
    ("reason", "flying"): "founded in-game: doctrinal ban broken by paralogue into Tzitzimitl",
}

MATRIX_ARTS = ["sword", "lance", "axe", "bow", "brawl", "reason", "faith"]
MATRIX_MOVES = ["infantry", "armor", "riding", "flying"]

MAX_CONSECUTIVE_SAME_VERB = 2


def read_tab(wb, name):
    """Return a tab as a list of dicts keyed by header.

    Note rows are prose parked in column A beneath the data. Gating on the tab's
    declared ID prefix means a note can never be read as a record, however the
    blank rows between them shift.
    """
    if name not in wb.sheetnames:
        return []
    ws = wb[name]
    headers = [c.value for c in ws[1]]
    prefix = PRIMARY_KEYS.get(name, (None, None))[1]
    rows = []
    for raw in ws.iter_rows(min_row=2, values_only=True):
        key = raw[0]
        if not isinstance(key, str):
            continue
        if prefix and not key.startswith(prefix):
            continue
        rows.append({h: raw[i] for i, h in enumerate(headers) if h})
    return rows


def split_multi(value):
    """Pipe-delimited text is the only multi-value form allowed anywhere."""
    if not value:
        return []
    return [v.strip() for v in str(value).split("|") if v.strip()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("workbook", nargs="?", default="fodlan_canon.xlsx")
    ap.add_argument("--out", default="violations.csv")
    args = ap.parse_args()

    wb = load_workbook(args.workbook, data_only=True)
    tabs = {name: read_tab(wb, name) for name in PRIMARY_KEYS}

    ids = {name: {r[PRIMARY_KEYS[name][0]] for r in rows} for name, rows in tabs.items()}
    v = []  # (check_id, severity, entity, detail)

    def fail(check, sev, entity, detail):
        v.append((check, sev, entity, detail))

    # --- c01 duplicate primary keys ------------------------------------------
    for tab, (key, _) in PRIMARY_KEYS.items():
        counts = Counter(r[key] for r in tabs[tab])
        for k, n in counts.items():
            if n > 1:
                fail("c01", "blocking", f"{tab}.{k}", f"primary key appears {n} times")

    # --- c02 ID prefix convention --------------------------------------------
    for tab, (key, prefix) in PRIMARY_KEYS.items():
        for r in tabs[tab]:
            if r[key] and not str(r[key]).startswith(prefix):
                fail("c02", "warning", f"{tab}.{r[key]}", f"expected prefix '{prefix}'")

    # --- c03 pipe-delimited foreign keys -------------------------------------
    multi_fks = [
        ("chapters", "recruits_unit_ids", "units"),
        ("scenes", "speaker_ids", "units+npcs"),
        ("scenes", "depends_on_units", "units"),
        ("scenes", "depends_on_flags", "canon_flags"),
    ]
    for tab, col, target in multi_fks:
        for r in tabs[tab]:
            valid = set()
            for t in target.split("+"):   # a speaker may be a unit or a troupe NPC
                valid |= ids[t]
            for ref in split_multi(r.get(col)):
                if ref not in valid:
                    fail("c03", "blocking", f"{tab}.{r[PRIMARY_KEYS[tab][0]]}",
                         f"{col} references unknown {target} id '{ref}'")

    # --- c04 chapter ordering: a unit cannot speak before they join ----------
    # Build a global sequence number per chapter so "before" is well defined.
    order = {}
    for r in tabs["chapters"]:
        act = str(r.get("act") or "")
        num = r.get("number") or 0
        act_rank = {"prologue": 0, "1": 1, "2": 2, "3": 3, "paralogue": 9}.get(act, 5)
        order[r["chapter_id"]] = (act_rank, num)

    join_at = {r["unit_id"]: order.get(r.get("join_chapter_id")) for r in tabs["units"]}
    for r in tabs["scenes"]:
        here = order.get(r.get("chapter_id"))
        if here is None:
            continue
        for u in split_multi(r.get("speaker_ids")):
            joined = join_at.get(u)
            if joined is None:
                continue  # unknown unit already caught by c03
            if joined > here:
                fail("c04", "blocking", f"scenes.{r['scene_id']}",
                     f"unit '{u}' speaks in {r['chapter_id']} but joins later")

    # --- c05 route coherence: a unit cannot appear on the wrong route --------
    unit_route = {r["unit_id"]: r.get("route") for r in tabs["units"]}
    chap_route = {r["chapter_id"]: r.get("route") for r in tabs["chapters"]}
    for r in tabs["chapters"]:
        for u in split_multi(r.get("recruits_unit_ids")):
            ur, cr = unit_route.get(u), r.get("route")
            if ur and cr and "both" not in (ur, cr) and ur != cr:
                fail("c05", "blocking", f"chapters.{r['chapter_id']}",
                     f"recruits {u} ({ur}) on a {cr} chapter")

    # --- c06 every chapter has a map and every map has a chapter -------------
    mapped = {r.get("map_id") for r in tabs["chapters"] if r.get("map_id")}
    for r in tabs["chapters"]:
        if not r.get("map_id"):
            fail("c06", "warning", f"chapters.{r['chapter_id']}", "no map assigned")
    for r in tabs["maps"]:
        if r["map_id"] not in mapped:
            fail("c06", "warning", f"maps.{r['map_id']}", "map exists but no chapter uses it")

    # --- c07 class matrix coverage vs declared gaps --------------------------
    have = {(r.get("art_primary"), r.get("movement"))
            for r in tabs["classes"] if r.get("tier") == "order"}
    for art in MATRIX_ARTS:
        for mv in MATRIX_MOVES:
            if (art, mv) in have:
                continue
            if (art, mv) in DECLARED_GAPS:
                fail("c07", "info", f"matrix.{art}+{mv}", f"declared gap: {DECLARED_GAPS[(art, mv)]}")
            else:
                fail("c07", "blocking", f"matrix.{art}+{mv}", "matrix cell empty and not a declared gap")

    # --- c08 promotion reachability ------------------------------------------
    class_ids = ids["classes"]
    promotes_into = defaultdict(list)
    for r in tabs["classes"]:
        if r.get("promotes_from"):
            promotes_into[r["promotes_from"]].append(r["class_id"])
    for r in tabs["units"]:
        base = r.get("base_class_id")
        if base and base in class_ids and not promotes_into.get(base):
            tier = next((c.get("tier") for c in tabs["classes"] if c["class_id"] == base), "")
            if tier not in ("personal", "paragon", "order", "hybrid"):
                fail("c08", "warning", f"units.{r['unit_id']}",
                     f"base class '{base}' has no promotion target")

    # --- c09 objective-verb monotony -----------------------------------------
    by_route = defaultdict(list)
    for r in tabs["chapters"]:
        by_route[(r.get("route"), r.get("column"))].append(r)
    verb_of = {r["map_id"]: r.get("objective_verb") for r in tabs["maps"]}
    for key, chs in by_route.items():
        chs = sorted(chs, key=lambda r: order.get(r["chapter_id"], (9, 99)))
        run, prev = 0, None
        for r in chs:
            verb = verb_of.get(r.get("map_id"))
            run = run + 1 if verb == prev else 1
            prev = verb
            if run > MAX_CONSECUTIVE_SAME_VERB:
                fail("c09", "warning", f"chapters.{r['chapter_id']}",
                     f"{run} consecutive '{verb}' chapters on route/column {key}")

    # --- c10 sect chapter counts match the declared plan ---------------------
    actual = Counter(r.get("sect_id") for r in tabs["chapters"] if r.get("sect_id"))
    for r in tabs["sects"]:
        declared = r.get("act2_chapter_count") or 0
        got = actual.get(r["sect_id"], 0)
        if got < declared:
            fail("c10", "info", f"sects.{r['sect_id']}",
                 f"declares {declared} Act 2 chapters, {got} written")

    # --- c11 world troupe rule: at least one appearance per act --------------
    for r in tabs["npcs"]:
        if r.get("role") != "world troupe":
            continue
        missing = [a for a in ("act1", "act2", "act3") if str(r.get(a)).lower() != "yes"]
        if missing:
            fail("c11", "warning", f"npcs.{r['npc_id']}",
                 f"troupe rule requires an appearance in every act; missing {', '.join(missing)}")

    # --- c13 defection class-niche coverage: a scripted/conditional
    #     departure should not zero out a class niche with no other
    #     non-defecting unit in it and no guest_units entry covering it ------
    class_niche = {r["class_id"]: (r.get("art_primary"), r.get("movement"))
                   for r in tabs["classes"]}
    unit_niche = {r["unit_id"]: class_niche.get(r.get("base_class_id"))
                  for r in tabs["units"]}
    defecting_units = {r["unit_id"] for r in tabs["defections"]}
    guest_niches = {class_niche.get(r.get("base_class_id")) for r in tabs["guest_units"]}
    for r in tabs["defections"]:
        uid = r["unit_id"]
        niche = unit_niche.get(uid)
        if niche is None:
            continue
        has_redundancy = any(
            other_id != uid and other_id not in defecting_units and unit_niche.get(other_id) == niche
            for other_id in unit_niche
        )
        if has_redundancy or niche in guest_niches:
            continue
        fail("c13", "warning", f"defections.{r['defection_id']}",
             "unit is the roster's only unit in its class niche and no "
             "guest_units entry covers it if this defection fires")

    # --- c13d christian_allegory sect_id must resolve, and every sect should
    #     have exactly one allegory entry ------------------------------------
    ally_sects = set()
    for r in tabs["christian_allegory"]:
        sid = r.get("sect_id")
        if sid and sid not in ids["sects"]:
            fail("c13", "blocking", f"christian_allegory.{sid}",
                 f"sect_id '{sid}' does not exist")
        elif sid:
            ally_sects.add(sid)
    for sid in ids["sects"]:
        if sid not in ally_sects:
            fail("c13", "warning", f"sects.{sid}", "no christian_allegory entry")

    # --- c13a forge locations must resolve against settlements OR polities ---
    for r in tabs["forges"]:
        loc = r.get("location")
        if not loc:
            continue
        if loc not in ids.get("settlements", set()) and loc not in ids.get("polities", set()):
            fail("c13", "blocking", f"forges.{r['forge_id']}",
                 f"location '{loc}' is not a known settlement or polity")

    # --- c13b materials must point at real Named and real forges -------------
    for r in tabs["materials"]:
        if r.get("named_id") and r["named_id"] not in ids["named"]:
            fail("c13", "blocking", f"materials.{r['material_id']}",
                 f"named_id '{r['named_id']}' does not exist")
        fid = r.get("forge_id")
        if fid and fid not in ids["forges"]:
            fail("c13", "blocking", f"materials.{r['material_id']}",
                 f"forge_id '{fid}' does not exist")

    # --- c13c the hard cap is stated correctly against actual drop count -----
    usable = [r for r in tabs["materials"] if r.get("forge_id")]
    if len(usable) < 3:
        fail("c13", "info", "materials", "fewer than 3 usable drops -- the 3-of-5 cap is moot")

    # --- c13 region / Named cross-references ---------------------------------
    for r in tabs["named"]:
        if r.get("region_id") and r["region_id"] not in ids["regions"]:
            fail("c13", "blocking", f"named.{r['named_id']}",
                 f"region_id '{r['region_id']}' does not exist")
    for r in tabs["regions"]:
        if r.get("named_id") and r["named_id"] not in ids["named"]:
            fail("c13", "blocking", f"regions.{r['region_id']}",
                 f"named_id '{r['named_id']}' does not exist")
        if r.get("claimed_by_sect_id") and r["claimed_by_sect_id"] not in ids["sects"]:
            fail("c13", "blocking", f"regions.{r['region_id']}",
                 f"claimed_by_sect_id '{r['claimed_by_sect_id']}' does not exist")

    # --- c13e endings tab sanity checks --------------------------------------
    if len(tabs.get("endings", [])) < 3:
        fail("c13", "warning", "endings", "fewer than 3 terminal states defined")
    for r in tabs.get("endings", []):
        if not r.get("resolution_and_aftermath"):
            fail("c13", "blocking", f"endings.{r['ending_id']}", "no resolution/aftermath text")

    # --- c14 the two-explanations discipline ---------------------------------
    # Every scar must support at least two incompatible readings. A scar with
    # only one explanation is a scar the game has quietly confirmed.
    for r in tabs["regions"]:
        scar = (r.get("scar") or "").strip().lower()
        if not scar or scar.startswith("none"):
            continue
        if not (r.get("explanation_sacred") and r.get("explanation_material")):
            fail("c14", "warning", f"regions.{r['region_id']}",
                 "scar has fewer than two competing explanations")

    # --- c15 pacing: calm is scheduled, not optional -------------------------
    CALM = {"warm", "wondrous"}
    HEAVY = {"grim", "desolate"}
    for key, chs in by_route.items():
        chs = sorted(chs, key=lambda r: order.get(r["chapter_id"], (9, 99)))
        run = 0
        since_calm = 0
        for r in chs:
            tone = (r.get("tonal_register") or "").strip()
            if not tone:
                fail("c15", "warning", f"chapters.{r['chapter_id']}", "no tonal_register assigned")
                continue
            run = run + 1 if tone in HEAVY else 0
            if run > 2:
                fail("c15", "warning", f"chapters.{r['chapter_id']}",
                     f"{run} consecutive heavy chapters on route/column {key}")
            since_calm = 0 if tone in CALM else since_calm + 1
            if since_calm > 4:
                fail("c15", "warning", f"chapters.{r['chapter_id']}",
                     f"{since_calm} chapters since the last warm or wondrous one")

    # --- c16 one new system per chapter, and never before its teaching -------
    taught = {}
    for r in sorted(tabs["chapters"], key=lambda x: order.get(x["chapter_id"], (9, 99))):
        sysname = (r.get("teaches_system") or "").strip()
        if not sysname:
            continue
        if sysname in taught:
            fail("c16", "info", f"chapters.{r['chapter_id']}",
                 f"'{sysname}' was already taught in {taught[sysname]}")
        else:
            taught[sysname] = r["chapter_id"]

    # --- c12 roster size ------------------------------------------------------
    recruitable = sum(1 for r in tabs["units"] if r.get("status") == "recruitable")
    if recruitable < 24:
        fail("c12", "info", "units", f"{recruitable} recruitables; target is 24-28")

    # --- report ---------------------------------------------------------------
    with open(args.out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["check_id", "severity", "entity", "detail"])
        w.writerows(sorted(v, key=lambda x: (x[1] != "blocking", x[0], x[2])))

    counts = Counter(x[1] for x in v)
    print(f"{len(v)} findings -> {args.out}")
    for sev in ("blocking", "warning", "info"):
        print(f"  {sev:9} {counts.get(sev, 0)}")
    for x in sorted(v):
        if x[1] == "blocking":
            print(f"  BLOCKING {x[0]} {x[2]}: {x[3]}")

    return 1 if counts.get("blocking") else 0


if __name__ == "__main__":
    sys.exit(main())
