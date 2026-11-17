"""Rename the names that read as Fire Emblem: Three Houses residue. 2026-11-17.

Indech -> Pambo and Macuil -> Poemen: the two hermits who refuse to adjudicate now carry the names of two Desert
Fathers famous for exactly that (Abba Pambo, whose silence was his answer to an archbishop; Abba Poemen, who would not
judge a brother). The silent sect is already anchored to the Desert Fathers in christian_allegory.
Anna -> Alexia: still named for Anna Komnene, now through the Alexiad, the history she wrote.
Run from the repo root; it rewrites canon.xlsx and every text file in the repo, and renames the files whose names carry
the old ids."""
import openpyxl, os, re, subprocess

KEEP = '\x00KOMNENE\x00'
RULES = [
    (r'Anna Komnene', KEEP), (r'ref_anna_komnene', 'ref_\x00annak\x00'),
    (r'ANNA_DESIGN', 'ALEXIA_DESIGN'), (r"ANNA'S", "ALEXIA'S"), (r'gst_anna', 'gst_alexia'),
    (r'sc_anna_fixed', 'sc_alexia_fixed'), (r'\banna(?=\b|_|-)', 'alexia'), (r'\bAnna\b', 'Alexia'),
    (r'INDECH', 'PAMBO'), (r'Indech', 'Pambo'), (r'indech', 'pambo'),
    (r'MACUIL', 'POEMEN'), (r'Macuil', 'Poemen'), (r'macuil', 'poemen'),
    (KEEP, 'Anna Komnene'), ('ref_\x00annak\x00', 'ref_anna_komnene'),
]
EXTRA = {   # specific cells rewritten, not renamed
    'FODLAN CANON MASTER DATA': 'CANON MASTER DATA',
    "this asymmetry was present in the original FE3H-era design": "this asymmetry was present in the original design",
    "flag_route, flag_byleth, flag_claude, flag_lysithea deleted -- all four described the cut canon-input prologue (importing FE3H route/pairing/survival choices from a prior save)":
        "four flags deleted -- all four described the cut canon-input prologue (importing route/pairing/survival choices from a prior game's save)",
    "DIRECT REFERENTIALITY, in the register FE3H used for the Fomorians (Cichol, Pambo, Cethleann, Conand -- undisguised Irish myth names).":
        "DIRECT REFERENTIALITY: undisguised names from real history and myth, used openly.",
}

def apply(text):
    for a, b in RULES:
        text = re.sub(a, b, text)
    for a, b in EXTRA.items():
        text = text.replace(a, b)
    return text

wb = openpyxl.load_workbook('canon.xlsx')
for ws in wb.worksheets:
    for row in ws.iter_rows():
        for c in row:
            if isinstance(c.value, str):
                n = apply(c.value)
                if n != c.value:
                    c.value = n
wb.save('canon.xlsx')

files = subprocess.run(['git', 'ls-files'], capture_output=True, text=True).stdout.split('\n')
for f in files:
    if not f or not os.path.isfile(f) or f.endswith(('.xlsx', '.db', '.png', '.glb', '.import')) or f.startswith('tools/canon_edits/'):
        continue
    try:
        t = open(f, encoding='utf-8').read()
    except UnicodeDecodeError:
        continue
    n = apply(t)
    if n != t:
        open(f, 'w', encoding='utf-8').write(n)
for f in files:
    if f and os.path.isfile(f) and not f.startswith('tools/canon_edits/'):
        g = apply(f)
        if g != f:
            subprocess.run(['git', 'mv', f, g], check=True)
