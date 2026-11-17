"""Re-anchor the Enlightened One's Perverse ending away from Sabbatai Zevi, and add a living-church caution for the
Continuing Word. 2026-11-17.

The Company of the Road is the lending sect, and canon protects it with an antisemitism guardrail (christian_allegory,
sect_road). Modelling its false god's aftermath on a Jewish messianic claimant undercuts that guardrail. The same shape
(a remnant that reads the failure as a hidden necessary step and carries on) has a Christian anchor: the Millerites'
Great Disappointment of 1844. The Hierophant (the Continuing Word) keeps its Sabbatai Zevi / Nathan of Gaza model,
which is about prophecy and the herald, not money."""
import openpyxl
OLD = ("Historical anchor: Sabbatai Zevi, the 17th c. claimant given a choice between conversion to Islam and execution, "
       "who converted -- and the Donmeh, a real following who reinterpreted the conversion as part of the messianic process "
       "rather than its refutation, and continued for centuries")
NEW = ("Historical anchor: the Great Disappointment of 1844 -- William Miller's followers waited for an end that did not "
       "come, and a remnant decided the date had been right but the event had been misread: something had happened, "
       "unseen, and the movement carried on (it became a church that exists today). Re-anchored 2026-11-17: the earlier "
       "anchor (Sabbatai Zevi and the Donmeh) put a Jewish messianic claimant behind the lending sect's false god, which "
       "undercuts the antisemitism guardrail in christian_allegory.sect_road.")
MARCH = (" ADDENDUM (2026-11-17): the restorationist cosmology and the rebaptism of the dead echo a living church. Write the "
         "Continuing Word's people as sincere and its practices as humane on their own terms; the setting's refusal to "
         "settle the question protects them only if no scene treats them as the punchline.")
wb = openpyxl.load_workbook('canon.xlsx')
en = wb['endings']
for row in en.iter_rows():
    for c in row:
        if isinstance(c.value, str) and OLD in c.value:
            c.value = c.value.replace(OLD, NEW)
ca = wb['christian_allegory']
for row in ca.iter_rows():
    if row[0].value == 'sect_march':
        cell = row[-1]
        if 'ADDENDUM (2026-11-17)' not in str(cell.value):
            cell.value = str(cell.value) + MARCH
wb.save('canon.xlsx')
