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
import re
import sys
from collections import Counter, defaultdict

from openpyxl import load_workbook

# Which column on which tab is the primary key, and what prefix its IDs must use.
WORLD_W, WORLD_H = 1152, 540   # the overworld canvas locations.map_x / map_y live on
PATH_ROUTES = {"diadem", "assembly", "both"}
PATH_KINDS = {"road", "trail"}
MAP_ACTIONS = {"capture", "shove", "smite", "bribe"}   # actions a class adds on the battle map (classes.map_actions)

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
    "unit_base_stats": ("unit_id", "u_"),  # reuses units' id space by design, same pattern as christian_allegory/sects
    "weapons": ("weapon_id", "wpn_"),
    "enemy_archetypes": ("enemy_id", "ea_"),
    "prologue_roster": ("punit_id", "pu_"),
    "encounter_spawns": ("spawn_id", "spn_"),
    "supports": ("chain_id", "sup_"),
    "promotion_rules": ("param_id", "prm_"),
    "abilities": ("ability_id", "ab_"),
    "world_paths": ("path_id", "path_"),
    "cargo_units": ("cargo_id", "cargo_"),
    "epilogue_text": ("phrase_id", "epi_"),
}

# Art x movement cells that are gaps ON PURPOSE. Anything else missing is a bug.
DECLARED_GAPS = {
    ("brawl", "riding"): "permanent: no mounted brawling tradition",
    ("brawl", "flying"): "permanent: no aerial brawling tradition",
    ("reason", "flying"): "founded in-game: doctrinal ban broken by paralogue into Tzitzimitl",
}

MATRIX_ARTS = ["sword", "lance", "axe", "bow", "brawl", "reason", "faith"]
MATRIX_MOVES = ["infantry", "armor", "riding", "flying"]
WEAPON_TIERS = ["worn", "basic", "mid", "high", "legendary"]
WEAPON_EFFECTS = {"heal_allies", "unmake", "pull"}
SPECIALTY_ARTS = {"edged": {"sword"}, "hafted": {"lance", "axe"}, "missile": {"bow"}}

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

    # --- c07b weapons.art must be a real art ---------------------------------
    for r in tabs["weapons"]:
        if r.get("art") not in MATRIX_ARTS:
            fail("c07", "blocking", f"weapons.{r['weapon_id']}",
                 f"art '{r.get('art')}' is not one of {MATRIX_ARTS}")

    # --- c07c enemy_archetypes.weapon_art must be real, first_seen_map_id
    #     must resolve --------------------------------------------------------
    for r in tabs["enemy_archetypes"]:
        if r.get("weapon_art") not in MATRIX_ARTS:
            fail("c07", "blocking", f"enemy_archetypes.{r['enemy_id']}",
                 f"weapon_art '{r.get('weapon_art')}' is not one of {MATRIX_ARTS}")
        map_id = r.get("first_seen_map_id")
        if map_id and map_id not in ids["maps"]:
            fail("c07", "blocking", f"enemy_archetypes.{r['enemy_id']}",
                 f"first_seen_map_id '{map_id}' does not exist")

    # --- c07g overlap weapons: req_arts / effective_vs / enemy weapon_id -----
    weapon_by_id = {w["weapon_id"]: w for w in tabs["weapons"]}
    def _pipe(v):
        return [x.strip() for x in str(v).split("|")] if v not in (None, "") else []
    for r in tabs["weapons"]:
        req = _pipe(r.get("req_arts"))
        for art in req:
            if art not in MATRIX_ARTS:
                fail("c07", "blocking", f"weapons.{r['weapon_id']}",
                     f"req_arts entry '{art}' is not one of {MATRIX_ARTS}")
        if req and r.get("art") not in req:
            fail("c07", "blocking", f"weapons.{r['weapon_id']}",
                 f"art '{r.get('art')}' must be one of its own req_arts {req} (it decides physical vs magic damage)")
        if len(req) == 1:
            fail("c07", "warning", f"weapons.{r['weapon_id']}",
                 "req_arts lists a single art -- leave it blank for a one-art weapon")
        for mv in _pipe(r.get("effective_vs")):
            if mv not in MATRIX_MOVES:
                fail("c07", "blocking", f"weapons.{r['weapon_id']}",
                     f"effective_vs entry '{mv}' is not one of {MATRIX_MOVES}")
    for r in tabs["enemy_archetypes"]:
        wid = r.get("weapon_id")
        if wid in (None, ""):
            continue
        w = weapon_by_id.get(wid)
        if w is None:
            fail("c07", "blocking", f"enemy_archetypes.{r['enemy_id']}", f"weapon_id '{wid}' does not exist")
        elif r.get("weapon_art") not in (_pipe(w.get("req_arts")) or [w.get("art")]):
            fail("c07", "blocking", f"enemy_archetypes.{r['enemy_id']}",
                 f"weapon_art '{r.get('weapon_art')}' is not one of {wid}'s arts {_pipe(w.get('req_arts')) or [w.get('art')]}")

    # --- c07h equipment: convoy_qty is a non-negative integer, drop_weapon_id resolves
    for r in tabs["weapons"]:
        q = r.get("convoy_qty")
        if q is not None and (not isinstance(q, (int, float)) or q < 0 or int(q) != q):
            fail("c07", "blocking", f"weapons.{r['weapon_id']}", f"convoy_qty '{q}' must be a non-negative integer")
    for r in tabs["encounter_spawns"]:
        d = r.get("drop_weapon_id")
        if d not in (None, "") and d not in weapon_by_id:
            fail("c07", "blocking", f"encounter_spawns.{r['spawn_id']}", f"drop_weapon_id '{d}' does not exist")

    # --- c07i progression: required parameters, ability tags and conditions, class unlocks
    REQUIRED_PARAMS = ["promote_min_level", "fee_base", "fee_per_level", "recert_fraction", "growth_bonus",
        "slots_base", "slots_every", "slots_promotion", "exp_per_level", "exp_base", "exp_per_diff", "exp_min", "exp_max",
        "kill_base", "kill_per_diff", "kill_max", "catchup_gap", "underdog_per_level", "underdog_cap",
        "income_base", "income_per_kill", "income_factor_bonus",
        "paragon_min_level", "paragon_deeds_required", "paragon_fee_base", "paragon_fee_per_level", "paragon_growth_bonus", "paragon_slots",
        "solo_hold_phases", "solo_hold_radius", "weapon_marks_max", "reforge_fee"]
    STATS = ["hp", "str", "mag", "dex", "spd", "lck", "def", "res"]
    param_ids = {r["param_id"] for r in tabs["promotion_rules"]}
    for need in REQUIRED_PARAMS + [f"jump_{s}" for s in STATS] + [f"paragon_jump_{s}" for s in STATS] + [f"shape_{m}" for m in MATRIX_MOVES]:
        if f"prm_{need}" not in param_ids:
            fail("c07", "blocking", "promotion_rules", f"required parameter prm_{need} is missing")
    for r in tabs["promotion_rules"]:
        pid = r["param_id"]
        if pid.startswith("prm_shape_"):
            for part in split_multi(r.get("text")):
                stat, _, amount = part.partition(":")
                if stat not in STATS or not amount.lstrip("-").isdigit():
                    fail("c07", "blocking", f"promotion_rules.{pid}", f"shape entry '{part}' must be <stat>:<integer>")
        elif not isinstance(r.get("value"), (int, float)):
            fail("c07", "blocking", f"promotion_rules.{pid}", "value must be a number")
    class_by_id = {c["class_id"]: c for c in tabs["classes"]}
    CONDS = ["always", "hp_full", "hp_low"] + [f"vs_{m}" for m in MATRIX_MOVES] + [f"art:{a}" for a in MATRIX_ARTS]
    for r in tabs["abilities"]:
        aid = r["ability_id"]
        if r.get("cond") not in CONDS:
            fail("c07", "blocking", f"abilities.{aid}", f"cond '{r.get('cond')}' is not one of {CONDS}")
        for tag in split_multi(r.get("pool")):
            kind, _, val = tag.partition(":")
            ok = (tag == "any" or (kind == "art" and val in MATRIX_ARTS) or (kind == "move" and val in MATRIX_MOVES)
                  or (kind == "tier" and val in ("commoner", "trained", "order", "hybrid", "paragon", "shadow", "personal"))
                  or (kind == "class" and val in class_by_id))
            if not ok:
                fail("c07", "blocking", f"abilities.{aid}", f"pool tag '{tag}' does not resolve")
        for col in ("hit", "avoid", "crit", "dodge", "dmg", "guard", "speed", "exp_pct"):
            if not isinstance(r.get(col), (int, float)):
                fail("c07", "blocking", f"abilities.{aid}", f"{col} must be a number")
    for r in tabs["epithets"]:
        if r.get("tracked") not in ("yes", "no"):
            fail("c07", "blocking", f"epithets.{r['epithet_id']}", f"tracked '{r.get('tracked')}' must be yes or no")
        cn = r.get("count_needed")
        if not isinstance(cn, int) or cn < 1:
            fail("c07", "blocking", f"epithets.{r['epithet_id']}", f"count_needed '{cn}' must be a whole number of at least 1")
    for c in tabs["classes"]:
        for act in split_multi(c.get("map_actions")):
            if act not in MAP_ACTIONS:
                fail("c07", "blocking", f"classes.{c['class_id']}", f"map_actions '{act}' is not one of {sorted(MAP_ACTIONS)}")
    for c in tabs["classes"]:
        um = c.get("unlock_map_id")
        if um in (None, ""):
            continue
        if um not in ids["maps"]:
            fail("c07", "blocking", f"classes.{c['class_id']}", f"unlock_map_id '{um}' does not exist")
        if c.get("tier") not in ("hybrid", "paragon"):
            fail("c07", "warning", f"classes.{c['class_id']}", "unlock_map_id only applies to hybrid- and paragon-tier classes")

    # --- c07j the overworld: every location is on the canvas, paths join real
    #     locations, the path graph is connected (the flashback excepted), every
    #     chapter has a place, and the unlock chain has no cycle and reaches everything
    loc_ids = {l["location_id"] for l in tabs["locations"]}
    for l in tabs["locations"]:
        x, y = l.get("map_x"), l.get("map_y")
        if not isinstance(x, (int, float)) or not isinstance(y, (int, float)):
            fail("c07", "blocking", f"locations.{l['location_id']}", "map_x / map_y must be numbers")
        elif not (0 <= x <= WORLD_W and 0 <= y <= WORLD_H):
            fail("c07", "blocking", f"locations.{l['location_id']}", f"({x}, {y}) is off the {WORLD_W}x{WORLD_H} overworld canvas")
    adj = defaultdict(set)
    for e in tabs["world_paths"]:
        pid = e["path_id"]
        if e.get("route") not in PATH_ROUTES:
            fail("c07", "blocking", f"world_paths.{pid}", f"route '{e.get('route')}' is not one of {sorted(PATH_ROUTES)}")
        if e.get("kind") not in PATH_KINDS:
            fail("c07", "blocking", f"world_paths.{pid}", f"kind '{e.get('kind')}' is not one of {sorted(PATH_KINDS)}")
        if e["from_location_id"] == e["to_location_id"]:
            fail("c07", "blocking", f"world_paths.{pid}", "a path cannot join a location to itself")
        for pt in (e.get("waypoints") or "").split(";"):
            if pt.strip() and not re.fullmatch(r"\s*\d+\s*,\s*\d+\s*", pt):
                fail("c07", "blocking", f"world_paths.{pid}", f"waypoint '{pt}' is not 'x,y'")
        adj[e["from_location_id"]].add(e["to_location_id"])
        adj[e["to_location_id"]].add(e["from_location_id"])
    if adj:
        start = next(iter(adj))
        reached, todo = {start}, [start]
        while todo:
            for n in adj[todo.pop()]:
                if n not in reached:
                    reached.add(n)
                    todo.append(n)
        for lid in sorted(set(adj) - reached):
            fail("c07", "blocking", f"locations.{lid}", "is not connected to the rest of the overworld by any chain of paths")
    chapter_loc = {c["chapter_id"]: c.get("location_id") for c in tabs["chapters"]}
    used = set()
    for c in tabs["chapters"]:
        lid = c.get("location_id")
        if lid not in loc_ids:
            fail("c07", "blocking", f"chapters.{c['chapter_id']}", f"location_id '{lid}' does not exist")
        used.add(lid)
        if lid not in adj and c.get("act") != "prologue":
            fail("c07", "blocking", f"chapters.{c['chapter_id']}", f"is placed at {lid}, which no path reaches (only the prologue flashback may stand alone)")
    for lid in sorted(loc_ids - used):
        fail("c07", "warning", f"locations.{lid}", "no chapter is placed here")
    after = {c["chapter_id"]: split_multi(c.get("unlock_after")) for c in tabs["chapters"]}
    for cid, reqs in after.items():
        for r in reqs:
            if r not in after:
                fail("c07", "blocking", f"chapters.{cid}", f"unlock_after '{r}' is not a chapter")
    open_set = {cid for cid, reqs in after.items() if not reqs}
    grew = True
    while grew:
        grew = False
        for cid, reqs in after.items():
            if cid not in open_set and any(r in open_set for r in reqs):
                open_set.add(cid)
                grew = True
    for cid in sorted(set(after) - open_set):
        fail("c07", "blocking", f"chapters.{cid}", "can never be unlocked (its unlock_after chain has a cycle or never starts)")

    # --- c07k deeds on terrain and cargo: a terrain deed names a real terrain,
    #     cargo sits on an escort map inside its grid, and a map never asks for
    #     more deliveries than it has cargo
    terr_ids = {t["terrain_id"] for t in tabs["terrain_costs"]}
    for ep in tabs["epithets"]:
        dterr = ep.get("deed_terrain")
        if dterr not in (None, "") and dterr not in terr_ids:
            fail("c07", "blocking", f"epithets.{ep['epithet_id']}", f"deed_terrain '{dterr}' is not a terrain_costs row")
    maps_by_id = {m["map_id"]: m for m in tabs["maps"]}
    cargo_by_map = Counter()
    for cu in tabs["cargo_units"]:
        m = maps_by_id.get(cu["map_id"])
        cid = cu["cargo_id"]
        cargo_by_map[cu["map_id"]] += 1
        if m is None:
            continue
        if m.get("objective_verb") not in ("escort", "escape"):
            fail("c07", "blocking", f"cargo_units.{cid}", f"is on {cu['map_id']}, which is a '{m.get('objective_verb')}' map, not an escort")
        r, c = cu.get("spawn_row"), cu.get("spawn_col")
        if not (isinstance(r, int) and isinstance(c, int) and 0 <= r < m["height"] and 0 <= c < m["width"]):
            fail("c07", "blocking", f"cargo_units.{cid}", f"spawn ({r}, {c}) is outside {cu['map_id']}'s {m['width']}x{m['height']} grid")
        if cu.get("movement") not in ("infantry", "armor", "riding", "flying"):
            fail("c07", "blocking", f"cargo_units.{cid}", f"movement '{cu.get('movement')}' is not a movement type")
    for mid, m in maps_by_id.items():
        need = m.get("cargo_needed")
        if need in (None, "", 0):
            continue
        if not isinstance(need, int) or need < 1 or need > cargo_by_map.get(mid, 0):
            fail("c07", "blocking", f"maps.{mid}", f"cargo_needed {need} but the map has {cargo_by_map.get(mid, 0)} cargo units")

    # --- c07l enemy behaviours: a flee threshold is a sane percent; a talkable enemy has a
    #     number for how receptive it is and something to say
    for ea in tabs["enemy_archetypes"]:
        eid = ea["enemy_id"]
        fp = ea.get("flees_below_pct")
        if fp not in (None, "") and not (isinstance(fp, int) and 1 <= fp <= 99):
            fail("c07", "blocking", f"enemy_archetypes.{eid}", f"flees_below_pct '{fp}' must be a whole percent from 1 to 99")
        tm = ea.get("talk_mod")
        if tm not in (None, "") and not isinstance(tm, int):
            fail("c07", "blocking", f"enemy_archetypes.{eid}", f"talk_mod '{tm}' must be a whole number")
        if tm not in (None, "") and not ea.get("talk_line"):
            fail("c07", "warning", f"enemy_archetypes.{eid}", "is talkable but has no talk_line")
        if tm in (None, "") and ea.get("talk_line"):
            fail("c07", "warning", f"enemy_archetypes.{eid}", "has a talk_line but no talk_mod, so it can never be talked down")

    # --- c07m the forge system: weapon effects are known; a master forge has a place and a
    #     readable access rule; a material's weapon is legendary, forged by the right smith
    #     from the right specialty, and its source enemy exists
    for w in tabs["weapons"]:
        eff = w.get("effect")
        if eff not in (None, "") and eff not in WEAPON_EFFECTS:
            fail("c07", "blocking", f"weapons.{w['weapon_id']}", f"effect '{eff}' is not one of {sorted(WEAPON_EFFECTS)}")
    forges_by_id = {f["forge_id"]: f for f in tabs["forges"]}
    maps_known = {m["map_id"] for m in tabs["maps"]}
    loc_known = {l["location_id"] for l in tabs["locations"]}
    for f in tabs["forges"]:
        if f.get("tier") != "master":
            continue
        fid = f["forge_id"]
        if f.get("location_id") not in loc_known:
            fail("c07", "blocking", f"forges.{fid}", f"location_id '{f.get('location_id')}' is not a location")
        rule = str(f.get("access_rule") or "")
        if rule != "always" and not (rule.startswith("won:") and all(m in maps_known for m in rule[4:].split("|"))):
            fail("c07", "blocking", f"forges.{fid}", f"access_rule '{rule}' must be 'always' or 'won:<map_id>[|<map_id>]' with real maps")
        if not isinstance(f.get("cycle_n"), int) or f["cycle_n"] < 1:
            fail("c07", "blocking", f"forges.{fid}", "cycle_n must be a whole number of chapters")
    weapons_by_id = {w["weapon_id"]: w for w in tabs["weapons"]}
    enemies_known = {e["enemy_id"] for e in tabs["enemy_archetypes"]}
    for mt in tabs["materials"]:
        mid = mt["material_id"]
        wid, eid = mt.get("weapon_id"), mt.get("enemy_id")
        if wid in (None, "") and eid in (None, ""):
            continue                      # the Huma: no material, on purpose
        if eid not in enemies_known:
            fail("c07", "blocking", f"materials.{mid}", f"enemy_id '{eid}' is not an enemy archetype")
        w = weapons_by_id.get(wid)
        if w is None:
            fail("c07", "blocking", f"materials.{mid}", f"weapon_id '{wid}' is not a weapon")
            continue
        if w.get("tier") != "legendary":
            fail("c07", "blocking", f"materials.{mid}", f"{wid} is tier '{w.get('tier')}', a master work must be legendary")
        if w.get("art") not in SPECIALTY_ARTS.get(mt.get("specialty_required"), set()):
            fail("c07", "blocking", f"materials.{mid}", f"{wid} is a {w.get('art')} weapon, which the '{mt.get('specialty_required')}' specialty doesn't make")
        fg = forges_by_id.get(mt.get("forge_id"))
        if fg is None or fg.get("specialty") != mt.get("specialty_required"):
            fail("c07", "blocking", f"materials.{mid}", f"forge '{mt.get('forge_id')}' doesn't work the '{mt.get('specialty_required')}' specialty")
    for w in tabs["weapons"]:
        if w.get("tier") == "legendary" and not any(m.get("weapon_id") == w["weapon_id"] for m in tabs["materials"]):
            fail("c07", "warning", f"weapons.{w['weapon_id']}", "is legendary but no material forges it")

    # --- c07n defections: a trigger and an appearance map; a recoverable defector has a way back
    #     and a scripted one doesn't; a guest requires real defections and a real departure map
    unit_known = {u["unit_id"] for u in tabs["units"]}
    defection_ids = set()
    for d in tabs["defections"]:
        did = d["defection_id"]
        if not str(did).startswith("def_"):
            continue
        defection_ids.add(did)
        if d.get("unit_id") not in unit_known:
            fail("c07", "blocking", f"defections.{did}", f"unit '{d.get('unit_id')}' is not a unit")
        for col in ("trigger_map_id", "appears_map_id"):
            if d.get(col) not in maps_known:
                fail("c07", "blocking", f"defections.{did}", f"{col} '{d.get(col)}' is not a map")
        recoverable = d.get("recruitable_back") == "yes"
        if recoverable and d.get("return_map_id") in (None, ""):
            fail("c07", "blocking", f"defections.{did}", "is recruitable back but names no return_map_id")
        if not recoverable and d.get("return_map_id") not in (None, ""):
            fail("c07", "blocking", f"defections.{did}", "has a return_map_id but is not recruitable back")
        if d.get("kind") == "scripted" and d.get("trigger_unless_map_id") not in (None, ""):
            fail("c07", "blocking", f"defections.{did}", "a scripted defection cannot be avoided (trigger_unless_map_id)")
    for g in tabs["guest_units"]:
        if not str(g.get("guest_id", "")).startswith("gst_"):
            continue
        for need in split_multi(g.get("requires_defections")):
            if need not in defection_ids:
                fail("c07", "blocking", f"guest_units.{g['guest_id']}", f"requires_defections '{need}' is not a defection")
        if g.get("depart_map_id") not in maps_known:
            fail("c07", "blocking", f"guest_units.{g['guest_id']}", f"depart_map_id '{g.get('depart_map_id')}' is not a map")

    # --- c07o the deputy ledger: every scoring factor the code uses is present, once, with a weight;
    #     a support that reveals literacy names a real rank
    needed_factors = {"writ_deed", "paralogue_deed", "on_objective", "witnessed", "unwitnessed_kill", "legible", "raw_kill", "literacy"}
    seen_factors = Counter()
    for dl in read_tab(wb, "deputy_ledger"):
        fid = dl.get("factor_id")
        if fid in (None, ""):
            continue
        seen_factors[fid] += 1
        if not isinstance(dl.get("weight"), (int, float)):
            fail("c07", "blocking", f"deputy_ledger.{fid}", "weight must be a number")
    for fid in sorted(needed_factors - set(seen_factors)):
        fail("c07", "blocking", "deputy_ledger", f"factor '{fid}' is missing")
    for fid, n in seen_factors.items():
        if n > 1:
            fail("c07", "blocking", f"deputy_ledger.{fid}", "appears more than once")
    for sp in tabs["supports"]:
        rv = sp.get("reveals")
        if rv not in (None, ""):
            if rv != "literacy":
                fail("c07", "blocking", f"supports.{sp['chain_id']}", f"reveals '{rv}' is not 'literacy'")
            if sp.get("reveals_about") not in (sp.get("unit_a_id"), sp.get("unit_b_id")):
                fail("c07", "blocking", f"supports.{sp['chain_id']}", "reveals_about must be one of the chain's two units")
            if sp.get("reveals_at_rank") not in ("C", "B", "A", "S"):
                fail("c07", "blocking", f"supports.{sp['chain_id']}", "reveals_at_rank must be C, B, A or S")

    # --- c07p the epilogue generator: every phrase it reaches for exists with the placeholders it fills;
    #     every enemy says whose it is and what its blow is called; a Named has a signature verb
    phrases = {r["phrase_id"]: str(r.get("text") or "") for r in tabs["epilogue_text"]}
    need_ph = {
        "epi_head": ["{NAME}", "{TITLE}", "{PLACE}"], "epi_head_plain": ["{NAME}", "{PLACE}"],
        "epi_tail_known": ["{KILLER}"], "epi_tail_unknown": [], "epi_tail_hazard": ["{HAZARD}"],
        "epi_hazard_cold": [], "epi_killer_polity": ["{ADJ}", "{NOUN}"], "epi_killer_band": ["{WHO}", "{NOUN}"],
        "epi_killer_named": ["{PHRASE}"], "epi_killer_defector": ["{DEFECTOR}"], "epi_killer_boss": ["{BOSS}"],
        "epi_title_slayer_of": ["{TOKEN}", "{OBJECT}"], "epi_title_slayer_fallback": [], "epi_title_the": ["{TOKEN}"],
        "epi_support_gone": ["{PARTNER}"], "epi_support_fallen_before": ["{PARTNER}"], "epi_support_fallen_after": ["{PARTNER}"],
        "epi_support_alone": [], "epi_roll_title": [], "epi_roll_empty": [],
    }
    for fate in ("lost_to_enemy", "retrieved", "thrown_and_lost", "with_the_body"):
        need_ph[f"epi_weapon_{fate}"] = ["{WEAPON}"]
    for kind in ("platonic", "romantic"):
        for tier in ("C", "B", "A") + (("S",) if kind == "romantic" else ()):
            need_ph[f"epi_support_{kind}_{tier}"] = ["{PARTNER}"]
    for pid, holes in need_ph.items():
        if pid not in phrases:
            fail("c07", "blocking", "epilogue_text", f"phrase '{pid}' is missing")
            continue
        for ph in holes:
            if ph not in phrases[pid]:
                fail("c07", "blocking", f"epilogue_text.{pid}", f"text lacks the placeholder {ph}")
    for pid, text in phrases.items():
        low = f" {text.lower()} "
        if any(w in low for w in (" he ", " she ", " his ", " her ", " him ", " hers ")):
            fail("c07", "warning", f"epilogue_text.{pid}", "uses a gendered pronoun for someone whose pronouns the game does not know")
    for ea in tabs["enemy_archetypes"]:
        if ea.get("affiliation") not in ("state", "band", "individual", "named"):
            fail("c07", "blocking", f"enemy_archetypes.{ea['enemy_id']}", "affiliation must be state, band, individual or named")
        if ea.get("affiliation") in ("state", "band") and not ea.get("death_noun"):
            fail("c07", "blocking", f"enemy_archetypes.{ea['enemy_id']}", "a state or band enemy needs a death_noun")
        if (ea.get("affiliation") == "named") != (ea.get("named_id") not in (None, "")):
            fail("c07", "blocking", f"enemy_archetypes.{ea['enemy_id']}", "affiliation 'named' must match having a named_id")
    for nm in tabs["named"]:
        if not nm.get("death_phrase"):
            fail("c07", "blocking", f"named.{nm['named_id']}", "a Named needs a death_phrase for the epilogue")
    for pl in tabs["polities"]:
        if not pl.get("epilogue_adjective"):
            fail("c07", "blocking", f"polities.{pl['polity_id']}", "a polity needs an epilogue_adjective")

    # --- c07q weapon names: every deed has a form for a weapon it marks, naming its base and carrying its
    #     vocabulary token; a form that wants an object has a bare fallback
    for ep in tabs["epithets"]:
        eid = ep["epithet_id"]
        form = str(ep.get("weapon_form") or "")
        token = str(ep.get("forge_vocab_token") or "").strip()
        if "{BASE}" not in form:
            fail("c07", "blocking", f"epithets.{eid}", "weapon_form must contain {BASE}")
        core = token[3:] if token.startswith("of ") else token
        if token and core.lower() not in form.lower():
            fail("c07", "blocking", f"epithets.{eid}", f"weapon_form does not carry its forge_vocab_token '{token}'")
        if "{OBJECT}" in form and "{BASE}" not in str(ep.get("weapon_form_bare") or ""):
            fail("c07", "blocking", f"epithets.{eid}", "a weapon_form with {OBJECT} needs a weapon_form_bare containing {BASE}")

    # --- c07d prologue_roster.weapon_art must be real or null (pu_nashar is
    #     the one deliberate non-combatant) -------------------------------------
    for r in tabs["prologue_roster"]:
        art = r.get("weapon_art")
        if art is not None and art not in MATRIX_ARTS:
            fail("c07", "blocking", f"prologue_roster.{r['punit_id']}",
                 f"weapon_art '{art}' is not one of {MATRIX_ARTS} or null")

    # --- c07e weapons.tier / enemy_archetypes.weapon_tier must be a real tier -
    for r in tabs["weapons"]:
        if r.get("tier") not in WEAPON_TIERS:
            fail("c07", "blocking", f"weapons.{r['weapon_id']}",
                 f"tier '{r.get('tier')}' is not one of {WEAPON_TIERS}")
    for r in tabs["enemy_archetypes"]:
        if r.get("weapon_tier") not in WEAPON_TIERS:
            fail("c07", "blocking", f"enemy_archetypes.{r['enemy_id']}",
                 f"weapon_tier '{r.get('weapon_tier')}' is not one of {WEAPON_TIERS}")

    # --- c07f encounter_spawns: map_id/enemy_id must resolve, kind must be
    #     real, row/col must be within that map's width/height, den rows must
    #     carry a spawn_interval/wave_size --------------------------------
    map_dims = {r["map_id"]: (r.get("width"), r.get("height")) for r in tabs["maps"]}
    SPAWN_KINDS = ["boss", "mook", "den"]
    for r in tabs["encounter_spawns"]:
        sid = r["spawn_id"]
        if r.get("map_id") not in map_dims:
            fail("c07", "blocking", f"encounter_spawns.{sid}",
                 f"map_id '{r.get('map_id')}' does not exist")
            continue
        if r.get("enemy_id") not in ids["enemy_archetypes"]:
            fail("c07", "blocking", f"encounter_spawns.{sid}",
                 f"enemy_id '{r.get('enemy_id')}' does not exist")
        if r.get("kind") not in SPAWN_KINDS:
            fail("c07", "blocking", f"encounter_spawns.{sid}",
                 f"kind '{r.get('kind')}' is not one of {SPAWN_KINDS}")
        width, height = map_dims[r["map_id"]]
        row, col = r.get("row"), r.get("col")
        if width and height and not (0 <= col < width and 0 <= row < height):
            fail("c07", "blocking", f"encounter_spawns.{sid}",
                 f"(row={row}, col={col}) is outside {r['map_id']}'s {width}x{height} grid")
        if r.get("kind") == "den" and not r.get("spawn_interval"):
            fail("c07", "blocking", f"encounter_spawns.{sid}",
                 "kind 'den' requires a spawn_interval")

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
