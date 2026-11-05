import {reminder,dateCandidates,validateRecord,validDate} from './model.js';
const $=id=>document.getElementById(id),MAX=20*1024*1024;
let db,records=[],tab='notes',draft=null,pending=null,previewUrl=null,cameraStream=null,worker=null,job=0,activePdf=null;
const node=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
const button=(text,fn,cls)=>{const b=node('button',text,cls);b.type='button';b.onclick=fn;return b;};
function toast(s){$('toast').textContent=s;$('toast').hidden=false;clearTimeout(toast.timer);toast.timer=setTimeout(()=>$('toast').hidden=true,5000);}
function error(e){console.error(e);toast(e.message||String(e));}
function openDb(){return new Promise((resolve,reject)=>{const q=indexedDB.open('vessel-deck-organizer',1);q.onupgradeneeded=()=>{q.result.createObjectStore('records',{keyPath:'id'});};q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(Error('Local database unavailable. Check browser storage permissions.'));});}
function transaction(mode,action){return new Promise((resolve,reject)=>{const tx=db.transaction('records',mode);const store=tx.objectStore('records');let result;try{result=action(store);}catch(e){tx.abort();reject(e);return;}tx.oncomplete=()=>resolve(result?.result);tx.onerror=()=>reject(tx.error||Error('Storage failed'));tx.onabort=()=>reject(tx.error||Error('Storage failed; your changes were not saved.'));});}
async function reload(){records=await transaction('readonly',s=>s.getAll());render();}
function render(){
 const due=records.filter(r=>r.kind==='docs'&&reminder(r).due);$('badge').textContent=due.length||'';
 $('add').textContent=tab==='notes'?'New note':'New document';$('reminderHint').hidden=tab!=='reminders';
 document.querySelectorAll('[data-tab]').forEach(b=>b.classList.toggle('active',b.dataset.tab===tab));
 const query=$('search').value.trim().toLowerCase();let list=records.filter(r=>tab==='reminders'?r.kind==='docs'&&reminder(r).due:r.kind===tab);
 list=list.filter(r=>(r.title+' '+r.body+' '+(r.number||'')).toLowerCase().includes(query));
 list.sort((a,b)=>tab==='notes'?(Number(b.pinned)-Number(a.pinned)||b.updated-a.updated):a.expiry.localeCompare(b.expiry));
 const root=$('list');root.replaceChildren();
 if(!list.length){root.append(node('div',query?'No matching records.':tab==='reminders'?'No documents due for a reminder.':tab==='notes'?'Create your first note or scan text from a photo.':'Add a document and its confirmed expiry date.','empty'));return;}
 for(const r of list){const c=node('article',undefined,'card');c.append(node('h3',(r.pinned&&r.kind==='notes'?'Pinned · ':'')+r.title));
  if(r.kind==='docs'){const status=reminder(r);c.append(node('p',`${r.expiry} · ${status.label}`,status.days<0?'expired':status.due?'due':'meta'));if(r.number)c.append(node('p',r.number,'meta'));}
  if(r.body)c.append(node('p',r.body.slice(0,800),'text'));
  const actions=node('div',undefined,'actions');
  actions.append(
    button('Open / Edit',()=>edit(r)),
    button('Delete',()=>deleteRecord(r),'danger'),
  );
  if(r.attachments.length)actions.append(node('span',`${r.attachments.length} attachment(s)`,'meta'));
  c.append(actions);root.append(c);
 }
}
function edit(r){draft=r?structuredClone(r):{id:crypto.randomUUID(),kind:tab==='notes'?'notes':'docs',title:'',body:'',pinned:false,number:'',issue:'',expiry:'',lead:30,attachments:[],updated:Date.now()};
 $('editHeading').textContent=(r?'Edit ':'New ')+(draft.kind==='notes'?'note':'document');$('title').value=draft.title;$('body').value=draft.body;$('pin').checked=!!draft.pinned;
 $('docNumber').value=draft.number||'';$('issue').value=draft.issue||'';$('expiry').value=draft.expiry||'';$('lead').value=String(draft.lead??30);
 $('expiry').required=draft.kind==='docs';$('docFields').hidden=draft.kind!=='docs';$('pinLabel').hidden=draft.kind!=='notes';$('delete').hidden=!r;$('editError').textContent='';attachments();$('editor').showModal();
}
function attachments(){
 const root=$('attachments');
 root.replaceChildren();
 draft.attachments.forEach((attachment,index)=>{
  const row=node('div',undefined,'attachment');
  row.append(node('span',attachment.name),button('View',()=>preview(attachment)));
  if(attachment.type==='application/pdf'){
   row.append(button('Compress PDF',event=>compressAttachment(attachment,event.currentTarget)));
  }
  row.append(button('Remove',()=>{draft.attachments.splice(index,1);attachments();}));
  root.append(row);
 });
}
async function compressAttachment(attachment, control, fromEditor=true){
 const currentDraft=draft;
 const isCurrent=()=>!fromEditor||(draft===currentDraft&&$('editor').open&&draft.attachments.includes(attachment));
 const message=$(fromEditor?'editError':'compressStatus');
 message.textContent='';
 control.disabled=true;
 control.textContent='Opening PDF…';
 try{
  if(!confirm('Create a compressed copy with pages saved as images? Searchable text, links and interactive features will be lost in the copy. Your original will be kept.'))return;
  const {compressPdf}=await import('./compress-pdf.js');
  const result=await compressPdf(attachment.blob,(page,total)=>{
   if(!isCurrent())throw new Error('Compression cancelled.');
   control.textContent=`Compressing ${page}/${total}…`;
  });
  if(!isCurrent())return;
  if(result.size>=attachment.blob.size){
   message.textContent='This PDF could not be made smaller.';
   return;
  }
  const kb=bytes=>`${Math.round(bytes/1024).toLocaleString()} KB`;
  if(confirm(`PDF size: ${kb(attachment.blob.size)} → ${kb(result.size)}. Download the compressed copy?`)){
   download(result,`${attachment.name.replace(/\.pdf$/i,'')}-compressed.pdf`);
  }
 }catch(e){
  if(isCurrent())message.textContent=e.message||'Could not compress this PDF.';
 }finally{
  control.disabled=false;
  control.textContent='Compress PDF';
 }
}
$('compressPdf').onclick=()=>{
 $('compressFile').value='';
 $('compressFile').click();
};
$('compressFile').onchange=async event=>{
 const file=event.currentTarget.files[0];
 if(!file)return;
 const control=$('compressPdf');
 control.disabled=true;
 try{
  const attachment=await checkedAttachment(file);
  if(attachment.type!=='application/pdf')throw new Error('Choose a PDF file.');
  await compressAttachment(attachment,control,false);
 }catch(e){
  $('compressStatus').textContent=e.message;
 }finally{
  control.disabled=false;
 }
};
function preview(a){if(previewUrl)URL.revokeObjectURL(previewUrl);previewUrl=URL.createObjectURL(a.blob);$('previewName').textContent=a.name;const content=$('previewContent');content.replaceChildren();
 const el=document.createElement(a.type==='application/pdf'?'iframe':'img');el.src=previewUrl;if(a.type==='application/pdf'){el.title='Document preview';}else el.alt=a.name;content.append(el);
 $('downloadAttachment').onclick=()=>download(a.blob,a.name);$('preview').showModal();
}
function download(blob,name){const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),60000);}
async function checkedAttachment(file){
 if(file.size>MAX)throw Error('File exceeds 20 MB. Use a smaller file.');
 const head=new Uint8Array(await file.slice(0,12).arrayBuffer());let type;
 if(String.fromCharCode(...head.slice(0,5))==='%PDF-')type='application/pdf';
 else if(head[0]===0xff&&head[1]===0xd8)type='image/jpeg';
 else if(head[0]===0x89&&head[1]===0x50&&head[2]===0x4e&&head[3]===0x47)type='image/png';
 else if(String.fromCharCode(...head.slice(0,4))==='RIFF'&&String.fromCharCode(...head.slice(8,12))==='WEBP')type='image/webp';
 else throw Error('Use a JPEG, PNG, WebP image or PDF. This file type is not supported.');
 return {name:(file.name||'camera.jpg').slice(0,200),type,blob:new Blob([file],{type})};
}
let fileAction='attach';function pick(action){fileAction=action;$('fileInput').value='';$('fileInput').click();}
$('fileInput').onchange=async()=>{const file=$('fileInput').files[0];if(!file)return;try{const a=await checkedAttachment(file);if(fileAction==='scan')await recognize(a);else{if(draft.attachments.length>=5)throw Error('Maximum 5 attachments per record.');draft.attachments.push(a);attachments();}}catch(e){error(e);}};
$('attach').onclick=()=>pick('attach');$('scan').onclick=()=>pick('scan');
$('editForm').onsubmit=async e=>{e.preventDefault();$('editError').textContent='';$('save').disabled=true;try{
 const r={...draft,title:$('title').value.trim(),body:$('body').value,pinned:$('pin').checked,updated:Date.now()};
 if(r.kind==='docs'){r.number=$('docNumber').value.trim();r.issue=$('issue').value;r.expiry=$('expiry').value;r.lead=+$('lead').value;}
 validateRecord(r);await transaction('readwrite',s=>s.put(r));$('editor').close();await reload();toast('Saved on this device.');
 }catch(e){$('editError').textContent=e.message||'Could not save. Browser storage may be full.';}finally{$('save').disabled=false;}};
async function deleteRecord(record, fromEditor=false){
  const kind=record.kind==='notes'?'note':'document';
  if(!confirm(`Delete ${kind} “${record.title}” and its attached files?`))return;
  try{
    await transaction('readwrite',store=>store.delete(record.id));
    if(fromEditor)$('editor').close();
    await reload();
  }catch(e){error(e);}
}
$('delete').onclick=()=>deleteRecord(draft,true);
$('add').onclick=()=>edit();$('search').oninput=render;document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{tab=b.dataset.tab;render();});
function stopCamera(){cameraStream?.getTracks().forEach(t=>t.stop());cameraStream=null;$('video').srcObject=null;}
$('camera').onclick=async()=>{if(!navigator.mediaDevices?.getUserMedia){toast('Camera requires HTTPS or localhost and a supported browser. Use Scan file instead.');return;}
 $('cameraError').textContent='';$('capture').disabled=true;$('cameraDialog').showModal();try{
 const stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:'environment'},width:{ideal:1920},height:{ideal:1080}},audio:false});
 if(!$('cameraDialog').open){stream.getTracks().forEach(t=>t.stop());return;}cameraStream=stream;$('video').srcObject=stream;await $('video').play();$('capture').disabled=false;
 }catch(e){$('cameraError').textContent='Camera unavailable or permission denied. You can select a photo using Scan file.';}};
$('capture').onclick=async()=>{try{const v=$('video');if(!v.videoWidth)throw Error('Camera is not ready yet.');const c=document.createElement('canvas');c.width=v.videoWidth;c.height=v.videoHeight;c.getContext('2d').drawImage(v,0,0);const blob=await new Promise(r=>c.toBlob(r,'image/jpeg',0.94));if(!blob)throw Error('Could not capture photo.');stopCamera();$('cameraDialog').close();await recognize({name:`photo-${Date.now()}.jpg`,type:'image/jpeg',blob});}catch(e){error(e);}};
$('cameraDialog').addEventListener('close',stopCamera);
$('preview').addEventListener('close',()=>{if(previewUrl)URL.revokeObjectURL(previewUrl);previewUrl=null;$('previewContent').replaceChildren();});
for(const b of document.querySelectorAll('[data-close]'))b.onclick=()=>$(b.dataset.close).close();
function progress(text,ratio){$('progress').textContent=text;if(Number.isFinite(ratio))$('progressBar').value=ratio;else $('progressBar').removeAttribute('value');}
async function loadTesseract(){if(window.Tesseract)return;await new Promise((resolve,reject)=>{const s=document.createElement('script');s.src=new URL('vendor/tesseract.min.js',location.href).href;s.onload=resolve;s.onerror=()=>{s.remove();reject(Error('OCR files are unavailable. Prepare offline OCR while the app server is reachable.'));};document.head.append(s);});}
async function scaledImage(blob){const bitmap=await createImageBitmap(blob);try{if(bitmap.width*bitmap.height>50000000)throw Error('Image is too large. Reduce its dimensions.');const scale=Math.min(1,2400/Math.max(bitmap.width,bitmap.height));const c=document.createElement('canvas');c.width=Math.max(1,Math.round(bitmap.width*scale));c.height=Math.max(1,Math.round(bitmap.height*scale));const ctx=c.getContext('2d');ctx.fillStyle='white';ctx.fillRect(0,0,c.width,c.height);ctx.drawImage(bitmap,0,0,c.width,c.height);return c;}finally{bitmap.close();}}
async function recognize(a){
 if($('busy').open)return;pending=a;const token=++job;$('busy').showModal();progress('Reading document…');let localWorker=null,localPdf=null;const current=()=>{if(token!==job)throw Error('Cancelled');};
 try{
  const ocr=async image=>{current();if(!localWorker){await loadTesseract();current();localWorker=await window.Tesseract.createWorker('eng+rus',1,{
    workerPath:new URL('vendor/worker.min.js',location.href).href,corePath:new URL('vendor/',location.href).href,langPath:new URL('vendor/',location.href).href,
    gzip:true,cacheMethod:'write',logger:m=>{if(token===job)progress(m.status||'Recognizing…',m.progress);},
   });if(token!==job){await localWorker.terminate();localWorker=null;throw Error('Cancelled');}worker=localWorker;}
   current();const result=await localWorker.recognize(image);current();return result.data.text;
  };
  let text='',method='Local OCR';
  if(a.type==='application/pdf'){
   progress('Opening PDF…');const pdfjs=await import('./vendor/pdf.mjs');current();pdfjs.GlobalWorkerOptions.workerSrc=new URL('vendor/pdf.worker.mjs',location.href).href;
   const loading=pdfjs.getDocument({data:new Uint8Array(await a.blob.arrayBuffer()),isEvalSupported:false,enableXfa:false,stopAtErrors:true,useSystemFonts:true});
   localPdf=await loading.promise;activePdf=localPdf;current();if(localPdf.numPages>20)throw Error('This PDF has more than 20 pages. Split it before recognition; it can still be attached without scanning.');
   for(let pageNo=1;pageNo<=localPdf.numPages;pageNo++){
    current();progress(`Reading page ${pageNo} of ${localPdf.numPages}…`);const page=await localPdf.getPage(pageNo);const content=await page.getTextContent();let pageText=content.items.map(i=>i.str+(i.hasEOL?'\n':' ')).join('');
    if(pageText.replace(/\s/g,'').length<20){const initial=page.getViewport({scale:1});const view=page.getViewport({scale:Math.min(2.5,2400/Math.max(initial.width,initial.height))});const canvas=document.createElement('canvas');canvas.width=Math.ceil(view.width);canvas.height=Math.ceil(view.height);await page.render({canvasContext:canvas.getContext('2d'),viewport:view}).promise;pageText=await ocr(canvas);canvas.width=canvas.height=0;}
    text+=`\n--- Page ${pageNo} ---\n${pageText}`;page.cleanup();if(text.length>100000)throw Error('Too much recognized text. Split this document into smaller files.');
   }method='Local PDF text extraction / OCR';
  }else{text=await ocr(await scaledImage(a.blob));}
  current();if(!text.trim())throw Error('No readable text found. Try a sharper photo or enter the text manually.');
  showReview(text,method);
 }catch(e){if(token===job)error(e.name==='PasswordException'?Error('Password-protected PDF: unlock it locally before importing.'):e);}
 finally{if(localWorker){await localWorker.terminate().catch(()=>{});if(worker===localWorker)worker=null;}if(localPdf){await localPdf.destroy().catch(()=>{});if(activePdf===localPdf)activePdf=null;}if(token===job)$('busy').close();}
}
function cancelOcr(){job++;worker?.terminate().catch(()=>{});worker=null;activePdf?.destroy().catch(()=>{});activePdf=null;$('busy').close();toast('Recognition cancelled.');}
$('cancelOcr').onclick=cancelOcr;$('busy').addEventListener('cancel',e=>{e.preventDefault();cancelOcr();});
function showReview(text,method){$('recognized').value=text;$('ocrInfo').textContent=method+' · '+pending.name+'. Check every date against the original.';$('reviewConfirm').checked=false;$('reviewError').textContent='';$('keepPhoto').checked=true;$('dateReview').hidden=draft.kind!=='docs';$('reviewExpiry').value='';
 $('suggestTitle').value=$('title').value||text.split(/\r?\n/).find(l=>l.trim()&&!l.startsWith('---'))?.trim().slice(0,200)||'';
 $('suggestNumber').value=$('docNumber').value||text.match(/(?:certificate|document|cert\.?)[ \t]*(?:no\.?|number|#)[ \t:.-]*([A-Z0-9][A-Z0-9\/-]{2,60})/i)?.[1]||'';
 const root=$('dateCandidates');root.replaceChildren();const dates=dateCandidates(text);
 if(!dates.length)root.append(node('p','No clear date found. Enter the expiry date manually.','hint'));
 for(const c of dates){const row=node('div',undefined,'card');row.append(node('p',c.context,'meta'),button(`${c.iso}${c.ambiguous?' — ambiguous format':''}: use as expiry`,()=>{$('reviewExpiry').value=c.iso;}));root.append(row);}
 $('review').showModal();
}
$('insert').onclick=()=>{if(!$('reviewConfirm').checked){$('reviewError').textContent='Check the recognized text and selected date, then tick the confirmation.';return;}
 if($('keepPhoto').checked&&draft.attachments.length>=5){$('reviewError').textContent='Maximum 5 attachments. Uncheck Keep source file or remove an existing attachment.';return;}
 const text=$('recognized').value;if([$('body').value,text].filter(Boolean).join('\n\n').length>100000){$('reviewError').textContent='The combined note is too long.';return;}
 $('body').value=[$('body').value,text].filter(Boolean).join('\n\n');
 if(draft.kind==='docs'){$('title').value=$('suggestTitle').value;$('docNumber').value=$('suggestNumber').value;if($('reviewExpiry').value)$('expiry').value=$('reviewExpiry').value;}
 if($('keepPhoto').checked&&pending)draft.attachments.push(pending);attachments();$('review').close();toast('Inserted into the draft. Press Save to keep it.');};
async function prepareOffline(){const b=$('offline');b.disabled=true;$('offlineStatus').textContent='Preparing local OCR files. Keep this page open…';try{
 if(!('serviceWorker' in navigator))throw Error('Offline preparation requires a supported browser and HTTPS or localhost.');
 const registration=await navigator.serviceWorker.register('./sw.js',{scope:'./'});await registration.update();
 const w=registration.installing||registration.waiting||registration.active;
 if(!w)throw Error('Offline worker could not start.');
 if(w.state!=='activated')await new Promise((resolve,reject)=>{
  const timer=setTimeout(()=>reject(Error('Preparation timed out. Check the installation and retry.')),120000);
  const changed=()=>{if(w.state==='activated'){clearTimeout(timer);resolve();}else if(w.state==='redundant'){clearTimeout(timer);reject(Error('Offline preparation failed. Check that all vendor files were installed.'));}};
  w.addEventListener('statechange',changed);changed();
 });
 const files=await (await fetch('./offline-files.json')).json();const cache=await caches.open('deck-organizer-offline-v1');
 for(const f of files){if(!await cache.match(new URL(f,location.href).href))throw Error('Offline preparation incomplete. Retry while the server is reachable.');}
 $('offlineStatus').textContent='Offline OCR ready. Documents are processed on this device.';
 navigator.storage?.persist?.().catch(()=>{});
 }catch(e){$('offlineStatus').textContent=e.message||'Offline preparation failed. Please retry.';}finally{b.disabled=false;}}
$('offline').onclick=prepareOffline;
window.addEventListener('beforeunload',e=>{if($('editor').open){e.preventDefault();e.returnValue='';}stopCamera();});
document.addEventListener('visibilitychange',()=>{if(document.hidden)stopCamera();else if(db)render();});
setInterval(()=>{if(db)render();},60000);
try{db=await openDb();await reload();const due=records.filter(r=>r.kind==='docs'&&reminder(r).due);if(due.length)toast(`${due.length} document(s) need attention. Open Reminders.`);
 if('caches' in window&&await caches.has('deck-organizer-offline-v1'))$('offlineStatus').textContent='Offline files saved. Use Prepare offline OCR to verify them after an update.';
}catch(e){$('list').replaceChildren(node('p',e.message,'error'));$('add').disabled=true;}
