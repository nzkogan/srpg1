"""Cut Act 1 to six chapters a route and give each survivor a job. 2026-11-17.

The cut chapters were back-filled from one-line location notes and recruited no one and advanced nothing.
Their locations stay on the world map as places the road passes through. story_job is DRAFTED: what each
remaining chapter is FOR in the story, so a scene or a map can be checked against it."""
import openpyxl
CUT = ['d04', 'd06', 'd08', 'd09', 'a04', 'a05', 'a06', 'a08']
RELINK = {'ch_d05': 'ch_d03', 'ch_d07': 'ch_d05', 'ch_d10': 'ch_d07', 'ch_a07': 'ch_a03', 'ch_a09': 'ch_a07',
          'ch_p_poemen': 'ch_a03|ch_d05', 'ch_p_simurgh': 'ch_a03|ch_d05', 'ch_p_pambo': 'ch_a07|ch_d07', 'ch_p_shadhavar': 'ch_a07|ch_d07'}
JOBS = {
 'ch_d01': "DRAFTED. Open on the clerk's real job: counting grain that is not there. Kheldar's manifest discrepancy starts here, and Kheldar is the first to offer credit against the shortfall -- the first strand of the network the Enlightened One will inherit.",
 'ch_d02': "DRAFTED. The state taking what it needs from a house that cannot refuse. Kest pockets her twin's decan token (the Act 3 evidence); Ricberta's hidden literacy is first visible to an attentive player.",
 'ch_d03': "DRAFTED. What feeding the capital costs the villages along the way. Jost and Tancred join; the first escort teaches that legible deeds (a delivery) are what the clerks will count.",
 'ch_d05': "DRAFTED. The Diadem's reach: grain bought abroad, on credit, through the factors. The convoy routes the player builds here are the distribution network canon says the Enlightened One is handed in Act 3.",
 'ch_d07': "DRAFTED. First sight of the silent: renunciants living in a ruin who will not explain or judge. Sets up Pambo and the refusal to adjudicate as a position, not an evasion.",
 'ch_d10': "DRAFTED. The Unstained will not talk. The route's finale is a door that answers with force; it sets up the occupation Waldrada will not serve (v21) and what is buried under Vashti.",
 'ch_a01': "DRAFTED. Medicine, not grain: the Assembly's crisis is authority, not supply -- the dole runs because a rump council improvises. The medicine was bought on Company credit, the first strand of the network on this route.",
 'ch_a02': "DRAFTED. Belief as a battlefield force: a preacher converts one a turn. The jailed preacher is the Act 2 hook into the Continuing Word; Solveig, Gunnar and Edda join.",
 'ch_a03': "DRAFTED. Anselm joins and starts asking the question he will leave over at Vetch. The reliquary to take or give is the route's first mercy-or-extraction choice the ledger reads.",
 'ch_a07': "DRAFTED. Holding a cliff where the rift never filled: the material explanation of the Drowned March (the ground simply dropped), seen before the sacred one is preached at the shrine.",
 'ch_a09': "DRAFTED. New scripture still arriving: the Continuing Word's method, converting levies in the field, shown before the Hierophant's movement consolidates out of it in Act 3.",
 'ch_a10': "DRAFTED. Obedience belongs to the throne: the court sect at home, its gate shut. Seeds Anselm's departure when the crown answers with it at the Vetch Reunion.",
}
wb = openpyxl.load_workbook('canon.xlsx')
def hdr(ws): return [c.value for c in ws[1]]
def drop_rows(ws, pred):
    h = hdr(ws)
    for r in range(ws.max_row, 1, -1):
        row = {h[i]: ws.cell(r, i + 1).value for i in range(len(h))}
        if pred(row):
            ws.delete_rows(r)
cut_ch = {f'ch_{c}' for c in CUT}; cut_map = {f'map_{c}' for c in CUT}; cut_sc = {f'sc_{c}' for c in CUT}
drop_rows(wb['chapters'], lambda r: r.get('chapter_id') in cut_ch)
drop_rows(wb['maps'], lambda r: r.get('map_id') in cut_map)
drop_rows(wb['encounter_spawns'], lambda r: r.get('map_id') in cut_map)
drop_rows(wb['scenes'], lambda r: r.get('scene_id') in cut_sc)
ch = wb['chapters']; h = hdr(ch)
if 'story_job' not in h:
    col = ch.max_column + 1
    c = ch.cell(1, col, 'story_job'); c._style = ch.cell(1, col - 1)._style
    h = hdr(ch)
ui, ji = h.index('unlock_after') + 1, h.index('story_job') + 1
for r in range(2, ch.max_row + 1):
    cid = ch.cell(r, 1).value
    if cid in RELINK:
        ch.cell(r, ui).value = RELINK[cid]
    if cid in JOBS:
        ch.cell(r, ji).value = JOBS[cid]
wb.save('canon.xlsx')

# The Timber Road boss dropped the Vila's Moonbow; it moves to the Upper Scar's boss (a mountain wall, where the vila hunts).
wb = openpyxl.load_workbook('canon.xlsx')
es = wb['encounter_spawns']; h = hdr(es); di = h.index('drop_weapon_id') + 1
for r in range(2, es.max_row + 1):
    if es.cell(r, 1).value == 'spn_a07_boss':
        es.cell(r, di).value = 'wpn_vila_moonbow'
wp = wb['weapons']; h = hdr(wp); ni = h.index('notes') + 1
for r in range(2, wp.max_row + 1):
    if wp.cell(r, 1).value == 'wpn_vila_moonbow':
        wp.cell(r, ni).value = str(wp.cell(r, ni).value).replace('Dropped on the Timber Road.', 'Dropped on the Upper Scar (moved from the Timber Road when that chapter was cut, 2026-11-17).')
wb.save('canon.xlsx')

# The Morningstar was dropped by the two cut harbour bosses; the Vashti Gate captain carries it now.
wb = openpyxl.load_workbook('canon.xlsx')
es = wb['encounter_spawns']; h = hdr(es); di = h.index('drop_weapon_id') + 1
for r in range(2, es.max_row + 1):
    if es.cell(r, 1).value == 'spn_d10_boss':
        es.cell(r, di).value = 'wpn_morningstar'
wp = wb['weapons']; h = hdr(wp); ni = h.index('notes') + 1
for r in range(2, wp.max_row + 1):
    if wp.cell(r, 1).value == 'wpn_morningstar':
        wp.cell(r, ni).value = str(wp.cell(r, ni).value).replace('Dropped by the harbour bosses of Act 1.', 'Dropped by the captain at Vashti Gate (moved from the harbour bosses of Act 1 when those chapters were cut, 2026-11-17).')
wb.save('canon.xlsx')
