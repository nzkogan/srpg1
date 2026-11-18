"""Vertical slice: scene rows for the prologue and Diadem chapters 1-3. 2026-11-18.

Each row's script lives in game/dialogue/<scene_id>.txt; word_count is filled from it. The summaries follow canon
(the prologue's turn, Kest's recruitment as the units tab describes it) and Act 1's DRAFTED story jobs."""
import openpyxl, os, re
SCENES = [
 ('sc_f00_pre', 'ch_f00', 'pre-battle', 'pu_sargath|pu_enmet|pu_ilat|pu_nashar',
  "The last night of Ur-Nashet. Enmet will take the river wall in one cast at first light; the patron's image in the court cannot be cast down, only worn down, by every hand. Nashar is to keep the book dry."),
 ('sc_f00_post', 'ch_f00', 'post-battle', 'pu_sargath|pu_nashar|pu_ilat',
  "The image is rubble. Nashar writes the patron into the book; a hand covers the page and the rain is on it. The name is never shown."),
 ('sc_d01_pre', 'ch_d01', 'pre-battle', 'u_avatar|u_sigrun|u_dietmar',
  "The tally house at night. The ledger and the warehouse disagree by half; a crew is carrying sacks out through the lanes. The lanes are too narrow for a horse."),
 ('sc_d01_post', 'ch_d01', 'post-battle', 'u_avatar|u_kheldar',
  "Kheldar's manifest says what the Avatar's ledger says. The difference left on a boat. Kheldar offers credit against the shortfall, on fair terms."),
 ('sc_d02_pre', 'ch_d02', 'pre-battle', 'u_avatar|u_emmerich|u_ricberta',
  "A requisition writ for a house that has already said no. Emmerich's figures are the Baron's; Ricberta knows the writ a little too well for someone who had it read to her. The levies in the field were farmers last week."),
 ('sc_d02_post', 'ch_d02', 'post-battle', 'u_avatar|u_kest',
  "Kest, mid-heist in an abandoned house, argues both sides of taking one small worthless thing -- a decan token -- and takes it. The Avatar notices the argument was with someone who is not there."),
 ('sc_d03_pre', 'ch_d03', 'pre-battle', 'u_avatar|u_tancred|u_sigrun',
  "Three wagons of the weighbridge's grain and one bridge a wagon can cross. Tancred's village has given twice already; Tancred is here to see it arrive."),
 ('sc_d03_post', 'ch_d03', 'post-battle', 'u_avatar|u_jost',
  "Jost, who slept through the morning on the bandits' side of the bridge, would rather walk beside the grain than wait for it at a ford."),
]
wb = openpyxl.load_workbook('canon.xlsx')
ws = wb['scenes']; h = [c.value for c in ws[1]]
have = {ws.cell(r, 1).value: r for r in range(2, ws.max_row + 1) if ws.cell(r, 1).value}
last = max(have.values())
for sid, ch, kind, speakers, summary in SCENES:
    path = f'game/dialogue/{sid}.txt'
    words = 0
    if os.path.exists(path):
        body = [l for l in open(path).read().split('\n') if l.strip() and not l.startswith('#')]
        words = sum(len(re.sub(r'^[^:>]*:\s*|^>\s*', '', l).split()) for l in body)
    r = have.get(sid)
    if r is None:
        last += 1
        r = last
        ws.insert_rows(r)
        for c in range(1, ws.max_column + 1):
            ws.cell(r, c)._style = ws.cell(r - 1, c)._style
    vals = {'scene_id': sid, 'chapter_id': ch, 'type': kind, 'speaker_ids': speakers, 'depends_on_flags': None,
            'depends_on_units': None, 'summary': summary, 'status': 'drafted', 'word_count': words}
    for k, v in vals.items():
        ws.cell(r, h.index(k) + 1).value = v
wb.save('canon.xlsx')
