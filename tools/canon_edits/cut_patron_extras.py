"""Cut the patron sub-systems that duplicated the procs (bound ground seals, patron of the day, offices). 2026-11-17."""
import openpyxl, re
wb = openpyxl.load_workbook('canon.xlsx')

def drop_col(ws, name):
    hdr = [c.value for c in ws[1]]
    if name in hdr:
        ws.delete_cols(hdr.index(name) + 1)

def scrub(ws, pattern):
    for row in ws.iter_rows():
        for c in row:
            if isinstance(c.value, str) and re.search(pattern, c.value, re.S):
                c.value = re.sub(pattern, '', c.value, flags=re.S).rstrip()

if 'offices' in wb.sheetnames:
    del wb['offices']
drop_col(wb['patrons'], 'office_id'); drop_col(wb['patrons'], 'office_text')
drop_col(wb['maps'], 'seal_tiles')
scrub(wb['patrons'], r' ADDENDUM \(2026-11-10, OFFICES_DESIGN\.md\):.*?DRAFTED: the assignments\.')
scrub(wb['maps'], r' ADDENDUM \(2026-11-08, BOUND_GROUND_DESIGN\.md\):.*?yours to move\.')

pr = wb['promotion_rules']
dead = re.compile(r'^prm_(seal_|office_|patron_day_bonus$)')
for r in range(pr.max_row, 1, -1):
    v = pr.cell(r, 1).value
    if isinstance(v, str) and dead.match(v):
        pr.delete_rows(r)
scrub(pr, r' ADDENDUM \(2026-11-08\): bound ground \(seal_\*\)\.')
scrub(pr, r' ADDENDUM \(2026-11-09\): patron_day_bonus \(PATRON_DAY_DESIGN\.md\)\.')
scrub(pr, r' ADDENDUM \(2026-11-10\): patron offices \(office_\*\)\.')

cl = wb['classes']; h = [c.value for c in cl[1]]; ci = h.index('map_actions') + 1
for r in range(2, cl.max_row + 1):
    if cl.cell(r, 1).value == 'cls_pardoner':
        cl.cell(r, ci).value = 'capture'
wb.save('canon.xlsx')
