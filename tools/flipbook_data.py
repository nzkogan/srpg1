#!/usr/bin/env python3
"""Derives the class and weapon flipbook data from game/data/*.json (the exported canon)."""
import json
import re
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "game" / "data"
STATS = ["hp", "str", "mag", "dex", "spd", "lck", "def", "res"]
ARTS = ["sword", "lance", "axe", "bow", "brawl", "reason", "faith"]
TIER_ORDER = ["worn", "basic", "mid", "high", "legendary", "mythic"]


def load(name):
    return json.loads((DATA / f"{name}.json").read_text())


def pipe(v):
    return [x for x in str(v).split("|") if x] if v not in (None, "") else []


def trim(s, n=260):
    """A canon note made readable: sentences about when it was drafted go, identifiers become names,
    ALL-CAPS tags and one-word shorthand go. Cut at a sentence boundary."""
    if not s:
        return ""
    s = " ".join(str(s).split())
    s = re.sub(r"\s*\([^)]*20\d\d-\d\d-\d\d[^)]*\)", "", s)
    s = re.sub(r"^(?:[A-Z][A-Z ,\-]{3,}[A-Z])[:.]?\s*", "", s)
    s = re.sub(r"^\(forged from [^)]*\)\.?\s*", "", s)
    s = re.sub(r"\s*\([^)]*weapons\.[^)]*\)", "", s)
    s = re.sub(r"^lv\d+\+?,[^.]*\.\s*", "", s)
    s = s.replace("prm_forge_heal HP", "a set amount of HP")
    s = re.sub(r"\bcls_(\w+)", lambda m: "the " + m.group(1).replace("_", " ").capitalize(), s)
    s = re.sub(r"\bweapons\.\w+|\bea_\w+", "the enemy", s)
    s = s.replace("req_arts", "required arts")
    s = s.replace(" -- ", " – ").replace("DRAFTED, not placed on any unit. ", "")
    if ";" in s and len(s) < 80:
        return ""
    parts = [p for p in re.split(r"(?<=[.!?])\s+", s) if p and not p.startswith(",") and not re.search(r"20\d\d-\d\d-\d\d|\bADDED\b|\bdrafted\b", p, re.I)]
    out = ""
    for p in parts:
        if len(out) + len(p) > n and out:
            break
        out = (out + " " + p).strip()
    return out if len(out) >= 40 else ""


def build():
    chapters = {c["chapter_id"]: c for c in load("chapters")}
    maps = {m["map_id"]: m for m in load("maps")}
    units = {u["unit_id"]: u for u in load("units")}
    classes = load("classes")
    class_by_id = {c["class_id"]: c for c in classes}
    weapons = load("weapons")
    params = {p["param_id"].replace("prm_", ""): p for p in load("promotion_rules")}
    P = lambda k: p_val(params, k)
    growths = {g["profile_id"]: g for g in load("growths")}

    # chapter rank = fewest chapters from the prologue (a '|' in unlock_after is "either")
    rank = {"ch_f00": 0}
    changed = True
    while changed:
        changed = False
        for cid, c in chapters.items():
            ua = pipe(c.get("unlock_after"))
            cands = [rank[u] + 1 for u in ua if u in rank]
            if cands and (cid not in rank or min(cands) < rank[cid]):
                rank[cid] = min(cands)
                changed = True

    def chap(cid):
        c = chapters.get(cid)
        if not c:
            return None
        act = c["act"]
        route = {"diadem": "Diadem", "assembly": "Assembly", "both": ""}.get(c["route"], c["route"])
        col = c.get("column")
        label = f"Act {act}" if str(act).isdigit() else ("Prologue" if act == "prologue" else "Paralogue")
        return {"id": cid, "title": c["title"], "label": label, "route": route,
                "column": col if col in ("A", "B") else "", "rank": rank.get(cid, 99)}

    def chap_of_map(map_id):
        m = maps.get(map_id)
        return chap(m["chapter_id"]) if m else None

    # ------------------------------------------------------------ weapons
    arts_of_class = {c["class_id"]: [a for a in (c["art_primary"], c["art_secondary"]) if a in ARTS] for c in classes}
    join = {}
    for u in units.values():
        cls = class_by_id.get(u["base_class_id"], {})
        art = cls.get("art_primary")
        if art in ARTS and u.get("join_chapter_id"):
            c = chap(u["join_chapter_id"])
            join.setdefault(art, []).append((c["rank"], c, u["name"]))
    sources = {w["weapon_id"]: [] for w in weapons}
    for w in weapons:
        wid = w["weapon_id"]
        if w["tier"] == "basic" and join.get(w["art"]):
            r, c, who = sorted(join[w["art"]], key=lambda t: t[0])[0]
            sources[wid].append({"kind": "kit", "text": f"Carried by {who}, the first {w['art']} unit to join", "chapter": c})
        if int(w.get("convoy_qty") or 0) > 0:
            sources[wid].append({"kind": "convoy", "text": f"{int(w['convoy_qty'])} in the convoy from the start", "chapter": chap("ch_d01")})
    for s in load("encounter_spawns"):
        for wid in pipe(s.get("drop_weapon_id")):
            c = chap_of_map(s["map_id"])
            who = "the boss" if s["kind"] == "boss" else "an enemy"
            sources[wid].append({"kind": "drop", "text": f"Dropped by {who} of {c['title']}", "chapter": c})
    archetypes = {e["enemy_id"]: e for e in load("enemy_archetypes")}
    for m in load("materials"):
        if m.get("weapon_id") and m.get("enemy_id"):
            e = archetypes[m["enemy_id"]]
            c = chap_of_map(e["first_seen_map_id"])
            f = next((x for x in load("forges") if x["forge_id"] == m["forge_id"]), {})
            rule = f.get("access_rule") or ""
            gate = ""
            if rule.startswith("won:"):
                mp = maps.get(rule[4:], {})
                gate = f"; the smith opens once {mp.get('title', rule[4:])} is won"
            sources[m["weapon_id"]].append({"kind": "forge", "text": f"Forged from {m['drop']} ({e['name']}), {f.get('name', 'a master smith')}{gate}", "chapter": c})
    seen = {}
    for e in archetypes.values():
        if e.get("weapon_id"):
            sources[e["weapon_id"]].append({"kind": "enemy", "text": f"Carried by {e['name']}", "chapter": chap_of_map(e["first_seen_map_id"])})
        if e.get("first_seen_map_id") and e.get("weapon_art") in ARTS:
            wid = f"wpn_{e['weapon_art']}_{e['weapon_tier']}"
            c = chap_of_map(e["first_seen_map_id"])
            if wid in sources and (wid not in seen or c["rank"] < seen[wid]["rank"]):
                seen[wid] = c

    out_w = []
    for w in weapons:
        wid = w["weapon_id"]
        req = pipe(w.get("req_arts")) or ([w["art"]] if w["art"] in ARTS else [])
        gate = "paragon" if w["tier"] == "mythic" else ("cert" if w["tier"] in ("high", "legendary") else "")
        wielders = [c["name"] for c in classes if all(a in arts_of_class[c["class_id"]] for a in req) and (gate != "paragon" or c["tier"] == "paragon")]
        obtain = [s for s in sources[wid] if s["kind"] != "enemy"]
        first = min(obtain, key=lambda s: s["chapter"]["rank"]) if obtain else None
        tied = [s for s in obtain if first and s["chapter"]["rank"] == first["chapter"]["rank"]]
        out_w.append({
            "id": wid, "name": w["name"], "art": w["art"], "tier": w["tier"],
            "might": int(w["might"]), "hit": int(w["hit"]), "crit": int(w["crit"]), "weight": int(w["weight"]), "uses": int(w["uses"]),
            "range": [int(w["range_min"]), int(w["range_max"])],
            "req": req, "hybrid": len(req) > 1, "gated": bool(gate), "gate": gate,
            "effective": pipe(w.get("effective_vs")), "effect": w.get("effect"), "note": trim(w.get("notes")),
            "wielders": wielders, "sources": [{"kind": s["kind"], "text": s["text"], "chapter": s["chapter"]} for s in sources[wid]],
            "first": first, "firstTied": [t["chapter"] for t in tied if t["chapter"]["id"] != first["chapter"]["id"]] if first else [],
            "seen": seen.get(wid),
        })
    out_w.sort(key=lambda w: (ARTS.index(w["art"]) if w["art"] in ARTS else 9, w["hybrid"], TIER_ORDER.index(w["tier"])))

    # ------------------------------------------------------------ classes
    jump = {s: int(P(f"jump_{s}")) for s in STATS}
    pjump = {s: int(P(f"paragon_jump_{s}")) for s in STATS}
    shapes = {}
    for mv in ("infantry", "armor", "riding", "flying"):
        sh = {}
        for part in pipe(params.get(f"shape_{mv}", {}).get("text")):
            k, _, v = part.partition(":")
            sh[k] = int(v)
        shapes[mv] = sh
    holders = {}
    for u in units.values():
        holders.setdefault(u["base_class_id"], []).append(u)
    for g in load("guest_units"):          # a guest holds a class too (the Quartermasters)
        if str(g.get("guest_id", "")).startswith("gst_"):
            holders.setdefault(g["base_class_id"], []).append({"unit_id": g["guest_id"], "name": g["name"] + " (guest)", "growth_profile_id": g["growth_profile_id"], "join_chapter_id": None})
    stats_by_unit = {s["unit_id"]: s for s in load("unit_base_stats")}
    gating = [e for e in load("epithets") if e.get("gates_paragon") == "yes"]
    out_c = []
    for c in classes:
        tier = c["tier"]
        arts = arts_of_class[c["class_id"]]
        prom = class_by_id.get(c.get("promotes_from"))
        unlock = None
        if c.get("unlock_map_id"):
            ch = chap_of_map(c["unlock_map_id"])
            unlock = {"map": maps.get(c["unlock_map_id"], {}).get("title", c["unlock_map_id"]), "chapter": ch}
        req = []
        fee_base, fee_per, pmin = int(P("fee_base")), int(P("fee_per_level")), int(P("promote_min_level"))
        if tier == "commoner":
            req.append("None. Every recruit who has not yet trained starts here.")
        elif tier == "trained":
            req.append(f"A commoner at level 5 or more, trained in one art: {c['art_primary']}.")
        elif tier in ("order", "hybrid"):
            req.append(f"Certify from {prom['name'] if prom else 'a trained class'} at level {pmin} or more.")
            req.append(f"Fee {fee_base} gold, plus {fee_per} for each level past {pmin}: the earlier, the cheaper.")
            if tier == "hybrid" and unlock:
                req.append(f"Opens only after {unlock['map']} is won.")
            if tier == "order":
                req.append("One order class per movement type; a unit may switch between them for half the fee.")
        elif tier == "paragon":
            req.append(f"Certified, at level {int(P('paragon_min_level'))} or more, with a class that already knows {c['art_primary']}.")
            req.append(f"At least {int(P('paragon_deeds_required'))} deed that gates paragon: " + ", ".join(e["forge_vocab_token"].strip() + (" …" if e["forge_vocab_token"].endswith(" of") else "") for e in gating) + ".")
            req.append(f"Fee {int(P('paragon_fee_base'))} gold, plus {int(P('paragon_fee_per_level'))} per level past {int(P('paragon_min_level'))}.")
            if unlock:
                req.append(f"Opens only after {unlock['map']} is won.")
        elif tier == "personal":
            who = ", ".join(u["name"] for u in holders.get(c["class_id"], [])) or "no one yet"
            req.append(f"Held by {who}. No paperwork exists, so no one else can take it.")
            if who != "no one yet" and all("(guest)" in str(u["name"]) for u in holders.get(c["class_id"], [])):
                req.append("Guests do not level or certify: they travel with the company and keep its convoy.")
            else:
                req.append("Takes a milestone at level 15 and again at 30 instead of changing class.")
        elif tier == "shadow":
            req.append(f"Off the matrix: advances along its own line{', from ' + prom['name'] if prom else ''}.")
        promoted = tier in ("order", "hybrid", "paragon")
        shape = shapes.get(c["movement"], {}) if promoted else {}
        net = {s: (jump[s] + shape.get(s, 0) if tier in ("order", "hybrid", "paragon") else 0) for s in STATS}
        if tier == "paragon":
            net = {s: pjump[s] + shape.get(s, 0) for s in STATS}
        held = []
        for u in holders.get(c["class_id"], []):
            gp = growths.get(u["growth_profile_id"])
            join_c = chap(u["join_chapter_id"]) if u.get("join_chapter_id") else None
            held.append({"name": u["name"], "profile": u["growth_profile_id"].replace("gp_", ""), "rates": {s: gp[s] for s in STATS} if gp else {},
                         "join": join_c, "base": {s: int(stats_by_unit[u["unit_id"]][s]) for s in STATS} if u["unit_id"] in stats_by_unit else {}})
        wpn = [{"id": w["id"], "name": w["name"], "tier": w["tier"], "art": w["art"], "gated": w["gated"], "gate": w["gate"], "hybrid": w["hybrid"]}
               for w in out_w if all(a in arts for a in w["req"]) and arts]
        out_c.append({
            "id": c["class_id"], "name": c["name"], "tier": tier, "arts": arts, "art2raw": c["art_secondary"], "movement": c["movement"],
            "promotesFrom": {"id": prom["class_id"], "name": prom["name"]} if prom else None,
            "unlock": unlock, "actions": pipe(c.get("map_actions")), "note": trim(c.get("notes"), 300), "provenance": c.get("provenance"),
            "requirements": req, "promoted": promoted,
            "growth": {"net": net, "shape": shape, "bonus": (int(P("growth_bonus")) if promoted else 0) + (int(P("paragon_growth_bonus")) if tier == "paragon" else 0),
                       "kind": "paragon" if tier == "paragon" else ("promotion" if promoted else "none")},
            "held": held, "weapons": wpn,
        })
    tier_rank = {t: i for i, t in enumerate(["commoner", "trained", "order", "hybrid", "paragon", "personal", "shadow"])}
    out_c.sort(key=lambda c: (tier_rank[c["tier"]], ARTS.index(c["arts"][0]) if c["arts"] and c["arts"][0] in ARTS else 9, c["name"]))
    return {"classes": out_c, "weapons": out_w, "stats": STATS,
            "fees": {"promote": [fee_base, fee_per, pmin], "slots": int(P("slots_promotion"))}}


def p_val(params, k):
    row = params.get(k)
    return row["value"] if row and row.get("value") is not None else 0


if __name__ == "__main__":
    d = build()
    print(len(d["classes"]), "classes,", len(d["weapons"]), "weapons")
    for w in d["weapons"]:
        f = w["first"]
        print(f"{w['name']:18} {w['tier']:9} first={f['chapter']['title'] + ' (' + f['kind'] + ')' if f else '—':45} seen={w['seen']['title'] if w['seen'] else '—'}")
