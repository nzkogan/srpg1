"""Vertical slice: real enemy rosters and layouts for Diadem chapters 1-3. 2026-11-18.

Every name, layout and number here is DRAFTED for Nick to change. Tuned with game/tools/autoplay.gd so a plain player
wins each chapter in several turns, not one. Re-runnable: it replaces the spawns of these three maps each time."""
import openpyxl

ARCH = [  # enemy_id, name, art, tier_w, move, tier, lv, hp, str, mag, dex, spd, lck, def, res, behavior, first_map, flee, talk_mod, affiliation, death_noun
 ('ea_wharf_boss', 'Wharf boss', 'axe', 'basic', 'infantry', 'trained', 5, 24, 6, 0, 5, 4, 3, 5, 1,
  "DRAFTED 2026-11-18 (vertical slice). Runs the night crew stripping the tally house and holds its door; does not leave it. Boss of map_d01.", 'map_d01', None, None, 'band', 'axe'),
 ('ea_house_retainer', 'House retainer', 'lance', 'basic', 'infantry', 'trained', 4, 22, 6, 0, 5, 5, 2, 5, 1,
  "DRAFTED 2026-11-18 (vertical slice). The reluctant house's own men: loyal to the house, not to the fight, so they can be talked down.", 'map_d02', None, 10, 'band', 'lance'),
 ('ea_house_steward', 'The steward', 'sword', 'basic', 'infantry', 'trained', 6, 27, 7, 1, 7, 6, 4, 6, 3,
  "DRAFTED 2026-11-18 (vertical slice). Holds the weighbridge for the house against the writ. Boss of map_d02.", 'map_d02', None, None, 'individual', 'sword'),
 ('ea_ford_bandit', 'Ford bandit', 'axe', 'basic', 'infantry', 'trained', 5, 24, 7, 0, 6, 7, 3, 4, 1,
  "DRAFTED 2026-11-18 (vertical slice). Works the crossings of the grain road, the trade Jost came from.", 'map_d03', None, 15, 'band', 'axe'),
 ('ea_ford_captain', 'Ford captain', 'axe', 'basic', 'infantry', 'trained', 8, 32, 9, 0, 8, 7, 4, 7, 2,
  "DRAFTED 2026-11-18 (vertical slice). Holds the north end of the bridge, where every wagon has to pass. Boss of map_d03.", 'map_d03', None, None, 'individual', 'axe'),
]
# spawn_id, map, kind, enemy, row, col, interval, waves, size, notes, drop
SPAWNS = [
 ('spn_d01_boss', 'map_d01', 'boss', 'ea_wharf_boss', 0, 1, None, None, 1, 'DRAFTED: on the tally house door (the seize tile); the map is won by taking it from him.', None),
 ('spn_d01_lane1', 'map_d01', 'mook', 'ea_looter', 3, 3, None, None, 1, 'DRAFTED: in a warehouse lane (foot only).', None),
 ('spn_d01_lane2', 'map_d01', 'mook', 'ea_looter', 3, 9, None, None, 1, 'DRAFTED: in a warehouse lane (foot only).', None),
 ('spn_d01_yard', 'map_d01', 'mook', 'ea_looter', 6, 7, None, None, 1, 'DRAFTED: in the yard, the first contact.', None),
 ('spn_d01_quay1', 'map_d01', 'mook', 'ea_privateer', 1, 5, None, None, 1, 'DRAFTED: on the quay, guarding the way to the door.', None),
 ('spn_d01_quay2', 'map_d01', 'mook', 'ea_looter', 1, 11, None, None, 1, 'DRAFTED: on the quay, where the rider comes round.', None),
 ('spn_d02_boss', 'map_d02', 'boss', 'ea_house_steward', 1, 2, None, None, 1, 'DRAFTED: on the weighbridge (the seize tile).', None),
 ('spn_d02_ret1', 'map_d02', 'mook', 'ea_house_retainer', 2, 3, None, None, 1, "DRAFTED: the steward's guard.", None),
 ('spn_d02_ret2', 'map_d02', 'mook', 'ea_house_retainer', 1, 6, None, None, 1, "DRAFTED: the steward's guard.", None),
 ('spn_d02_ret3', 'map_d02', 'mook', 'ea_house_retainer', 2, 12, None, None, 1, 'DRAFTED: inside the gate, against the rider.', None),
 ('spn_d02_levy1', 'map_d02', 'mook', 'ea_conscript_levy', 4, 4, None, None, 1, 'Green levies in the field: they flee below half HP (the chapter teaches dispersal).', None),
 ('spn_d02_levy2', 'map_d02', 'mook', 'ea_conscript_levy', 4, 9, None, None, 1, 'See spn_d02_levy1.', None),
 ('spn_d02_levy3', 'map_d02', 'mook', 'ea_conscript_levy', 7, 13, None, None, 1, 'See spn_d02_levy1.', None),
 ('spn_d02_ret4', 'map_d02', 'mook', 'ea_house_retainer', 6, 6, None, None, 1, 'DRAFTED: a retainer out in the field with the levies, stiffening them.', None),
 ('spn_d02_den', 'map_d02', 'den', 'ea_conscript_levy', 0, 8, 3, 3, 1, "The house's back gate: more levies every 3 turns, 3 times, until it is taken.", None),
 ('spn_d03_boss', 'map_d03', 'boss', 'ea_ford_captain', 5, 5, None, None, 1, 'DRAFTED: at the north end of the bridge, beside the only crossing a wagon can use.', None),
 ('spn_d03_bridge', 'map_d03', 'mook', 'ea_ford_bandit', 7, 4, None, None, 1, 'DRAFTED: at the south end of the bridge.', None),
 ('spn_d03_ford', 'map_d03', 'mook', 'ea_ford_bandit', 5, 16, None, None, 1, 'DRAFTED: watching the ford (foot only).', None),
 ('spn_d03_road', 'map_d03', 'mook', 'ea_ford_bandit', 9, 7, None, None, 1, 'DRAFTED: on the road south of the river.', None),
 ('spn_d03_north', 'map_d03', 'mook', 'ea_ford_bandit', 3, 12, None, None, 1, 'DRAFTED: near the delivery point.', None),
 ('spn_d03_levy', 'map_d03', 'mook', 'ea_conscript_levy', 10, 12, None, None, 1, 'A pressed levy on the road.', None),
 ('spn_d03_ambush1', 'map_d03', 'mook', 'ea_ford_bandit', 8, 1, None, None, 1, 'DRAFTED: waiting by the west road for the wagons.', None),
 ('spn_d03_ambush2', 'map_d03', 'mook', 'ea_ford_bandit', 9, 10, None, None, 1, 'DRAFTED: on the road, between the wagons and the bridge.', None),
 ('spn_d03_den', 'map_d03', 'den', 'ea_ford_bandit', 1, 18, 8, 1, 2, "'turn 8 NE reinforcements' (map_d03's design note): two more bandits once, from the north-east.", None),
]
MAPS = {
 'map_d01': ("# map_d01 -- The tally house   14 x 10   (layout DRAFTED 2026-11-18, vertical slice)\n"
             "#   . dock frontage / yard   b warehouse (impassable)   s warehouse lane (foot only)\n"
             "#   * the tally house door (seize). A rider cannot use the lanes and must go round by the quay (cols 12-13).\n",
             ["b*............", "bb............", "bbbssbssbssb..", "bbbssbssbssb..", "bbbssbssbssb..",
              "..............", "..............", "..............", "..............", ".............."]),
 'map_d02': ("# map_d02 -- The weighbridge   16 x 12   (layout DRAFTED 2026-11-18, vertical slice)\n"
             "#   . open ground   h hedgerow (blocks riding only)   d the estate gate (riding)\n"
             "#   * the weighbridge (seize). The estate hedge stops a rider except at the gate on the far side.\n",
             ["................", "..*.............", "................", "hhhhhhhhhhhhhddd", "................",
              "...hh.....hh....", "...hh.....hh....", "................", "................", "................",
              "................", "................"]),
}
wb = openpyxl.load_workbook('canon.xlsx')
def hdr(ws): return [c.value for c in ws[1]]
ea = wb['enemy_archetypes']; h = hdr(ea)
have = {ea.cell(r, 1).value: r for r in range(2, ea.max_row + 1)}
cols = ['enemy_id', 'name', 'weapon_art', 'weapon_tier', 'movement_type', 'tier', 'level', 'hp', 'str', 'mag', 'dex', 'spd', 'lck',
        'def', 'res', 'behavior', 'first_seen_map_id', 'flees_below_pct', 'talk_mod', 'affiliation', 'death_noun']
for a in ARCH:
    row = have.get(a[0])
    if row is None:
        row = max(r for r in have.values()) + 1
        ea.insert_rows(row)
        for c in range(1, ea.max_column + 1):
            ea.cell(row, c)._style = ea.cell(row - 1, c)._style
        have = {ea.cell(r, 1).value: r for r in range(2, ea.max_row + 1)}
    for k, v in zip(cols, a):
        ea.cell(row, h.index(k) + 1).value = v
es = wb['encounter_spawns']; h = hdr(es)
for r in range(es.max_row, 1, -1):
    if es.cell(r, h.index('map_id') + 1).value in ('map_d01', 'map_d02', 'map_d03'):
        es.delete_rows(r)
last = max(r for r in range(2, es.max_row + 1) if es.cell(r, 1).value)
scols = ['spawn_id', 'map_id', 'kind', 'enemy_id', 'row', 'col', 'spawn_interval', 'max_waves', 'wave_size', 'notes', 'drop_weapon_id']
for i, s in enumerate(SPAWNS):
    r = last + 1 + i
    es.insert_rows(r)
    for c in range(1, es.max_column + 1):
        es.cell(r, c)._style = es.cell(last, c)._style
    for k, v in zip(scols, s):
        es.cell(r, h.index(k) + 1).value = v
mp = wb['maps']; h = hdr(mp)
for r in range(2, mp.max_row + 1):
    mid = mp.cell(r, 1).value
    if mid in ('map_d01', 'map_d02', 'map_d03'):
        note = mp.cell(r, h.index('design_note') + 1)
        if 'vertical slice' not in str(note.value):
            note.value = str(note.value) + " ADDENDUM (2026-11-18, vertical slice): enemy roster rebuilt and, for d01/d02, the layout redrawn; tuned with game/tools/autoplay.gd. DRAFTED."
        if mid == 'map_d02':
            mp.cell(r, h.index('reinforcement_source') + 1).value = 'den'
TALK = {  # DRAFTED 2026-11-18: one line each, for the talk resolution
 'ea_house_retainer': "It's the steward's quarrel, not mine. I'll stand aside.",
 'ea_ford_bandit': "The ford pays worse than you do. I never saw your wagons.",
}
ea = wb['enemy_archetypes']; h = hdr(ea)
for r in range(2, ea.max_row + 1):
    eid = ea.cell(r, 1).value
    if eid in TALK:
        ea.cell(r, h.index('talk_line') + 1).value = TALK[eid]
wb.save('canon.xlsx')
for mid, (head, rows) in MAPS.items():
    open(f'game/data/maps/{mid}.txt', 'w').write(head + "\n" + "\n".join(rows) + "\n")
