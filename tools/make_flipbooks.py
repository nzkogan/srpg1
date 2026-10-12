#!/usr/bin/env python3
"""Builds flipbooks/classes.html and flipbooks/weapons.html from the exported canon (game/data/*.json).

    python3 tools/make_flipbooks.py
Run after python3 export_canon_json.py whenever classes or weapons change.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from flipbook_data import build  # noqa: E402
from flipbook_assets import CSS, JS_ENGINE, JS_FIGURES, JS_WEAPONS  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "flipbooks"

PAGE = """<title>{title}</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Alegreya+SC:wght@400;500;700&family=Alegreya+Sans:wght@400;500;700&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>{css}</style>
<div class="wrap">
  <header class="top">
    <div><h1>{title}</h1><p class="sub">{sub}</p></div>
    <div class="tools"><input type="search" id="q" placeholder="Find by name" aria-label="Find by name"><button id="toc" aria-expanded="false" aria-controls="drawer">Contents</button></div>
  </header>
  <div class="chips" id="chips" role="group" aria-label="Filter"></div>
  <div class="drawer" id="drawer" hidden></div>
  <div class="stage"><article class="sheet" id="sheet"><section class="leaf left" id="left" aria-live="polite"></section><section class="leaf right" id="right"></section></article></div>
  <div class="pager"><button id="prev" aria-label="Previous page">&larr; Back</button><input type="range" id="range" min="0" max="0" value="0" aria-label="Page"><span class="count" id="count"></span><button id="next" aria-label="Next page">Next &rarr;</button></div>
  <p class="hint">Arrow keys turn the page. {hint}</p>
</div>
<script>
const DATA={data};
{engine}
{extra}
{script}
</script>
"""

CLASSES_JS = r"""
const TIERS=[["commoner","Commoner"],["trained","Trained"],["order","Order"],["hybrid","Hybrid"],["paragon","Paragon"],["personal","Personal"],["shadow","Shadow"]];
const TIERN=Object.fromEntries(TIERS);
const TIERBLURB={commoner:"Untrained",trained:"One art",order:"Certified",hybrid:"Certified, two arts",paragon:"Deed-gated",personal:"One bearer",shadow:"Off the matrix"};
const WT=["worn","basic","mid","high","legendary"];
function classLeft(c,n,total){
  const arts=c.arts.map(a=>'<span class="tag art" style="color:'+HUE[a]+'">'+esc(a)+'</span>').join("");
  return '<div class="plate">Plate '+n+' of '+total+'</div>'+figureSvg(c)+'<h2>'+esc(c.name)+'</h2>'+
    '<span class="tier">'+esc(TIERN[c.tier])+' · '+esc(TIERBLURB[c.tier])+'</span>'+
    '<div class="meta"><span class="tag">'+esc(c.movement)+' movement</span>'+(arts||'<span class="tag">no art</span>')+(c.art2raw==="authority"?'<span class="tag">authority</span>':'')+'</div>'+
    '<p class="hint">A generic rendering: build from movement type, weapon in hand from its art, trim from its tier.</p>';
}
function growthBlock(c){
  const g=c.growth, out=[];
  if(g.kind!=="none"){
    const rows=DATA.stats.map(s=>({l:STATN[s],v:g.net[s],show:(g.net[s]>0?"+":"")+g.net[s]}));
    const total=DATA.stats.reduce((a,s)=>a+g.net[s],0);
    out.push('<p class="small">On '+(g.kind==="paragon"?"taking the paragon tier":"certifying")+': a flat jump'+(Object.keys(g.shape).length?' plus the '+esc(c.movement)+' shape':'')+', '+(total>0?'+':'')+total+' stats in all.</p>'+bars(rows,8));
    out.push('<p class="small">From then on, every growth rate is '+g.bonus+' points higher'+(g.kind==="paragon"?' (5 from certifying, 5 from the paragon tier)':'')+'.</p>');
  } else {
    out.push('<p class="small">This class adds nothing of its own. A unit\'s growth rates come from its own profile, and the class matters once it certifies: +25 stats, +5 growth, the movement shape and an extra ability slot.</p>');
  }
  c.held.forEach(h=>{
    if(!Object.keys(h.rates).length) return;
    const bonus=g.bonus||0;
    const rows=DATA.stats.map(s=>({l:STATN[s],v:h.rates[s],bonus:bonus,show:(h.rates[s]+bonus)+"%"}));
    out.push('<p class="small"><b>'+esc(h.name)+'</b> rolls these per level (profile “'+esc(h.profile)+'”'+(bonus?', with the class bonus in gold':'')+'):</p>'+bars(rows,100));
  });
  return out.join("");
}
function weaponsBlock(c){
  if(!c.weapons.length) return '<p class="small">No art, so no weapon it can wield. It fights with what it can do on the map.</p>';
  const by={}; c.weapons.forEach(w=>{(by[w.tier]=by[w.tier]||[]).push(w);});
  const rows=WT.filter(t=>by[t]).map(t=>'<div class="wtier"><b>'+t+'</b>'+by[t].map(w=>'<span class="wchip'+(w.gated&&!c.promoted?' gate':'')+'" title="'+esc(w.art)+'">'+esc(w.name)+'</span>').join("")+'</div>').join("");
  const gate=!c.promoted&&c.weapons.some(w=>w.gated)?'<p class="small">Dashed weapons are high or legendary tier: the unit must be certified first.</p>':"";
  return '<div class="who">'+rows+'</div>'+gate;
}
function classRight(c){
  let h='<section class="blk"><h3>Requirements</h3><ul class="plain">'+c.requirements.map(r=>'<li>'+esc(r)+'</li>').join("")+'</ul>';
  if(c.unlock) h+='<p class="small">Unlocks at: '+chapterText(c.unlock.chapter)+'.</p>';
  h+='</section>';
  h+='<section class="blk"><h3>Weapon types</h3>'+weaponsBlock(c)+'</section>';
  h+='<section class="blk"><h3>Growth</h3>'+growthBlock(c)+'</section>';
  if(c.actions.length) h+='<section class="blk"><h3>Map actions</h3><div class="meta" style="justify-content:flex-start">'+c.actions.map(a=>'<span class="tag">'+esc(a)+'</span>').join("")+'</div></section>';
  if(c.held.length) h+='<section class="blk"><h3>Starts as this</h3><ul class="plain">'+c.held.map(u=>'<li>'+esc(u.name)+(u.join?', joining at '+chapterText(u.join):'')+'</li>').join("")+'</ul></section>';
  if(c.note) h+='<p class="note">'+esc(c.note)+'</p>';
  return h;
}
Flip({items:DATA.classes,title:"Class Flipbook",group:c=>c.tier,filters:[{id:"all",label:"All"}].concat(TIERS.map(t=>({id:t[0],label:t[1]}))),left:classLeft,right:classRight});
"""

WEAPONS_JS = r"""
const ARTL=[["sword","Sword"],["lance","Lance"],["axe","Axe"],["bow","Bow"],["brawl","Brawl"],["reason","Reason"],["faith","Faith"]];
const TIERBLURB={worn:"Scavenged",basic:"Iron",mid:"Steel",high:"Silver",legendary:"Named material"};
const MAX={might:16,hit:100,crit:12,weight:14,uses:50};
function wkey(w){return w.hybrid?"hybrid":w.art;}
function wLeft(w,n,total){
  const reqs=w.req.map(a=>'<span class="tag art" style="color:'+HUE[a]+'">'+esc(a)+'</span>').join("");
  return '<div class="plate">Plate '+n+' of '+total+'</div>'+weaponSvg(w)+'<h2>'+esc(w.name)+'</h2>'+
    '<span class="tier">'+esc(TIERBLURB[w.tier])+' · '+esc(w.tier)+(w.hybrid?' · overlap':'')+'</span>'+
    '<div class="meta">'+reqs+'<span class="tag">range '+(w.range[0]===w.range[1]?w.range[0]:w.range[0]+"–"+w.range[1])+'</span></div>'+
    '<p class="hint">A generic rendering: the shape comes from its art, the metal from its tier.</p>';
}
function wRight(w){
  const rows=[{l:"Might",v:w.might,show:w.might,max:MAX.might},{l:"Hit",v:w.hit,show:w.hit,max:MAX.hit},{l:"Crit",v:w.crit,show:w.crit,max:MAX.crit},
    {l:"Wt",v:w.weight,show:w.weight,max:MAX.weight},{l:"Uses",v:w.uses,show:w.uses,max:MAX.uses}];
  const statHtml=bars(rows,1);
  let h='';
  const f=w.first;
  h+='<section class="blk"><h3>First available</h3>';
  if(f){
    h+='<div class="callout"><span class="big">'+chapterText(f.chapter,f.kind)+'</span><span class="small">'+esc(f.text)+'.'+(w.firstTied.length?' Also at '+w.firstTied.map(c=>esc(c.title)).join(", ")+'.':'')+'</span></div>';
  } else {
    h+='<div class="callout"><span class="big">Not yet obtainable</span><span class="small">Canon names no source for it: nothing drops it, sells it or forges it.'+(w.seen?' Enemies carry it from '+esc(w.seen.title)+'.':'')+'</span></div>';
  }
  const rest=w.sources.filter(s=>s.kind!=="enemy"&&s!==f&&!(f&&s.text===f.text));
  const enemies=w.sources.filter(s=>s.kind==="enemy");
  if(rest.length||enemies.length||(w.seen&&f)) h+='<ul class="plain">'+rest.map(s=>'<li>'+esc(s.text)+', '+chapterText(s.chapter,s.kind)+'</li>').join("")+enemies.map(s=>'<li>'+esc(s.text)+' from '+chapterText(s.chapter)+' (seen, not yours to take)</li>').join("")+(w.seen&&f&&!enemies.length?'<li>Enemies first carry this tier at '+esc(w.seen.title)+'.</li>':"")+'</ul>';
  h+='</section>';
  h+='<section class="blk"><h3>Stats</h3>'+statHtml+'</section>';
  const names=w.wielders; const shown=names.slice(0,14).join(", ")+(names.length>14?" and "+(names.length-14)+" more":"");
  h+='<section class="blk"><h3>Requirements</h3><ul class="plain"><li>Proficiency in '+w.req.map(esc).join(" and ")+(w.hybrid?' (an overlap weapon: both).':'.')+'</li>'+
     (w.gated?'<li>The wielder must be certified: high and legendary tiers are closed to uncertified units.</li>':'<li>Open to any unit with the art, certified or not.</li>')+
     '<li>'+names.length+' of the classes can wield it'+(names.length?': '+esc(shown)+'.':'. No class has the pair yet.')+'</li></ul></section>';
  const sp=[];
  if(w.effective.length) sp.push('<li>Effective against '+w.effective.map(esc).join(", ")+' movement (double might).</li>');
  if(w.effect) sp.push('<li>'+({heal_allies:"Heals each ally beside the wielder on a hit.",unmake:"Wears the foe’s weapon one step down on a hit.",pull:"Drags a hit foe a tile toward the wielder."})[w.effect]+'</li>');
  if(sp.length) h+='<section class="blk"><h3>Special</h3><ul class="plain">'+sp.join("")+'</ul></section>';
  if(w.note) h+='<p class="note">'+esc(w.note)+'</p>';
  return h;
}
Flip({items:DATA.weapons,title:"Weapon Flipbook",group:wkey,filters:[{id:"all",label:"All"}].concat(ARTL.map(a=>({id:a[0],label:a[1]})),[{id:"hybrid",label:"Overlap"}]),left:wLeft,right:wRight});
"""


def render(name, title, sub, hint, data, extra, script):
    blob = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    html = PAGE.format(title=title, sub=sub, hint=hint, css=CSS, data=blob, engine=JS_ENGINE, extra=extra, script=script)
    (OUT / name).write_text(html)
    print(f"{name}: {len(html) // 1024} KB")


def main():
    OUT.mkdir(exist_ok=True)
    d = build()
    render("classes.html", "Class Flipbook",
           "Every class in canon: what it asks, what it can wield, how it grows.", "Contents jumps to any class.",
           {"classes": d["classes"], "stats": d["stats"]}, JS_FIGURES, CLASSES_JS)
    render("weapons.html", "Weapon Flipbook",
           "Every weapon in canon: its numbers, what it asks of the wielder, and the first chapter you can hold it.", "Contents jumps to any weapon.",
           {"weapons": d["weapons"]}, JS_WEAPONS, WEAPONS_JS)


if __name__ == "__main__":
    main()
