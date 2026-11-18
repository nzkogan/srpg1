"""Vertical slice: the Karkadann's paralogue, brought forward to follow Diadem 3 and scaled to an Act 1 party. 2026-11-18.

Nick chose it for the slice. Everything here is DRAFTED: the early unlock, the creature's numbers, and the boss
standing on the colony's heart (the seize tile), so the map is won by facing it rather than walking past it."""
import openpyxl, os, re
wb = openpyxl.load_workbook('canon.xlsx')
def hdr(ws): return [c.value for c in ws[1]]
def set_row(ws, key, vals):
    h = hdr(ws)
    for r in range(2, ws.max_row + 1):
        if ws.cell(r, 1).value == key:
            for k, v in vals.items():
                ws.cell(r, h.index(k) + 1).value = v
            return r
    raise KeyError(key)

NOTE = (" ADDENDUM (2026-11-18, vertical slice): DRAFTED. Brought forward to open after chapter 3 on either route, and "
        "scaled to an Act 1 party, because it is the slice's paralogue ('the plain one on purpose'). Its earlier numbers "
        "were lv 33 / hp 78 / str 24 / def 22 / spd 18 with a high-tier brawl weapon.")
ea = wb['enemy_archetypes']; h = hdr(ea)
r = set_row(ea, 'ea_karkadann', {'level': 8, 'hp': 46, 'str': 8, 'mag': 2, 'dex': 7, 'spd': 5, 'lck': 6, 'def': 7, 'res': 3,
                                 'weapon_tier': 'basic'})
b = ea.cell(r, h.index('behavior') + 1)
if 'vertical slice' not in str(b.value):
    b.value = str(b.value) + NOTE

ch = wb['chapters']; h = hdr(ch)
r = set_row(ch, 'ch_p_karkadann', {'unlock_after': 'ch_a03|ch_d03'})
n = ch.cell(r, h.index('notes') + 1)
if 'vertical slice' not in str(n.value):
    n.value = str(n.value) + " ADDENDUM (2026-11-18, vertical slice): DRAFTED. Unlocks after chapter 3 on either route (was after chapter 10), as the slice's paralogue."

es = wb['encounter_spawns']; h = hdr(es)
r = set_row(es, 'spn_pkarkadann_boss', {'row': 4, 'col': 8})
n = es.cell(r, h.index('notes') + 1)
if 'vertical slice' not in str(n.value):
    n.value = str(n.value) + " ADDENDUM (2026-11-18, vertical slice): DRAFTED. Stands on the colony's heart (the seize tile), so the clearing is taken by facing it."

sc = wb['scenes']; h = hdr(sc)
have = {sc.cell(r, 1).value: r for r in range(2, sc.max_row + 1) if sc.cell(r, 1).value}
if 'sc_p_karkadann_pre' not in have:
    r = max(have.values()) + 1
    sc.insert_rows(r)
    for c in range(1, sc.max_column + 1):
        sc.cell(r, c)._style = sc.cell(r - 1, c)._style
    vals = {'scene_id': 'sc_p_karkadann_pre', 'chapter_id': 'ch_p_karkadann', 'type': 'pre-battle',
            'speaker_ids': 'u_avatar|u_jost|u_tancred', 'depends_on_flags': None, 'depends_on_units': None,
            'summary': "The ash field and the clearing in it, full of doves, and the Karkadann standing over them. Nothing about it is a riddle: it guards what it has decided to guard.",
            'status': 'drafted', 'word_count': 0}
    for k, v in vals.items():
        sc.cell(r, h.index(k) + 1).value = v
# word counts from the scripts in game/dialogue
for r in range(2, sc.max_row + 1):
    sid = sc.cell(r, 1).value
    path = f'game/dialogue/{sid}.txt'
    if sid in ('sc_p_karkadann', 'sc_p_karkadann_pre') and os.path.exists(path):
        body = [l for l in open(path).read().split('\n') if l.strip() and not l.startswith('#')]
        sc.cell(r, h.index('word_count') + 1).value = sum(len(re.sub(r'^[^:>]*:\s*|^>\s*', '', l).split()) for l in body)
wb.save('canon.xlsx')
