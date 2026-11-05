export function validDate(s){if(!/^\d{4}-\d{2}-\d{2}$/.test(s||''))return false;const [y,m,d]=s.split('-').map(Number);const t=new Date(Date.UTC(y,m-1,d));return y>=1900&&y<=2200&&t.getUTCFullYear()===y&&t.getUTCMonth()===m-1&&t.getUTCDate()===d;}
export function today(){const d=new Date();return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;}
export function daysUntil(expiry,now=today()){if(!validDate(expiry)||!validDate(now))throw Error('Invalid date');return Math.round((Date.parse(expiry+'T00:00:00Z')-Date.parse(now+'T00:00:00Z'))/86400000);}
export function reminder(doc,now=today()){const days=daysUntil(doc.expiry,now);return {days,due:days<=doc.lead,label:days<0?`Expired ${-days} day(s) ago`:days===0?'Expires today':`Expires in ${days} day(s)`};}
export function dateCandidates(text){
 const candidates=new Map();const add=(y,m,d,context,ambiguous=false)=>{const iso=`${y}-${String(m).padStart(2,'0')}-${String(d).padStart(2,'0')}`;if(validDate(iso)&&!candidates.has(iso))candidates.set(iso,{iso,context:context.slice(0,180),ambiguous});};
 for(const line of text.split(/\r?\n/)){
  for(const m of line.matchAll(/\b(20\d{2}|19\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b/g))add(+m[1],+m[2],+m[3],line);
  for(const m of line.matchAll(/\b(\d{1,2})[-/.](\d{1,2})[-/.](20\d{2}|19\d{2})\b/g)){
   const a=+m[1],b=+m[2],y=+m[3],amb=a<=12&&b<=12&&a!==b;add(y,b,a,line,amb);if(amb)add(y,a,b,line,true);else if(b>12)add(y,a,b,line);
  }
  const names=['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'];
  const ru=['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'];
  const months='January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec|января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря';
  for(const m of line.matchAll(new RegExp('(\\d{1,2})[ .-]+('+months+')[ ,.\\-]+(20\\d{2}|19\\d{2})','gi'))){const name=m[2].toLowerCase();let mo=names.indexOf(name.slice(0,3));if(mo<0)mo=ru.findIndex(x=>name.startsWith(x));if(name==='мая')mo=4;if(mo>=0)add(+m[3],mo+1,+m[1],line);}
 }
 return [...candidates.values()].slice(0,40);
}
export function validateRecord(r){
 if(!r||!['notes','docs'].includes(r.kind)||typeof r.id!=='string'||!r.id||typeof r.title!=='string'||!r.title.trim()||r.title.length>200||typeof r.body!=='string'||r.body.length>100000)throw Error('Invalid record');
 if(r.kind==='docs'&&(!validDate(r.expiry)||![0,1,7,14,30].includes(r.lead)|| (r.issue&&!validDate(r.issue)) || (r.issue&&r.issue>r.expiry)))throw Error('Invalid certificate dates or reminder');
 if(!Array.isArray(r.attachments)||r.attachments.length>5)throw Error('Invalid attachments');
 return r;
}
