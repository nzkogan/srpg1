"""Shared CSS, JS engine and SVG drawing for the class and weapon flipbooks."""

CSS = r"""
/* Layout: a bound book on a desk. One spread at a time (figure leaf left, ledger leaf right); stacks to one leaf on a phone. */
:root{
  --paper:#e8ebe4; --desk:#dde1d8; --leaf:#f6f7f1; --leaf2:#eceee6; --ink:#16202b; --muted:#566370; --rule:#c5ccc1;
  --accent:#2a479a; --accent-soft:#dbe2f6; --gold:#94701f; --gold-soft:#efe5c8; --good:#2c7352; --warn:#a1502a;
  --h-sword:#4a6fa5; --h-lance:#3f8a6a; --h-axe:#b25a34; --h-bow:#a3822a; --h-brawl:#8a5a3c; --h-reason:#7a4fa0; --h-faith:#c1962f; --h-none:#7c8794;
  --skin:#d9b391; --m-worn:#8c8174; --m-iron:#6f7a86; --m-steel:#8da3b8; --m-silver:#c9d3dc; --shadowc:rgba(22,32,43,.18);
  --f-display:"Alegreya SC",Georgia,serif; --f-body:"Alegreya Sans",system-ui,sans-serif; --f-mono:"IBM Plex Mono",ui-monospace,monospace;
}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){
  --paper:#0e1319; --desk:#0a0e13; --leaf:#171f29; --leaf2:#131a22; --ink:#e7eae4; --muted:#9ba7b3; --rule:#2a3441;
  --accent:#8fa9f2; --accent-soft:#1f2b4d; --gold:#dcb75d; --gold-soft:#33291a; --good:#6cc49a; --warn:#e29a72;
  --h-sword:#7da2da; --h-lance:#6cc49a; --h-axe:#e08a62; --h-bow:#d6b44f; --h-brawl:#c08a68; --h-reason:#b58bdc; --h-faith:#e6bf55; --h-none:#8f9ba8;
  --skin:#c39a78; --m-worn:#7b7064; --m-iron:#8c97a3; --m-steel:#a9bdd0; --m-silver:#dbe3ea; --shadowc:rgba(0,0,0,.45); color-scheme:dark}}
:root[data-theme="dark"]{
  --paper:#0e1319; --desk:#0a0e13; --leaf:#171f29; --leaf2:#131a22; --ink:#e7eae4; --muted:#9ba7b3; --rule:#2a3441;
  --accent:#8fa9f2; --accent-soft:#1f2b4d; --gold:#dcb75d; --gold-soft:#33291a; --good:#6cc49a; --warn:#e29a72;
  --h-sword:#7da2da; --h-lance:#6cc49a; --h-axe:#e08a62; --h-bow:#d6b44f; --h-brawl:#c08a68; --h-reason:#b58bdc; --h-faith:#e6bf55; --h-none:#8f9ba8;
  --skin:#c39a78; --m-worn:#7b7064; --m-iron:#8c97a3; --m-steel:#a9bdd0; --m-silver:#dbe3ea; --shadowc:rgba(0,0,0,.45); color-scheme:dark}
*{box-sizing:border-box}
[hidden]{display:none!important}
body{background:var(--desk);color:var(--ink);font-family:var(--f-body);font-size:16px;line-height:1.45;padding-inline:16px;padding-block:14px 22px}
.wrap{max-width:1080px;margin-inline:auto;display:flex;flex-direction:column;gap:12px}
header.top{display:flex;flex-wrap:wrap;align-items:end;justify-content:space-between;gap:10px 18px}
h1{font-family:var(--f-display);font-weight:500;font-size:clamp(1.5rem,4vw,2.1rem);letter-spacing:.02em;margin:0;line-height:1.1;text-wrap:balance}
.sub{color:var(--muted);font-size:.95rem;margin:2px 0 0}
.tools{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
input[type=search]{font:inherit;color:var(--ink);background:var(--leaf);border:1px solid var(--rule);border-radius:6px;padding:7px 10px;min-width:0;width:11.5rem}
button{font:inherit;color:var(--ink);background:var(--leaf);border:1px solid var(--rule);border-radius:6px;padding:7px 12px;cursor:pointer}
button:hover{border-color:var(--accent)}
:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.chips{display:flex;gap:6px;flex-wrap:wrap}
.chip{font-size:.86rem;padding:4px 10px;border-radius:999px;border:1px solid var(--rule);background:var(--leaf);cursor:pointer;display:inline-flex;gap:6px;align-items:center}
.chip[aria-pressed=true]{background:var(--accent);border-color:var(--accent);color:var(--leaf)}
.chip .n{font-family:var(--f-mono);font-size:.78rem;opacity:.8}
.stage{perspective:1800px}
.sheet{display:grid;grid-template-columns:1fr 1fr;background:var(--leaf);border:1px solid var(--rule);border-radius:4px;box-shadow:0 1px 0 var(--rule),0 3px 0 -1px var(--leaf2),0 4px 0 -1px var(--rule),0 6px 0 -2px var(--leaf2),0 7px 0 -2px var(--rule),0 18px 30px -12px var(--shadowc);transform-origin:left center;min-height:560px;position:relative}
.sheet::after{content:"";position:absolute;inset:0 calc(50% - 22px) 0 auto;width:44px;left:calc(50% - 22px);background:linear-gradient(90deg,transparent,var(--shadowc),transparent);opacity:.35;pointer-events:none}
.leaf{padding:26px 28px;min-width:0;display:flex;flex-direction:column;gap:14px}
.leaf.left{align-items:center;text-align:center;justify-content:flex-start;gap:8px}
.plate{font-family:var(--f-mono);font-size:.74rem;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
.leaf h2{font-family:var(--f-display);font-weight:500;font-size:clamp(1.7rem,4.2vw,2.5rem);margin:0;line-height:1.05;letter-spacing:.015em;text-wrap:balance}
.fig{width:100%;max-width:340px;height:auto;aspect-ratio:5/6;flex:none}
.fig.wide{aspect-ratio:2/1;max-width:420px}
.tier{font-family:var(--f-mono);font-size:.72rem;letter-spacing:.1em;text-transform:uppercase;padding:3px 9px;border-radius:3px;border:1px solid var(--gold);color:var(--gold);background:var(--gold-soft);display:inline-block}
.meta{display:flex;gap:6px;flex-wrap:wrap;justify-content:center}
.tag{font-size:.85rem;padding:2px 9px;border-radius:999px;background:var(--leaf2);border:1px solid var(--rule);white-space:nowrap}
.tag.art{border-color:currentColor;background:transparent;font-weight:600}
section.blk{display:flex;flex-direction:column;gap:6px;min-width:0}
h3{font-family:var(--f-display);font-weight:500;font-size:1.08rem;letter-spacing:.06em;margin:0;color:var(--accent);border-bottom:1px solid var(--rule);padding-bottom:3px}
ul.plain{margin:0;padding-left:1.1em;display:flex;flex-direction:column;gap:3px}
.bars{display:grid;grid-template-columns:3.2rem 1fr 3.4rem;gap:4px 10px;align-items:center;font-size:.9rem}
.bars .l{font-family:var(--f-mono);font-size:.78rem;text-transform:uppercase;color:var(--muted)}
.bars .v{font-family:var(--f-mono);font-size:.85rem;text-align:right;font-variant-numeric:tabular-nums}
.track{height:9px;background:var(--leaf2);border-radius:2px;overflow:hidden;display:flex;border:1px solid var(--rule)}
.track i{display:block;height:100%;background:var(--accent)}
.track i.b{background:var(--gold)}
.track i.neg{background:var(--warn)}
.who{font-size:.92rem;display:flex;flex-direction:column;gap:6px}
.wtier{display:flex;gap:6px;flex-wrap:wrap;align-items:baseline}
.wtier b{font-family:var(--f-mono);font-size:.72rem;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);width:5.3rem;flex:none}
.wchip{font-size:.85rem;padding:1px 8px;border:1px solid var(--rule);border-radius:4px;background:var(--leaf2)}
.wchip.gate{border-style:dashed}
.callout{border:1px solid var(--gold);background:var(--gold-soft);border-radius:4px;padding:10px 12px;display:flex;flex-direction:column;gap:2px}
.callout .big{font-family:var(--f-display);font-size:1.35rem;line-height:1.15}
.callout .small{color:var(--muted);font-size:.9rem}
.note{color:var(--muted);font-size:.9rem;font-style:italic}
.kv{display:grid;grid-template-columns:auto 1fr;gap:3px 12px;font-size:.93rem}
.kv dt{color:var(--muted)} .kv dd{margin:0}
.pager{display:flex;align-items:center;gap:12px}
.pager .count{font-family:var(--f-mono);font-size:.85rem;min-width:6.5rem;text-align:center;font-variant-numeric:tabular-nums}
.pager input[type=range]{flex:1;min-width:0;accent-color:var(--accent)}
.drawer{background:var(--leaf);border:1px solid var(--rule);border-radius:6px;padding:12px 14px;display:flex;flex-direction:column;gap:10px;max-height:60vh;overflow:auto}
.drawer h4{font-family:var(--f-display);font-weight:500;margin:0;font-size:1rem;color:var(--accent);letter-spacing:.05em}
.drawer .row{display:flex;gap:6px;flex-wrap:wrap}
.drawer button{font-size:.88rem;padding:3px 9px}
.drawer button[aria-current=true]{background:var(--accent);color:var(--leaf);border-color:var(--accent)}
.hint{color:var(--muted);font-size:.82rem}
svg text{font-family:var(--f-mono)}
.fig .ink{stroke:var(--ink);stroke-width:1.6;stroke-linejoin:round;stroke-linecap:round}
.fig .shadow{fill:var(--shadowc)}
@media (max-width:760px){
  .pager{flex-wrap:wrap}
  .pager input[type=range]{order:5;flex-basis:100%}
  .pager .count{flex:1}
  .sheet{grid-template-columns:1fr;min-height:0}
  .sheet::after{display:none}
  .leaf{padding:20px 16px}
  .leaf.left{border-bottom:1px dashed var(--rule)}
  input[type=search]{width:100%}
  .tools{width:100%}
}
@media (prefers-reduced-motion: reduce){.sheet{transition:none}}
"""

JS_ENGINE = r"""
const $=s=>document.querySelector(s);
const esc=s=>String(s??"").replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const HUE={sword:"var(--h-sword)",lance:"var(--h-lance)",axe:"var(--h-axe)",bow:"var(--h-bow)",brawl:"var(--h-brawl)",reason:"var(--h-reason)",faith:"var(--h-faith)",none:"var(--h-none)"};
const STATN={hp:"HP",str:"STR",mag:"MAG",dex:"DEX",spd:"SPD",lck:"LCK",def:"DEF",res:"RES"};
function chapterText(c,kind){
  if(!c) return "—";
  if(kind==="convoy") return "From the start of Act 1, on either route";
  const where=[c.label, c.route && c.route+(c.column?" column "+c.column:"") || (c.column?"Column "+c.column:"")].filter(Boolean).join(", ");
  return esc(c.title)+" ("+esc(where)+")";
}
function bars(rows,max,opts){
  opts=opts||{};
  return '<div class="bars">'+rows.map(r=>{
    const m=r.max||max, w=Math.max(0,Math.min(100,100*Math.abs(r.v)/m)), b=r.bonus?Math.min(100-w,100*r.bonus/m):0;
    return '<span class="l">'+esc(r.l)+'</span><span class="track" role="img" aria-label="'+esc(r.l+" "+r.show)+'"><i class="'+(r.v<0?"neg":"")+'" style="width:'+w+'%"></i>'+(b?'<i class="b" style="width:'+b+'%"></i>':"")+'</span><span class="v">'+esc(r.show)+'</span>';
  }).join("")+'</div>';
}
function Flip(cfg){
  const items=cfg.items; let filter="all", query="", cur=0, busy=false;
  const sheet=$("#sheet"), left=$("#left"), right=$("#right"), count=$("#count"), range=$("#range");
  const reduce=matchMedia("(prefers-reduced-motion: reduce)").matches;
  const visible=()=>items.filter(it=>(filter==="all"||cfg.group(it)===filter)&&(!query||it.name.toLowerCase().includes(query)));
  let list=visible();
  function paint(){
    const it=list[cur]; if(!it){left.innerHTML='<p class="note">Nothing matches.</p>';right.innerHTML="";count.textContent="0 / 0";return;}
    left.innerHTML=cfg.left(it,items.indexOf(it)+1,items.length); right.innerHTML=cfg.right(it);
    count.textContent=(cur+1)+" / "+list.length; range.max=Math.max(0,list.length-1); range.value=cur;
    document.title=cfg.title; try{history.replaceState(null,"","#"+it.id)}catch(e){}
    document.querySelectorAll("#drawer button").forEach(b=>b.setAttribute("aria-current",b.dataset.id===it.id));
  }
  function go(n,instant){
    if(!list.length||busy) return; n=Math.max(0,Math.min(list.length-1,n)); if(n===cur&&!instant) return;
    const dir=n>cur?1:-1;
    if(reduce||instant||!sheet.animate){cur=n;paint();return;}
    busy=true;
    sheet.animate([{transform:"rotateY(0deg)",opacity:1},{transform:"rotateY("+(-dir*62)+"deg)",opacity:.15}],{duration:170,easing:"ease-in",fill:"forwards"}).finished.then(()=>{
      cur=n;paint();
      return sheet.animate([{transform:"rotateY("+(dir*62)+"deg)",opacity:.15},{transform:"rotateY(0deg)",opacity:1}],{duration:200,easing:"ease-out",fill:"forwards"}).finished;
    }).then(()=>{sheet.getAnimations().forEach(a=>a.cancel());busy=false;}).catch(()=>{busy=false;});
  }
  function refresh(keepId){
    const id=keepId||(list[cur]&&list[cur].id); list=visible(); const i=list.findIndex(x=>x.id===id); cur=i>=0?i:0; paint();
  }
  $("#prev").onclick=()=>go(cur-1); $("#next").onclick=()=>go(cur+1);
  range.oninput=()=>go(+range.value);
  addEventListener("keydown",e=>{
    if(e.target.matches("input[type=search]")) return;
    if(e.key==="ArrowRight"||e.key==="PageDown") go(cur+1); else if(e.key==="ArrowLeft"||e.key==="PageUp") go(cur-1);
    else if(e.key==="Home") go(0); else if(e.key==="End") go(list.length-1);
  });
  $("#q").oninput=e=>{query=e.target.value.trim().toLowerCase();refresh();};
  const chips=$("#chips");
  chips.innerHTML=cfg.filters.map(f=>'<button class="chip" data-f="'+f.id+'" aria-pressed="'+(f.id==="all")+'">'+esc(f.label)+' <span class="n">'+(f.id==="all"?items.length:items.filter(i=>cfg.group(i)===f.id).length)+'</span></button>').join("");
  chips.onclick=e=>{const b=e.target.closest("button"); if(!b) return; filter=b.dataset.f; chips.querySelectorAll("button").forEach(x=>x.setAttribute("aria-pressed",x===b)); refresh();};
  const dr=$("#drawer");
  dr.innerHTML=cfg.filters.filter(f=>f.id!=="all").map(f=>'<div><h4>'+esc(f.label)+'</h4><div class="row">'+items.filter(i=>cfg.group(i)===f.id).map(i=>'<button data-id="'+i.id+'">'+esc(i.name)+'</button>').join("")+'</div></div>').join("");
  dr.onclick=e=>{const b=e.target.closest("button"); if(!b) return; filter="all"; query=""; $("#q").value=""; chips.querySelectorAll("button").forEach(x=>x.setAttribute("aria-pressed",x.dataset.f==="all")); list=visible(); const i=list.findIndex(x=>x.id===b.dataset.id); go(i,true);};
  $("#toc").onclick=()=>{dr.hidden=!dr.hidden; $("#toc").setAttribute("aria-expanded",!dr.hidden);};
  const start=(location.hash||"").slice(1); const si=list.findIndex(x=>x.id===start); cur=si>=0?si:0; paint();
}
"""

# --------------------------------------------------------------------------- drawing
JS_FIGURES = r"""
function propSvg(art,x,y,s,extra){
  const H=HUE[art]||HUE.none; let d="";
  const steel='fill="var(--m-steel)" class="ink"';
  if(art==="sword") d='<path d="M-3 0 L-3 -64 L0 -76 L3 -64 L3 0Z" '+steel+'/><rect x="-11" y="-3" width="22" height="5" rx="1" fill="'+H+'" class="ink"/><rect x="-2.2" y="2" width="4.4" height="13" fill="'+H+'" class="ink"/>';
  else if(art==="lance") d='<path d="M0 44 L0 -100" class="ink" fill="none" stroke-width="3.4"/><path d="M0 -118 L7 -96 L-7 -96Z" '+steel+'/><path d="M0 -94 L18 -89 L0 -82Z" fill="'+H+'" class="ink"/>';
  else if(art==="axe") d='<path d="M0 34 L0 -72" class="ink" fill="none" stroke-width="4"/><path d="M0 -74 Q24 -76 24 -52 Q24 -38 0 -34 Q9 -54 0 -74Z" '+steel+'/>';
  else if(art==="bow") d='<path d="M2 -66 Q40 0 2 66" class="ink" fill="none" stroke-width="3.6" stroke="'+H+'"/><path d="M2 -66 L2 66" fill="none" stroke="var(--ink)" stroke-width="1"/>';
  else if(art==="brawl") d='<rect x="-10" y="-12" width="20" height="17" rx="5" fill="'+H+'" class="ink"/><path d="M-6 -12 L-6 -4 M0 -12 L0 -4 M6 -12 L6 -4" class="ink" fill="none" stroke-width="1.1"/>';
  else if(art==="reason") d='<rect x="-15" y="-26" width="30" height="26" rx="2" fill="'+H+'" class="ink"/><path d="M-9 -26 L-9 0" class="ink" fill="none" stroke-width="1.2"/><path d="M4 -17 l2 4 4 .5 -3 3 .8 4 -3.8-2 -3.8 2 .8-4 -3-3 4-.5z" fill="var(--leaf)" stroke="none"/>';
  else if(art==="faith") d='<path d="M0 0 L0 -26" class="ink" fill="none" stroke-width="1.5"/><circle cx="0" cy="-36" r="10" fill="'+H+'" class="ink"/><path d="M-5 -36 h10 M0 -41 v10" class="ink" fill="none" stroke-width="1"/><path d="M0 -50 q-7 -8 0 -15 q7 -8 0 -16" fill="none" stroke="var(--muted)" stroke-width="1.6" stroke-linecap="round"/>';
  else if(art==="authority") d='<rect x="-18" y="-10" width="36" height="12" rx="6" fill="var(--leaf)" class="ink"/><path d="M-12 -4 h24" class="ink" fill="none" stroke-width="1"/>';
  else d='<path d="M0 36 L0 -58" class="ink" fill="none" stroke-width="3" stroke="var(--m-worn)"/>';
  return '<g transform="translate('+x+' '+y+') scale('+s+')">'+d+'</g>';
}
function figureSvg(c){
  const mv=c.movement, tier=c.tier, arts=c.arts||[], a1=arts[0]||null, a2=arts[1]||null;
  const raw2=c.art2raw, H=a1?HUE[a1]:HUE.none;
  const body='color-mix(in oklab, '+H+' 58%, var(--leaf))';
  const trim='var(--gold)';
  let s='<svg class="fig" viewBox="0 0 200 240" role="img" aria-label="'+esc(c.name)+', a '+esc(mv)+' figure">';
  const rider=mv==="riding", fly=mv==="flying", arm=mv==="armor";
  const lift=fly?-20:0;
  s+='<ellipse class="shadow" cx="100" cy="'+(fly?224:216)+'" rx="'+(rider?66:fly?30:44)+'" ry="'+(fly?4:6)+'"/>';
  s+='<g transform="translate(0 '+lift+')">';
  if(fly){
    s+='<path d="M92 112 Q26 56 6 124 Q42 104 66 150Z" fill="'+body+'" class="ink"/><path d="M108 112 Q174 56 194 124 Q158 104 134 150Z" fill="'+body+'" class="ink"/>';
    s+='<path d="M30 96 Q40 112 54 126 M170 96 Q160 112 146 126" fill="none" class="ink" stroke-width="1"/>';
  }
  if(tier==="order"||tier==="paragon"||tier==="hybrid"||tier==="shadow") s+='<path d="M80 92 Q54 150 60 206 L96 176Z" fill="color-mix(in oklab, '+(tier==="shadow"?'var(--ink)':'var(--accent)')+' 62%, var(--leaf))" class="ink"/>';
  if(rider){
    s+='<g class="ink" fill="color-mix(in oklab, var(--m-worn) 70%, var(--leaf))"><ellipse cx="96" cy="172" rx="52" ry="23"/><path d="M134 160 L154 118 L170 124 L156 172Z"/><path d="M154 118 L186 134 L178 150 L158 140Z"/><path d="M46 164 Q22 176 30 206 Q40 186 50 180Z"/></g>';
    s+='<path d="M60 190 L58 214 M80 192 L80 214 M112 192 L114 214 M132 188 L136 214" class="ink" fill="none" stroke-width="6"/>';
    s+='<path d="M84 150 L72 184 M104 150 L116 182" class="ink" fill="none" stroke-width="7" stroke="var(--ink)"/>';
  } else {
    s+='<path d="M91 152 L88 '+(fly?196:208)+' M109 152 L112 '+(fly?196:208)+'" class="ink" fill="none" stroke-width="'+(arm?11:8)+'"/>';
  }
  const ty=rider?-10:0;
  s+='<g transform="translate(0 '+ty+')">';
  if(arm) s+='<path d="M72 92 Q100 82 128 92 L134 156 L66 156Z" fill="'+body+'" class="ink"/><circle cx="70" cy="98" r="13" fill="color-mix(in oklab, '+H+' 40%, var(--m-iron))" class="ink"/><circle cx="130" cy="98" r="13" fill="color-mix(in oklab, '+H+' 40%, var(--m-iron))" class="ink"/>';
  else s+='<path d="M84 92 Q100 85 116 92 L121 154 L79 154Z" fill="'+body+'" class="ink"/>';
  if(tier==="trained") s+='<path d="M84 94 L118 152" class="ink" fill="none" stroke="'+trim+'" stroke-width="4"/>';
  if(tier==="commoner") s+='<path d="M92 128 h16 v12 h-16z" fill="var(--leaf)" class="ink"/>';
  if(tier==="order"||tier==="paragon") s+='<circle cx="116" cy="100" r="4.5" fill="'+trim+'" class="ink"/>';
  if(tier==="hybrid"){ s+='<circle cx="94" cy="100" r="4.5" fill="'+HUE[arts[0]||"none"]+'" class="ink"/><circle cx="106" cy="100" r="4.5" fill="'+HUE[arts[1]||arts[0]||"none"]+'" class="ink"/>'; }
  if(tier==="personal") s+='<circle cx="100" cy="124" r="8" fill="none" stroke="'+trim+'" stroke-width="2"/><path d="M100 116 L103 124 L100 132 L97 124Z" fill="'+trim+'"/>';
  s+='<path d="M'+(arm?70:84)+' 98 L72 130" class="ink" fill="none" stroke-width="7"/><path d="M'+(arm?130:116)+' 98 L128 118" class="ink" fill="none" stroke-width="7"/>';
  // head
  if(tier==="shadow") s+='<circle cx="100" cy="72" r="13" fill="var(--ink)" class="ink"/><path d="M84 78 Q100 38 116 78 Q100 64 84 78Z" fill="var(--ink)" class="ink"/>';
  else if(arm) s+='<circle cx="100" cy="72" r="14" fill="var(--m-iron)" class="ink"/><rect x="90" y="68" width="20" height="5" fill="var(--ink)"/>';
  else s+='<circle cx="100" cy="72" r="13" fill="var(--skin)" class="ink"/><path d="M87 70 Q100 52 113 70 Q100 62 87 70Z" fill="color-mix(in oklab, var(--ink) 80%, var(--leaf))"/>';
  if(tier==="paragon") s+='<circle cx="100" cy="68" r="27" fill="none" stroke="'+trim+'" stroke-width="2.6"/><path d="M100 30 l3 7 7 .8 -5.4 4.6 1.8 7 -6.4 -3.8 -6.4 3.8 1.8 -7 -5.4 -4.6 7 -.8z" fill="'+trim+'" class="ink" stroke-width="1"/>';
  s+='</g>';
  // weapons
  const hx=rider?132:arm?134:130, hy=rider?112:arm?116:118;
  if(a1==="bow") s+=propSvg("bow",hx+6,hy,1,0);
  else if(a1==="brawl"){ s+=propSvg("brawl",hx,hy,1); s+=propSvg("brawl",rider?66:arm?66:72,rider?128:130,1); }
  else if(a1) s+=propSvg(a1,hx,hy,1);
  else if(raw2==="authority") s+=propSvg("authority",hx,hy,1);
  else s+=propSvg("none",hx,hy+6,1);
  if(a2 && a1!=="brawl") s+=propSvg(a2,rider?64:70,rider?124:130,.72);
  else if(raw2==="authority" && a1) s+=propSvg("authority",64,134,.8);
  s+='</g></svg>';
  return s;
}
"""

JS_WEAPONS = r"""
function weaponSvg(w){
  const A=w.art, T=w.tier, id=w.id;
  const mat={worn:"var(--m-worn)",basic:"var(--m-iron)",mid:"var(--m-steel)",high:"var(--m-silver)",legendary:"var(--m-silver)"}[T];
  const H=HUE[A]||HUE.none, G="var(--gold)";
  const ink='class="ink"';
  let d="", glow="", nicks="";
  if(T==="worn") nicks='<path d="M120 74 l5 4 -5 3 M176 86 l-5 -4 5 -3" fill="none" stroke="var(--ink)" stroke-width="1.4"/>';
  if(id==="wpn_feather_blade") d='<rect x="20" y="75" width="40" height="10" rx="3" fill="'+H+'" '+ink+'/><circle cx="16" cy="80" r="8" fill="'+G+'" '+ink+'/><rect x="60" y="62" width="9" height="36" rx="2" fill="'+G+'" '+ink+'/><path d="M69 80 Q150 40 292 80 Q150 120 69 80Z" fill="color-mix(in oklab, var(--h-lance) 50%, var(--m-silver))" '+ink+'/><path d="M80 80 L282 80" stroke="var(--ink)" stroke-width="1.2"/><path d="M110 70 l-10 -14 M140 64 l-8 -16 M170 62 l-6 -16 M110 90 l-10 14 M140 96 l-8 16 M170 98 l-6 16" stroke="'+G+'" stroke-width="2" stroke-linecap="round"/>';
  else if(id==="wpn_anzu_edge") d='<rect x="20" y="75" width="40" height="10" rx="3" fill="'+H+'" '+ink+'/><circle cx="16" cy="80" r="8" fill="'+G+'" '+ink+'/><rect x="60" y="62" width="9" height="36" rx="2" fill="'+G+'" '+ink+'/><path d="M69 74 L120 74 L136 62 L150 74 L176 72 L192 60 L206 73 L240 72 L296 80 L240 88 L69 86Z" fill="var(--m-silver)" '+ink+'/><path d="M80 80 L280 80" stroke="var(--ink)" stroke-width="1.2" stroke-dasharray="14 5"/>';
  else if(id==="wpn_karkadann_lance") d='<rect x="14" y="77" width="206" height="7" rx="2" fill="'+H+'" '+ink+'/><circle cx="12" cy="80" r="6" fill="'+G+'" '+ink+'/><path d="M214 66 L304 80 L214 94 Q226 80 214 66Z" fill="var(--m-silver)" '+ink+'/><path d="M226 72 Q250 66 262 76 M226 80 Q256 74 276 80 M226 88 Q252 90 270 84" fill="none" stroke="'+G+'" stroke-width="1.8"/><path d="M200 80 L170 56 L170 104Z" fill="'+H+'" '+ink+'/>';
  else if(id==="wpn_shadhavar_bow") d='<path d="M130 8 Q262 80 130 152 Q238 80 130 8Z" fill="color-mix(in oklab, var(--m-silver) 80%, var(--h-bow))" '+ink+'/><circle cx="196" cy="48" r="3.5" fill="var(--ink)"/><circle cx="214" cy="80" r="3.5" fill="var(--ink)"/><circle cx="196" cy="112" r="3.5" fill="var(--ink)"/><path d="M130 8 L130 152" stroke="var(--ink)" stroke-width="1.2"/><path d="M92 52 q-14 28 0 56 M70 40 q-22 40 0 80" fill="none" stroke="'+G+'" stroke-width="1.8" stroke-linecap="round"/>';
  else if(id==="wpn_marko_claymore") d='<rect x="10" y="74" width="62" height="12" rx="3" fill="'+H+'" '+ink+'/><circle cx="8" cy="80" r="9" fill="'+G+'" '+ink+'/><path d="M72 52 Q62 60 66 66 L84 66 L84 94 L66 94 Q62 100 72 108 L92 96 L92 64Z" fill="'+G+'" '+ink+'/><path d="M92 68 L262 68 L304 80 L262 92 L92 92Z" fill="var(--m-silver)" '+ink+'/><path d="M100 80 L268 80" stroke="var(--ink)" stroke-width="2" opacity=".6"/><path d="M104 72 L252 72 M104 88 L252 88" stroke="var(--ink)" stroke-width="1" opacity=".35"/>';
  else if(id==="wpn_stgeorge_spear") d='<rect x="10" y="77" width="236" height="7" rx="2" fill="'+H+'" '+ink+'/><circle cx="8" cy="80" r="7" fill="'+G+'" '+ink+'/><path d="M246 80 L212 52 L224 80 L212 108Z" fill="'+G+'" '+ink+'/><path d="M246 66 L306 80 L246 94 Q258 80 246 66Z" fill="var(--m-silver)" '+ink+'/><path d="M236 80 L196 62 L196 98Z" fill="var(--warn)" '+ink+'/><path d="M262 76 L290 80 L262 84" fill="none" stroke="var(--ink)" stroke-width="1.2"/>';
  else if(id==="wpn_svarog_cleaver") d='<rect x="14" y="76" width="200" height="9" rx="3" fill="'+H+'" '+ink+'/><circle cx="12" cy="80" r="7" fill="'+G+'" '+ink+'/><path d="M196 80 L196 22 L286 22 L286 138 L196 138Z" fill="var(--m-silver)" '+ink+'/><path d="M196 22 L170 12 L196 40Z M196 138 L170 148 L196 120Z" fill="var(--m-iron)" '+ink+'/>'+[[212,40],[212,120],[212,80]].map(c=>'<circle cx="'+c[0]+'" cy="'+c[1]+'" r="4" fill="'+G+'" '+ink+'/>').join("")+'<path d="M230 36 L280 80 L230 124" fill="none" stroke="var(--ink)" stroke-width="1.4" opacity=".5"/>';
  else if(id==="wpn_rostam_bow") d='<path d="M126 6 Q262 80 126 154" fill="none" stroke="color-mix(in oklab, var(--h-bow) 60%, var(--m-worn))" stroke-width="9" stroke-linecap="round" '+ink+'/><path d="M126 6 L126 154" stroke="var(--ink)" stroke-width="1.3"/><path d="M50 80 L236 80 M236 80 l-11 -6 M236 80 l-11 6" stroke="var(--ink)" stroke-width="1.8" fill="none"/>'+[[170,34],[212,56],[212,104],[170,126]].map(c=>'<g transform="translate('+c[0]+' '+c[1]+') rotate(-30)"><path d="M0 0 q10 -8 20 0 q-10 8 -20 0z" fill="var(--good)" '+ink+'/></g>').join("")+'<path d="M54 76 l12 -5 M54 80 l12 -5 M54 84 l12 -5" stroke="'+G+'" stroke-width="2"/>';
  else if(id==="wpn_svyatogor_grip") d='<rect x="40" y="38" width="64" height="84" rx="8" fill="var(--m-iron)" '+ink+'/><rect x="96" y="30" width="136" height="100" rx="24" fill="color-mix(in oklab, var(--m-iron) 70%, var(--h-brawl))" '+ink+'/><path d="M148 30 v100 M186 30 v100 M222 44 v72" stroke="var(--ink)" stroke-width="1.6" opacity=".6"/><path d="M110 130 Q88 164 132 154" fill="var(--m-iron)" '+ink+'/>'+[148,172,198].map(x=>'<circle cx="'+x+'" cy="48" r="6" fill="'+G+'" '+ink+'/>').join("")+'<path d="M64 60 l10 12 -8 10 12 14" fill="none" stroke="var(--ink)" stroke-width="1.6"/>';
  else if(id==="wpn_slavonic_enoch") d='<rect x="80" y="18" width="160" height="124" rx="7" fill="color-mix(in oklab, '+H+' 45%, var(--ink))" '+ink+'/><rect x="92" y="30" width="136" height="100" rx="3" fill="none" stroke="'+G+'" stroke-width="2.6"/><path d="M80 18 v124" stroke="var(--ink)" stroke-width="2.4"/><circle cx="160" cy="80" r="30" fill="none" stroke="'+G+'" stroke-width="2.4"/>'+[0,1,2,3,4,5,6].map(i=>'<path d="M'+(160+30*Math.cos(i*Math.PI*2/7-Math.PI/2))+' '+(80+30*Math.sin(i*Math.PI*2/7-Math.PI/2))+' l0 0" stroke="'+G+'" stroke-width="7" stroke-linecap="round"/>').join("")+'<path d="M160 62 l4 12 12 1 -10 8 4 12 -10 -7 -10 7 4 -12 -10 -8 12 -1z" fill="'+G+'"/>';
  else if(id==="wpn_perun_brand") d='<rect x="20" y="75" width="40" height="10" rx="3" fill="'+H+'" '+ink+'/><circle cx="16" cy="80" r="8" fill="'+G+'" '+ink+'/><rect x="60" y="62" width="9" height="36" rx="2" fill="'+G+'" '+ink+'/><path d="M69 73 L130 73 L146 66 L160 74 L186 72 L200 62 L214 73 L252 72 L292 80 L252 88 L214 87 L200 100 L186 88 L160 90 L146 96 L130 87 L69 87Z" fill="color-mix(in oklab, var(--m-silver) 70%, var(--gold))" '+ink+'/><path d="M104 80 L150 80 L136 98 L196 80 L172 80 L206 58" fill="none" stroke="var(--gold)" stroke-width="2.4" stroke-linejoin="round"/>';
  else if(id==="wpn_morningstar") d='<rect x="16" y="76" width="150" height="8" rx="3" fill="'+H+'" '+ink+'/><circle cx="12" cy="80" r="7" fill="'+mat+'" '+ink+'/>'+[0,1,2,3].map(i=>'<ellipse cx="'+(176+i*13)+'" cy="80" rx="8" ry="4.5" fill="none" stroke="var(--ink)" stroke-width="2.2"/>').join("")+'<circle cx="256" cy="80" r="30" fill="'+mat+'" '+ink+'/>'+[0,45,90,135,180,225,270,315].map(a=>'<path d="M256 44 L262 52 L250 52Z" transform="rotate('+a+' 256 80)" fill="'+mat+'" '+ink+'/>').join("")+'<circle cx="256" cy="80" r="8" fill="'+H+'" '+ink+'/>';
  else if(id==="wpn_vila_moonbow") d='<path d="M150 8 Q300 80 150 152 Q222 80 150 8Z" fill="color-mix(in oklab, var(--m-silver) 78%, var(--gold))" '+ink+'/><path d="M150 8 L150 152" stroke="var(--ink)" stroke-width="1.2"/><path d="M60 80 L236 80 M236 80 l-9 -6 M236 80 l-9 6" stroke="var(--ink)" stroke-width="1.6" fill="none"/><path d="M84 36 l3 7 7 1 -5 5 1 7 -6 -4 -6 4 1 -7 -5 -5 7 -1z" fill="'+G+'"/><path d="M60 118 l2 5 5 1 -4 3 1 5 -4 -3 -4 3 1 -5 -4 -3 5 -1z" fill="'+G+'"/>';
  else if(id==="wpn_neith_bow") d='<path d="M130 12 Q236 80 130 148" fill="none" stroke="color-mix(in oklab, '+H+' 60%, var(--m-worn))" stroke-width="7" stroke-linecap="round" '+ink+'/><path d="M130 12 L130 148" stroke="var(--ink)" stroke-width="1.2"/><path d="M46 36 L238 124 M46 124 L238 36" stroke="var(--ink)" stroke-width="2" fill="none"/><path d="M238 124 l-12 -2 6 -9z M238 36 l-12 2 6 9z" fill="'+G+'" '+ink+'/><path d="M50 38 l12 -5 M50 41 l12 -5 M50 122 l12 5 M50 119 l12 5" stroke="'+G+'" stroke-width="2"/>';
  else if(id==="wpn_miroslav_gospel") d='<rect x="82" y="22" width="156" height="116" rx="7" fill="color-mix(in oklab, '+H+' 70%, var(--ink))" '+ink+'/><rect x="94" y="32" width="132" height="96" rx="3" fill="none" stroke="'+G+'" stroke-width="3"/><path d="M82 22 v116" stroke="var(--ink)" stroke-width="2.4"/><path d="M160 46 v68 M134 70 h52" stroke="'+G+'" stroke-width="7" stroke-linecap="round"/>'+[[110,44],[210,44],[110,116],[210,116]].map(c=>'<circle cx="'+c[0]+'" cy="'+c[1]+'" r="5" fill="var(--h-reason)" '+ink+'/>').join("")+'<circle cx="160" cy="80" r="40" fill="url(#gl)"/>';
  else if(id==="wpn_zographos_codex") d='<rect x="90" y="20" width="140" height="120" rx="5" fill="color-mix(in oklab, var(--m-worn) 55%, '+H+')" '+ink+'/><rect x="100" y="30" width="120" height="100" rx="2" fill="var(--leaf)" stroke="var(--ink)" stroke-width="1.2"/><path d="M90 20 v120" stroke="var(--ink)" stroke-width="2.4"/>'+[[116,52,"o"],[142,52,"t"],[168,52,"c"],[194,52,"o"],[116,80,"c"],[142,80,"o"],[168,80,"t"],[194,80,"c"],[116,108,"t"],[142,108,"c"],[168,108,"o"],[194,108,"t"]].map(g=>g[2]==="o"?'<circle cx="'+g[0]+'" cy="'+g[1]+'" r="8" fill="none" stroke="var(--ink)" stroke-width="2.4"/>':g[2]==="t"?'<path d="M'+(g[0]-8)+' '+g[1]+' h16 M'+g[0]+' '+(g[1]-9)+' v18" stroke="var(--ink)" stroke-width="2.4"/>':'<path d="M'+(g[0]-8)+' '+(g[1]-8)+' h16 v16 h-16z" fill="none" stroke="var(--ink)" stroke-width="2.4"/>').join("");
  else if(id==="wpn_astaroth_goetia") d='<rect x="82" y="22" width="156" height="116" rx="7" fill="color-mix(in oklab, var(--h-reason) 45%, var(--ink))" '+ink+'/><path d="M82 22 v116" stroke="var(--ink)" stroke-width="2.4"/><path d="M160 44 L172 88 L134 60 L186 60 L148 88Z" fill="none" stroke="var(--warn)" stroke-width="3" stroke-linejoin="round"/><circle cx="160" cy="70" r="34" fill="none" stroke="var(--warn)" stroke-width="2"/><path d="M82 52 Q50 60 40 100 M238 100 Q270 120 280 90" fill="none" stroke="var(--muted)" stroke-width="3" stroke-dasharray="6 4"/>';
  else if(id==="wpn_lemegeton") d='<rect x="78" y="14" width="164" height="132" rx="8" fill="color-mix(in oklab, var(--h-reason) 35%, var(--ink))" '+ink+'/><rect x="90" y="26" width="140" height="108" rx="3" fill="none" stroke="'+G+'" stroke-width="2.6"/><path d="M78 14 v132" stroke="var(--ink)" stroke-width="2.4"/><circle cx="160" cy="80" r="36" fill="none" stroke="'+G+'" stroke-width="2.4"/><path d="M160 46 L190 98 L130 98Z M160 114 L130 62 L190 62Z" fill="none" stroke="'+G+'" stroke-width="2.4" stroke-linejoin="round"/><rect x="236" y="68" width="14" height="24" rx="3" fill="'+G+'" '+ink+'/>';
  else if(A==="sword") d='<rect x="20" y="75" width="38" height="10" rx="3" fill="'+H+'" '+ink+'/><circle cx="16" cy="80" r="7" fill="'+(T==="high"?G:mat)+'" '+ink+'/><rect x="58" y="64" width="8" height="32" rx="2" fill="'+(T==="high"?G:H)+'" '+ink+'/><path d="M66 73 L252 73 L286 80 L252 87 L66 87Z" fill="'+mat+'" '+ink+'/>'+(T==="worn"?"":'<path d="M74 80 L246 80" stroke="var(--ink)" stroke-width="1.2" opacity=".6"/>')+nicks+(T==="high"?'<path d="M92 76 l8 8 M112 76 l8 8 M132 76 l8 8" stroke="var(--ink)" stroke-width="1" opacity=".5"/>':"");
  else if(A==="lance") d='<rect x="14" y="77" width="232" height="7" rx="2" fill="'+H+'" '+ink+'/><circle cx="12" cy="80" r="6" fill="'+mat+'" '+ink+'/><path d="M246 68 L300 80 L246 92 Q256 80 246 68Z" fill="'+mat+'" '+ink+'/><path d="M236 80 L210 62 L210 98Z" fill="'+H+'" '+ink+'/>'+(T==="high"?'<rect x="240" y="76" width="8" height="8" fill="'+G+'" '+ink+'/>':"")+nicks;
  else if(A==="axe"&&w.hybrid) d='<rect x="14" y="77" width="250" height="7" rx="2" fill="'+H+'" '+ink+'/><path d="M214 80 L214 36 Q262 28 272 56 Q276 80 272 100 Q262 128 214 124Z" fill="'+mat+'" '+ink+'/><path d="M264 78 L306 80 L264 82Z" fill="'+mat+'" '+ink+'/><path d="M214 124 L196 140 L214 112" fill="'+mat+'" '+ink+'/>';
  else if(id==="wpn_maul") d='<rect x="14" y="77" width="236" height="8" rx="2" fill="'+H+'" '+ink+'/><rect x="222" y="40" width="64" height="80" rx="8" fill="'+mat+'" '+ink+'/><path d="M234 50 v60 M258 46 v68" stroke="var(--ink)" stroke-width="1.2" opacity=".5"/><circle cx="268" cy="80" r="5" fill="'+G+'" '+ink+'/>';
  else if(A==="axe") d='<rect x="14" y="77" width="232" height="7" rx="2" fill="'+H+'" '+ink+'/><path d="M206 80 L206 36 Q258 28 270 58 Q276 80 270 102 Q258 132 206 124Z" fill="'+mat+'" '+ink+'/><path d="M206 80 L240 80" stroke="var(--ink)" stroke-width="1.2" opacity=".5"/>'+(T==="high"?'<circle cx="244" cy="80" r="6" fill="'+G+'" '+ink+'/>':"")+nicks;
  else if(A==="bow") d='<path d="M130 10 Q256 80 130 150" fill="none" stroke="'+(T==="high"?G:H)+'" stroke-width="9" stroke-linecap="round" '+ink+'/><path d="M130 10 L130 150" stroke="var(--ink)" stroke-width="1.3"/><path d="M60 80 L226 80 M226 80 l-10 -6 M226 80 l-10 6 M66 80 l-8 -6 M66 80 l-8 6" stroke="var(--ink)" stroke-width="1.6" fill="none"/>'+(T==="worn"?'<path d="M130 10 L150 56" stroke="var(--ink)" stroke-width="1.6" stroke-dasharray="3 3"/>':"");
  else if(A==="brawl") d='<rect x="52" y="48" width="52" height="64" rx="6" fill="'+mat+'" '+ink+'/><rect x="100" y="42" width="112" height="76" rx="18" fill="'+mat+'" '+ink+'/><path d="M140 42 v76 M170 42 v76 M200 54 v52" stroke="var(--ink)" stroke-width="1.3" opacity=".6"/><path d="M110 118 Q92 148 128 140" fill="'+mat+'" '+ink+'/>'+[132,158,184].map(x=>'<circle cx="'+x+'" cy="58" r="4" fill="'+(T==="high"?G:H)+'" '+ink+'/>').join("")+nicks;
  else if(A==="reason"&&!w.hybrid) d='<rect x="80" y="24" width="150" height="112" rx="8" fill="'+H+'" '+ink+'/><rect x="92" y="34" width="130" height="92" rx="3" fill="color-mix(in oklab, '+H+' 55%, '+mat+')" stroke="var(--ink)" stroke-width="1.2"/><path d="M92 24 v112" stroke="var(--ink)" stroke-width="2"/><circle cx="157" cy="80" r="26" fill="none" stroke="'+(T==="high"?G:"var(--leaf)")+'" stroke-width="2"/><path d="M157 56 l7 17 18 1 -14 11 5 18 -16 -10 -16 10 5 -18 -14 -11 18 -1z" fill="'+(T==="high"?G:"var(--leaf)")+'" stroke="none"/>'+nicks;
  else if(id==="wpn_censer"||(A==="reason"&&w.hybrid)) d='<path d="M160 6 L160 40" stroke="var(--ink)" stroke-width="2"/><path d="M120 40 Q160 20 200 40 L190 100 Q160 120 130 100Z" fill="'+mat+'" '+ink+'/><path d="M130 62 h60 M132 80 h56" stroke="var(--ink)" stroke-width="1.2"/><circle cx="160" cy="70" r="9" fill="'+H+'" '+ink+'/><path d="M160 112 q-12 14 0 26 q12 12 0 22" fill="none" stroke="var(--muted)" stroke-width="3" stroke-linecap="round"/>';
  else if(A==="faith") d='<rect x="30" y="77" width="198" height="7" rx="2" fill="color-mix(in oklab, '+H+' 40%, var(--m-worn))" '+ink+'/><circle cx="256" cy="80" r="21" fill="'+mat+'" '+ink+'/><circle cx="256" cy="80" r="10" fill="'+(T==="high"?G:H)+'" '+ink+'/>'+[0,30,60,90,120,150,180,210,240,270,300,330].map(a=>'<path d="M256 '+(80-24)+' l0 -11" transform="rotate('+a+' 256 80)" stroke="'+mat+'" stroke-width="3.4" stroke-linecap="round"/>').join("")+nicks;
  if(T==="legendary"||T==="mythic") glow='<circle cx="160" cy="80" r="'+(T==="mythic"?118:92)+'" fill="url(#gl)"/>';
  const defs='<defs><radialGradient id="gl"><stop offset="0" stop-color="var(--gold)" stop-opacity=".30"/><stop offset="1" stop-color="var(--gold)" stop-opacity="0"/></radialGradient></defs>';
  return '<svg class="fig wide" viewBox="0 0 320 160" role="img" aria-label="'+esc(w.name)+'">'+defs+glow+'<ellipse class="shadow" cx="160" cy="154" rx="112" ry="4"/><g transform="rotate(-9 160 80)">'+d+'</g></svg>';
}
"""
