#!/usr/bin/env python3
"""Builds flipbooks/timeline.html: the chronicle of the setting and the campaign, from the exported canon.

    python3 tools/make_timeline.py
Run after python3 export_canon_json.py. The deep-history and branch text is written here from canon's eras, flashbacks,
defections, endings and calendar tabs; the chapter lists, locations and cast joins are read from game/data/*.json.
"""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
D = ROOT / "game" / "data"
def load(n): return json.load(open(D / f"{n}.json"))
e = html.escape

chapters = {c["chapter_id"]: c for c in load("chapters")}
locs = {l["location_id"]: l for l in load("locations")}
units = load("units")
joins = {}
for u in units:
    joins.setdefault(u["join_chapter_id"], []).append(u["name"])

def loc_name(cid):
    n = locs.get(chapters[cid]["location_id"], {}).get("name", "")
    return n.split(" (")[0]

def tags(*items):
    out = []
    for layer, text in items:
        out.append(f'<span class="tag t-{layer}" data-layer="{layer}">{e(text)}</span>')
    return "".join(out)

def chrow(cid, extra=""):
    c = chapters[cid]
    j = joins.get(cid)
    jt = tags(("main", "joins: " + ", ".join(j))) if j else ""
    num = {"diadem": "D", "assembly": "A"}.get(c["route"], "") 
    label = f'{c["number"]}' if c["act"] != "paralogue" else "P"
    return (f'<li class="ch" data-layer="main"><span class="no">{e(label)}</span><div><b>{e(c["title"])}</b>'
            f'<small>{e(loc_name(cid))} · {e(c["tonal_register"])}</small>{jt}{extra}</div></li>')

def ev(layer, when, title, body, tg="", cls=""):
    return (f'<article class="ev {cls}" data-layer="{layer}"><div class="when">{e(when)}</div><div class="what"><h4>{e(title)}</h4>'
            f'<p>{body}</p>{tg}</div></article>')

# ------------------------------------------------------------------ Part I: the record
ERAS = [
 ("era_cities", "The Hundred Cities", "about 800 years before",
  "Every valley held a city-state with its own patron, temple and king. The patrons were named parties with terms, not metaphors.",
  [ev("play", "Memory F0 · prologue", "Ur-Nashet, the last night",
      "The first battle of the game is 800 years early, in a city that no longer exists. Eight ancestors, each a preview of a class you will spend thirty chapters earning. The city is taken and its patron is written into a book, and you did that. The name is never shown: the scribe's hand covers the page, the angle is wrong, the rain is on it.",
      tags(("sys", "built: the prologue"), ("lore", "no permadeath · chariots · one weapon each")), "playable")]),
 ("era_binding", "The Binding of Sargath", "about 780 years before",
  "Sargath of Ur-Nashet binds the rest. He did not kill the patrons; he wrote them down, which turned gods into signatories. Every pact in the present is a clause in a treaty nobody alive negotiated.",
  [ev("lore", "The First Register", "A register is written",
      "Which patron owes what to whom. It outlived his empire by seven centuries. The demons the nobles borrow from are deposed city-patrons, and the register is his instrument.", ""),
   ev("play", "Memory F1 · between Act 1 and Act 2", "The scribes' quarter",
      "The Register is copied for the first time, under deadline. Five defenders hold a walled quarter; four copyists sit at their desks and three must live eight turns. A clerk writes each deed down under the doer's name, which teaches the epithet ledger. When the copy is finished a page is lost and nothing ever says which. The missing name enters the world here, as an accident nobody notices.",
      tags(("sys", "built: copyists · clerk ledger · the lost page")), "playable")]),
 ("era_empire", "The Long Reign", "780 to 90 years before",
  "One realm, one church, and the church that held it together was not telling the truth. Learning moved east and came back translated; the capital lived on inheritance. This is the age the Diadem still thinks it is living in.",
  [ev("play", "Memory F2 · between Act 2 and Act 3", "The last court of the Long Reign",
      "The church that held the realm together, on the day it stopped being believed. Six defenders face fourteen levies, no reinforcements, no supply. Every pact answers once, free, and the court falls regardless. Hold to dawn or lose the company first: either way the memory counts, and losing is its ending.",
      tags(("sys", "built: free pact · the court falls")), "playable")]),
 ("era_venerated", "The Venerated", "about 90 to 40 years before",
  "A person, and then an absence. What they did is disputed, whether they died is disputed, and so is the tomb. No depiction survives that all parties accept as authentic. The sects are five answers to one question the game never settles.",
  [ev("lore", "The calendar schism", "When was the Venerated born?",
      "That fixes the sign, the governing decan, the feast kept and which spirits are properly invoked. The court keeps the Ram (spring, born at the lambing). The Continuing Word says the Vessel (winter, and the date can move). The Company of the Road says the Scales (autumn, the reckoning season). The Unstained hold no feast valid. The silent will not say, and they are the only ones who might know.",
      tags(("sys", "built: each sect's calendar sets which unit signs a chapter favours")), ""),
   ev("open", "Unwritten", "The five answers",
      "Canon fixes the question and the sects' stances but not what each sect says the Venerated did. Writing the five answers, each credible and none provable, is the heart of the setting.", tags(("open", "needs authoring")), "gap")]),
 ("era_war", "The War of the Two Claims", "40 to 1 years before",
  "The realm splits: crowned succession against elective succession, and both call themselves the inheritance. It ended in exhaustion, not victory. The claim did not end.",
  [ev("lore", "The wounds", "What the war and the plague left",
      "Each sect carries one. The Vashti men: the lords who hosted the experiments still hold office. The March voices: plague, and the last hierarch's silence. The Company of the Road: starvation, when the war closed the road, and a stranger who extended credit to people who could not repay. The court: proximity to power. The silent: closest to the truth, least interested in sharing it.", ""),
   ev("lore", "Year 0", "Act 1 opens the year after", "The Diadem (crowned, antique, the largest library on the continent, almost none of it originally theirs) and the Assembly (elective, socially current: contract law, property held by women) are two exhausted co-claimants.", "")]),
]

def era_block(eid, name, when, text, items):
    return (f'<section class="era" id="{eid}"><header class="eh"><div class="ew">{e(when)}</div><h3>{e(name)}</h3><p>{e(text)}</p></header>'
            f'<div class="evs">{"".join(items)}</div></section>')

part1 = "".join(era_block(*x) for x in ERAS)

# ------------------------------------------------------------------ Part II: the campaign
def column(title, cids, cls=""):
    return f'<div class="col {cls}"><h5>{e(title)}</h5><ol>{"".join(chrow(c) for c in cids)}</ol></div>'

act1_d = [f"ch_d{n:02d}" for n in range(1, 11)]
act1_a = [f"ch_a{n:02d}" for n in range(1, 11)]
kheldar = ""

para = [
 ("ch_p_macuil", "after chapter 5 on either road"), ("ch_p_simurgh", "after chapter 5"), ("ch_p_indech", "after chapter 6"),
 ("ch_p_shadhavar", "after chapter 6"), ("ch_p_karkadann", "after chapter 10"), ("ch_p_buried_works", "after chapter 10"),
 ("ch_p_anzu", "after the Second Writ"), ("ch_p_huma", "after the Second Writ"),
]
named = {"ch_p_simurgh": "the Simurgh", "ch_p_shadhavar": "the Shadhavar", "ch_p_karkadann": "the Karkadann", "ch_p_anzu": "the Anzu", "ch_p_huma": "the Huma"}
para_html = "".join(
    f'<li class="ch" data-layer="main"><span class="no">P</span><div><b>{e(chapters[c]["title"])}</b><small>{e(loc_name(c))} · {e(when)}</small>'
    + (tags(("sys", f"{named[c]}: a mount, or a hazard" if c != "ch_p_huma" else "the Huma: a shadow, never a unit")) if c in named else "") + "</div></li>"
    for c, when in para)

act1 = f"""
<section class="act" id="act1"><header class="ah"><span class="an">Act 1</span><h3>The crossing</h3><p>The year after the war. Two routes, each ten chapters, each starting in a different institution's shadow: a clerk on the Diadem's docks, a healer's cart at the Assembly's gate. Kheldar, the smuggler, is on both.</p></header>
<div class="split">{column("The Diadem road", act1_d, "c-d")}{column("The Assembly road", act1_a, "c-a")}</div>
<div class="side"><h5>The side roads: paralogues of the Named</h5><p class="note">Five creatures pact with an object (a feather, a shadow, a nest, a song, a register). Each paralogue is a capstone you may capture, kill or leave. Capture them gently and they become mounts; kill one and the others will not be taken (the Named know each other).</p><ol>{para_html}</ol></div>
<div class="bridge" data-layer="play">&darr; The Act 1 finale hands the party into <b>Memory F1</b>, the scribes' quarter, before Act 2 begins.</div></section>"""

writ = ev("sys", "Chapter 11 · both roads", "The Second Writ",
          "The largest map, the whole army deployed once. The commission splits. The church surveyor is revealed as the crown's auditor, and the deputy is named off the epithet ledger: the crown's pick is accepted, or contested once, which the crown grants and pays for by withholding Column B's supply. Eight candidates are scored on witnessed deeds, objectives and kills.",
          tags(("sys", "built: the ledger and the writ"), ("open", "the writ scene is unwritten")), "key")

wal = ev("main", "After The Unstained Seat", "Waldrada leaves",
         "A scripted defection on the Diadem road: the Vashti campaign becomes an occupation she will not carry orders for. She returns as a lieutenant beside the first foe of Re-Made Clean. Not the boss; the map can be won without killing her. No way back.",
         tags(("sys", "built: defections")), "defect")
ans = ev("main", "After The Vetch Reunion", "Anselm leaves",
         "A scripted defection on the Assembly road, and a theological event rather than a grievance: the court sect's answer is that obedience belongs to the throne. He appears at the Kaisareia granary. No way back.",
         tags(("sys", "built: defections")), "defect")
mar = ev("main", "After The going rate", "Maren may leave",
         "Conditional. If Column B's opener is won and the Cinder Track was never worked, the state's medicine policy has written the Ashland off, and Maren goes. She returns as a lieutenant at the Throat Pass. Win the Cinder Track afterwards, and she comes home with the weapons she took.",
         tags(("sys", "built: a supply decision that reverses"), ("open", "Kest's restitution thread feeds the ascension signals")), "defect")
anna_svg = ('<svg class="anna" viewBox="0 0 64 72" role="img" aria-label="A drafted sketch of Anna: red hair in a ponytail">'
            '<path d="M45 22c10 2 13 14 8 26-2 5-6 8-9 8l-2-6c3-4 4-12 1-17z" fill="#b8431f"/>'
            '<circle cx="30" cy="30" r="15" style="fill:var(--skin)"/>'
            '<path d="M14 28c2-14 18-18 28-9 3 3 4 7 3 10-5-2-9-6-12-9-4 5-10 8-19 8z" fill="#c8512a"/>'
            '<rect x="42" y="20" width="6" height="5" rx="2" style="fill:var(--gold)"/>'
            '<circle cx="25" cy="32" r="1.6" style="fill:var(--ink)"/><circle cx="35" cy="32" r="1.6" style="fill:var(--ink)"/>'
            '<path d="M26 39c3 2 6 2 9 0" style="stroke:var(--ink)" stroke-width="1.5" fill="none" stroke-linecap="round"/>'
            '<path d="M10 72c1-14 9-20 20-20s19 6 20 20z" style="fill:var(--accent)"/></svg>')
anna = (f'<article class="ev anna-ev" data-layer="main"><div class="when">Once both Anselm and Maren have gone</div><div class="what anna-w">{anna_svg}<div><h4>Anna joins, and leaves at the Reunion</h4>'
        '<p>A faith unit who covers the gap the two departures open, fighting a little below the squad, with no support chain and no place in the 153. She has one fixed scene on the eve of the Reunion, shows the parish lists beside the decan tables, and goes on enrolling the plague dead by name. She is the one who might know when the Venerated was born. Her Act 3 payoff is the missing text.'
        + tags(("sys", "built: her scene and the roll's last line"), ("open", "the decan token is unwritten")) +
        '<span class="aside">Sketch: red hair in a ponytail. A joke from the table, not canon.</span></p></div></div></article>')

act2 = f"""
<section class="act" id="act2"><header class="ah"><span class="an">Act 2</span><h3>The columns</h3><p>The army splits by sect and by supply. Each stop is a seat of one sect's answer to the same question.</p></header>
<div class="stage">{writ}</div>
<div class="split">{column("Diadem road: the Vashti seat", ["ch_v21","ch_v22"], "c-d")}{column("Assembly road: the Drowned March", ["ch_m21","ch_m22"], "c-a")}</div>
<div class="stage">{wal}</div>
<div class="stage"><ol class="solo">{chrow("ch_c21")}</ol>{ans}</div>
<div class="split">{column("Column A: the ash", ["ch_ct19"], "c-a")}{column("Column B: the road east", ["ch_b15","ch_r16","ch_tp19"], "c-d")}</div>
<div class="stage">{mar}{anna}</div>
<div class="stage"><ol class="solo">{chrow("ch_rf20")}</ol></div>
<div class="bridge" data-layer="play">&darr; The Reunion hands the party into <b>Memory F2</b>, the last court of the Long Reign, before Act 3 begins.</div></section>"""

fork_note = ev("open", "Open", "Does the player walk both roads?", "Both the Enlightened One's road and the Hierophant's open after chapter 22. Canon gives four terminal states but does not say whether a run plays one road or both.", tags(("open", "needs a decision")), "gap")
act3 = f"""
<section class="act" id="act3"><header class="ah"><span class="an">Act 3</span><h3>What feeds the colossus</h3><p>The capital as a battlefield. Two false godheads are assembled from what was taken: one from money, one from certainty.</p></header>
<div class="stage"><ol class="solo">{chrow("ch_k21")}{chrow("ch_k22")}</ol></div>
<div class="stage">{fork_note}</div>
<div class="split">
<div class="col c-r"><h5>The Enlightened One (the Company of the Road)</h5><ol>{chrow("ch_e31", tags(("sys","hidden signals are read here"), ("open","signal set is yours to decide")))}</ol>
 <div class="fork"><div class="br good"><b>Sanctification</b><p>The honest ascension. The party fights the deposed patrons resisting absorption into one new claim. A true good god still ends the plurality.</p></div>
 <div class="br bad"><b>The Idol</b><p>The extracted ascension. The party fights him directly, and the shape converges with the Hierophant's colossus.</p></div></div>
 <p class="note">He is generous, at scale, on fair terms, and the deal is winnable. Taking it is the loss. His name, history and whether he believes it are still open.</p></div>
<div class="col c-h"><h5>The Hierophant (the March voices)</h5><ol>{chrow("ch_h31")}{chrow("ch_h32", tags(("sys","built: the docket and the commission"), ("open","the trial scene is unwritten")))}</ol>
 <div class="fork"><div class="br good"><b>Mercy: Subterfuge</b><p>The prophet reframes the capitulation as a hidden descent; the movement goes underground for a second, later battle.</p><ol>{chrow("ch_h33_mercy")}</ol></div>
 <div class="br bad"><b>Execution: the war</b><p>The trial performed impartiality and the outcome betrayed it. Costly maps against regions that were allied a chapter ago.</p><ol>{chrow("ch_h34_war1")}{chrow("ch_h34_war2")}{chrow("ch_h34_war3")}</ol></div></div></div>
</div></section>"""

# ------------------------------------------------------------------ Part III: open threads
OPEN = [
 ("The Venerated", "What did they do, and did they die?", "Five sects answer; none can be proven. Each answer needs a voice, a relic and a reason to be believed.", "eras, sects, calendar"),
 ("The withheld name", "What Nashar wrote", "Never shown, by design. What can be written is everyone who has argued about it since. Treat it as a constraint to write around, and the page lost in the scribes' quarter as the thing that made it possible.", "flashbacks"),
 ("Anna's payoff", "The decan token", "What it proves, who contests it, and how it reaches Act 3. Canon marks it a reconstruction gap and the calendar schism depends on it.", "guest_units, calendar"),
 ("The Enlightened One", "A name, a history, whether he believes it", "The only decision made is that his horror is generosity. Everything else is open.", "the_claimant"),
 ("The Hierophant", "Beyond Methodios", "The prophet is known; the person he speaks for is not.", "the_hierophant"),
 ("The ascension signals", "Which five things the game watches", "Dispersal against kills, the Unstained respected or steamrolled, Kest's restitution, how forge access was used, how Maren was handled. Candidates, not a locked list.", "ascension_signals"),
 ("Kest", "Restitution or one more extraction", "A prodigious thief raised in a guild, recruited by heist. How the decan-token thread resolves for her is a signal in the ending.", "units, ascension_signals"),
 ("The scripts", "Thirty-seven scenes, no words", "Every scene is drafted with a summary and a word count of zero. The scene screen is ready to show a script the moment one exists.", "scenes"),
 ("The war arc", "How many fronts, and where", "Canon says 'several'; three chapters were invented to hold the shape.", "chapters"),
 ("Looks", "What anyone looks like", "Canon records stats and roles, not appearances. A short note per character, even a line, would give the next art pass something to hold.", "units"),
]
open_html = "".join(
    f'<article class="ev gap" data-layer="open"><div class="when">{e(src)}</div><div class="what"><h4>{e(t)}: {e(s)}</h4><p>{e(b)}</p></div></article>'
    for t, s, b, src in OPEN)

# ------------------------------------------------------------------ page
CSS = r"""
:root{
  --paper:#e8ebe4; --desk:#dde1d8; --leaf:#f6f7f1; --leaf2:#eceee6; --ink:#16202b; --muted:#566370; --rule:#c5ccc1;
  --accent:#2a479a; --accent-soft:#dbe2f6; --gold:#94701f; --gold-soft:#efe5c8; --good:#2c7352; --good-soft:#d6ebde; --warn:#a1502a; --warn-soft:#f3dccf; --skin:#d9b391;
  --f-display:"Alegreya SC",Georgia,serif; --f-body:"Alegreya Sans",system-ui,sans-serif; --f-mono:"IBM Plex Mono",ui-monospace,monospace;
}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){
  --paper:#0e1319; --desk:#0a0e13; --leaf:#171f29; --leaf2:#131a22; --ink:#e7eae4; --muted:#9ba7b3; --rule:#2a3441;
  --accent:#8fa9f2; --accent-soft:#1f2b4d; --gold:#dcb75d; --gold-soft:#33291a; --good:#6cc49a; --good-soft:#16302a; --warn:#e29a72; --warn-soft:#3a251a; --skin:#c39a78; color-scheme:dark}}
:root[data-theme="dark"]{
  --paper:#0e1319; --desk:#0a0e13; --leaf:#171f29; --leaf2:#131a22; --ink:#e7eae4; --muted:#9ba7b3; --rule:#2a3441;
  --accent:#8fa9f2; --accent-soft:#1f2b4d; --gold:#dcb75d; --gold-soft:#33291a; --good:#6cc49a; --good-soft:#16302a; --warn:#e29a72; --warn-soft:#3a251a; --skin:#c39a78; color-scheme:dark}
*{box-sizing:border-box}
[hidden]{display:none!important}
body{background:var(--desk);color:var(--ink);font-family:var(--f-body);font-size:16px;line-height:1.45;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px));padding-block:14px 40px}
.wrap{max-width:1040px;margin-inline:auto;display:flex;flex-direction:column;gap:22px}
h1{font-family:var(--f-display);font-weight:500;font-size:clamp(1.7rem,5vw,2.5rem);letter-spacing:.02em;margin:0;line-height:1.08;text-wrap:balance}
h2{font-family:var(--f-display);font-weight:500;font-size:1.5rem;margin:0;letter-spacing:.03em}
h3{font-family:var(--f-display);font-weight:500;font-size:1.3rem;margin:0;letter-spacing:.03em;text-wrap:balance}
h4{margin:0;font-size:1.05rem;font-weight:700;text-wrap:balance}
h5{margin:0 0 6px;font-family:var(--f-mono);font-size:.74rem;font-weight:500;letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}
p{margin:0}
.sub{color:var(--muted);max-width:62ch;margin-top:6px}
.bar{position:sticky;top:env(safe-area-inset-top,0px);z-index:5;background:var(--desk);padding-block:8px;border-bottom:1px solid var(--rule);display:flex;flex-wrap:wrap;gap:8px 14px;align-items:center}
.bar::before{content:"";position:fixed;inset:0 0 auto;height:env(safe-area-inset-top,0px);background:var(--desk);z-index:10}
.chips{display:flex;flex-wrap:wrap;gap:6px}
.chip{font:500 .8rem var(--f-mono);border:1px solid var(--rule);background:var(--leaf);color:var(--ink);border-radius:999px;padding:5px 11px;cursor:pointer}
.chip[aria-pressed="true"]{background:var(--ink);color:var(--paper);border-color:var(--ink)}
.chip:focus-visible,.nav a:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.nav{display:flex;gap:12px;font:500 .8rem var(--f-mono)}
.nav a{color:var(--accent);text-decoration:none}
.part{display:flex;flex-direction:column;gap:14px}
.part>header{display:flex;flex-direction:column;gap:4px;border-bottom:2px solid var(--ink);padding-bottom:8px}
.part>header p{color:var(--muted);max-width:66ch}
.era{display:grid;grid-template-columns:minmax(0,15rem) minmax(0,1fr);gap:8px 18px;padding-block:14px;border-top:1px solid var(--rule)}
.eh .ew{font:500 .78rem var(--f-mono);color:var(--accent);margin-bottom:2px}
.eh p{color:var(--muted);font-size:.95rem;margin-top:6px}
.evs{display:flex;flex-direction:column;gap:10px;min-width:0}
.ev{display:grid;grid-template-columns:7.5rem minmax(0,1fr);gap:4px 14px;background:var(--leaf);border:1px solid var(--rule);border-left:4px solid var(--muted);border-radius:4px;padding:10px 12px}
.ev .when{font:500 .74rem var(--f-mono);color:var(--muted);padding-top:3px}
.ev .what{min-width:0;display:flex;flex-direction:column;gap:5px}
.ev.playable{border-left-color:var(--gold);background:var(--gold-soft)}
.ev.playable .when{color:var(--gold)}
.ev[data-layer="lore"]{border-left-color:var(--accent)}
.ev[data-layer="sys"]{border-left-color:var(--good)}
.ev.gap{border-left-color:var(--warn);border-style:dashed;border-left-style:solid;background:var(--warn-soft)}
.ev.defect{border-left-color:var(--warn)}
.ev.key{border-left-color:var(--good)}
.act{display:flex;flex-direction:column;gap:12px;padding-block:6px}
.ah{display:grid;grid-template-columns:auto 1fr;gap:2px 14px;align-items:baseline;border-top:1px solid var(--rule);padding-top:14px}
.ah .an{font:500 .8rem var(--f-mono);color:var(--accent);grid-row:1/3}
.ah p{color:var(--muted);max-width:66ch;grid-column:2}
.split{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}
.col{background:var(--leaf);border:1px solid var(--rule);border-radius:4px;padding:10px 12px;min-width:0}
.col.c-d{border-top:3px solid var(--accent)}.col.c-a{border-top:3px solid var(--gold)}.col.c-r{border-top:3px solid var(--good)}.col.c-h{border-top:3px solid var(--warn)}
ol{list-style:none;margin:0;padding:0;display:flex;flex-direction:column}
.ch{display:grid;grid-template-columns:2rem minmax(0,1fr);gap:8px;padding:7px 0;border-top:1px solid var(--rule)}
.col ol>.ch:first-child,.side ol>.ch:first-child,.solo>.ch:first-child{border-top:0}
.ch .no{font:500 .8rem var(--f-mono);color:var(--muted);padding-top:2px}
.ch b{display:block}
.ch small{display:block;color:var(--muted);font-size:.86rem}
.stage{display:flex;flex-direction:column;gap:10px}
.solo{background:var(--leaf);border:1px solid var(--rule);border-radius:4px;padding:6px 12px}
.side{background:var(--leaf2);border:1px solid var(--rule);border-radius:4px;padding:10px 12px;display:flex;flex-direction:column;gap:6px}
.note{color:var(--muted);font-size:.92rem;max-width:70ch}
.bridge{font:500 .85rem var(--f-mono);background:var(--gold-soft);color:var(--gold);border:1px dashed var(--gold);border-radius:4px;padding:8px 12px}
.bridge b{font-weight:700}
.fork{display:grid;gap:8px;margin-top:8px}
.br{border-radius:4px;padding:8px 10px;font-size:.93rem}
.br p{color:var(--muted)}
.br.good{background:var(--good-soft)}.br.bad{background:var(--warn-soft)}
.br ol{margin-top:4px}
.tag{display:inline-block;font:500 .7rem var(--f-mono);border-radius:3px;padding:2px 6px;margin:4px 6px 0 0;border:1px solid var(--rule);color:var(--muted)}
.t-sys{color:var(--good);border-color:var(--good)}.t-open{color:var(--warn);border-color:var(--warn)}.t-lore{color:var(--accent);border-color:var(--accent)}.t-main{color:var(--ink)}
.anna-w{flex-direction:row!important;gap:12px;align-items:flex-start}
.anna{flex:none;width:64px;height:72px;border-radius:4px;background:var(--leaf2)}
.aside{display:block;font-size:.85rem;color:var(--muted);font-style:italic;margin-top:4px}
.legend{display:flex;flex-wrap:wrap;gap:6px 14px;font-size:.88rem;color:var(--muted)}
.legend i{display:inline-block;width:12px;height:12px;border-radius:2px;margin-right:5px;vertical-align:-1px}
@media (max-width:760px){
  .era{grid-template-columns:minmax(0,1fr)}
  .split{grid-template-columns:minmax(0,1fr)}
  .ev{grid-template-columns:minmax(0,1fr)}
  .ev .when{padding-top:0}
}
@media (prefers-reduced-motion:no-preference){html{scroll-behavior:smooth}}
"""

JS = r"""
const layers={lore:true,play:true,main:true,sys:true,open:true};
function apply(){
  document.querySelectorAll('[data-layer]').forEach(function(el){
    if(el.classList.contains('chip'))return;
    el.hidden=!layers[el.getAttribute('data-layer')];
  });
  document.querySelectorAll('.era,.act').forEach(function(sec){
    var any=sec.querySelector('[data-layer]:not([hidden])');
    sec.style.display=any?'':'none';
  });
}
document.querySelectorAll('.chip').forEach(function(btn){
  btn.addEventListener('click',function(){
    var k=btn.getAttribute('data-k');layers[k]=!layers[k];
    btn.setAttribute('aria-pressed',layers[k]);apply();
  });
});
apply();
"""

PAGE = f"""<title>Chronicle of the Two Claims</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Alegreya+SC:wght@400;500;700&family=Alegreya+Sans:ital,wght@0,400;0,500;0,700;1,400&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>{CSS}</style>
<div class="wrap">
 <header><h1>Chronicle of the Two Claims</h1>
  <p class="sub">Eight hundred years of a record nobody can fully read, and the campaign that walks through the last forty. Built from the canon workbook; gold marks the three memories you play, green what the game already does, red what is still waiting to be written.</p></header>
 <div class="bar">
  <div class="chips" role="group" aria-label="Show or hide layers">
   <button class="chip" data-k="lore" aria-pressed="true">History</button><button class="chip" data-k="play" aria-pressed="true">Memories you play</button>
   <button class="chip" data-k="main" aria-pressed="true">Campaign</button><button class="chip" data-k="sys" aria-pressed="true">Built into the game</button>
   <button class="chip" data-k="open" aria-pressed="true">Waiting to be written</button></div>
  <nav class="nav" aria-label="Jump to"><a href="#record">I Record</a><a href="#campaign">II Campaign</a><a href="#threads">III Threads</a></nav>
 </div>
 <section class="part" id="record"><header><h2>I. The record</h2><p>Years are counted back from the year Act 1 opens. Spacing is by era, not to scale.</p></header>{part1}</section>
 <section class="part" id="campaign"><header><h2>II. The campaign</h2><p>Two roads that join at the Second Writ, split again by sect, and meet at the Reunion. Chapter numbers are canon's; the sequence follows each chapter's unlock.</p></header>{act1}{act2}{act3}</section>
 <section class="part" id="threads"><header><h2>III. Threads waiting for a writer</h2><p>Where canon stops and the story could begin. Each names the tab it comes from, so a decision lands in the workbook.</p></header><div class="evs">{open_html}</div></section>
</div>
<script>{JS}</script>
"""
out = ROOT / "flipbooks" / "timeline.html"
out.write_text(PAGE, encoding="utf-8")
print("wrote", out, len(PAGE))
