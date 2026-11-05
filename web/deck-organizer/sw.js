const CACHE='deck-organizer-offline-v1';
// Refresh cached files in place to include compression for text and scanned PDFs.
self.addEventListener('install',event=>event.waitUntil((async()=>{
 const response=await fetch(new URL('offline-files.json',self.registration.scope),{cache:'reload'});
 if(!response.ok)throw Error('Missing offline manifest');
 const files=await response.json();const cache=await caches.open(CACHE);
 // Cache only this module. Do not replace the parent Flutter service worker.
 for(const file of files){const url=new URL(file,self.registration.scope);if(url.origin!==self.location.origin||!url.href.startsWith(self.registration.scope))throw Error('Invalid offline path');
  const asset=await fetch(url,{cache:'reload'});if(!asset.ok)throw Error('Missing '+file);await cache.put(url,asset);
 }
 await self.skipWaiting();
})()));
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('fetch',event=>{
 const url=new URL(event.request.url);if(event.request.method!=='GET'||url.origin!==self.location.origin||!url.href.startsWith(self.registration.scope))return;
 event.respondWith((async()=>{const cache=await caches.open(CACHE);const key=url.pathname.endsWith('/')?new URL('index.html',url).href:event.request;return await cache.match(key)||fetch(event.request);})());
});
