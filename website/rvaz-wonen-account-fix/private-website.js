(()=>{
 'use strict';
 const cfg=window.rvazPrivate,root=document.getElementById('rvaz-private-root');if(!cfg||!root)return;
 const el=(tag,text)=>{const x=document.createElement(tag);if(text)x.textContent=text;return x;};
 const error=el('p'),body=el('div');root.append(error,body);
 const api=async(path,data)=>{const r=await fetch(cfg.api+path,{method:data?'POST':'GET',credentials:'same-origin',headers:{'Content-Type':'application/json','X-WP-Nonce':cfg.nonce},...(data?{body:JSON.stringify(data)}:{})});const d=await r.json();if(!r.ok)throw Error(d.message||'De aanvraag is niet gelukt.');return d;};
 const btn=(label,action)=>{const b=el('button',label);b.type='button';b.onclick=async()=>{b.disabled=true;error.textContent='';try{await action();}catch(e){error.textContent=e.message;}finally{b.disabled=false;}};return b;};
 const link=(label,url)=>{const a=el('a',label);try{const u=new URL(url,location.href);if(['https:','http:'].includes(u.protocol))a.href=u.href;}catch(_){}return a;};
 const checkbox=label=>{const l=el('label',label),i=el('input');i.type='checkbox';l.append(i);return {label:l,input:i};};
 if(!cfg.nonce){body.append(link('Log in met je RVAZ-account om je woning aan te bieden.',cfg.login));return;}
 if(cfg.admin){
  for(const row of cfg.rows){const card=el('article');card.append(el('h2',row.title),el('p',`${row.owner_email} · ${row.publication_status} · Betaling: ${row.payment_status}`),link('Woning en foto’s controleren',row.edit_url));
   const confirmed=checkbox('Ik heb de bevoegdheid, kenmerken en foto’s gecontroleerd.');card.append(confirmed.label,btn('Goedkeuren',async()=>{const d=await api(`/beheer/particulier/${row.id}`,{decision:'approve',authority_checked:confirmed.input.checked});card.append(el('p',d.status==='awaiting_payment'?'Gecontroleerd. De eigenaar kan nu de factuur aanvragen.':'Goedgekeurd en gepubliceerd.'));}),btn('Afwijzen',async()=>{const reason=prompt('Reden voor afwijzing');if(reason===null)return;await api(`/beheer/particulier/${row.id}`,{decision:'reject',reason});card.append(el('p','Afgewezen; de eigenaar kan de woning aanpassen.'));}));body.append(card);
  }if(!cfg.rows.length)body.append(el('p','Nog geen particuliere woningen.'));return;
 }
 async function render(){
  const rows=await api('/particulier/woningen');body.replaceChildren();if(!rows.length)body.append(btn('Nieuwe woning',()=>edit({})));
  for(const row of rows){const a=el('article');a.append(el('h3',row.title),el('p',`Status: ${row.publication_status} · Betaling: ${row.payment_status}`));if(row.placement_expires)a.append(el('p',`Plaatsing eindigt: ${new Date(row.placement_expires*1000).toLocaleString('nl-NL')}`));if(row.review_reason)a.append(el('p',`Beoordeling: ${row.review_reason}`));a.append(btn('Woning bewerken',()=>edit(row)),btn('Archiveren',async()=>{if(!confirm('Deze woning verdwijnt uit het aanbod.'))return;await api(`/particulier/woningen/${row.id}/verwijderen`,{confirm:true});await render();}));
   const authority=checkbox('Ik ben bevoegd deze woning aan te bieden.'),photos=checkbox('Ik heb toestemming om deze foto’s te gebruiken.');a.append(authority.label,photos.label,btn('Indienen voor beoordeling',async()=>{await api(`/particulier/woningen/${row.id}/indienen`,{authority_confirmed:authority.input.checked,photos_confirmed:photos.input.checked});await render();}));
   if(row.publication_status==='pending'){
    const couponLabel=el('label','Kortingscode (optioneel) '),coupon=el('input'),preview=el('small');coupon.type='text';coupon.placeholder='Vul je kortingscode in';coupon.autocomplete='off';coupon.style.cssText='padding:8px;margin:4px 8px;max-width:200px';couponLabel.append(coupon);preview.setAttribute('aria-live','polite');preview.style.display='block';a.append(couponLabel,preview);
    coupon.addEventListener('change',async()=>{if(!coupon.value.trim()){preview.textContent='';return;}try{const q=await api('/kortingscode/controleren',{code:coupon.value,audience:'particulier'});preview.textContent=`Prijs na korting: €${Number(q.total).toFixed(2).replace('.',',')}`;}catch(e){preview.textContent=e.message;}});
    a.append(btn('Plaatsing aanvragen: €25 / één maand (vóór korting)',async()=>{let amount=25;if(coupon.value.trim()){const q=await api('/kortingscode/controleren',{code:coupon.value,audience:'particulier'});amount=Number(q.total);}if(!confirm(`Bevestig €${amount.toFixed(2).replace('.',',')} voor één woning, één kalendermaand vanaf publicatie. Geen automatische verlenging. RVAZ controleert eerst de woning.`))return;await api(`/particulier/woningen/${row.id}/bestellen`,{confirm:true,expected_price:'25.00',expected_period:'1_month',coupon_code:coupon.value.trim()});await render();}));
   }body.append(a);
  }
  const invoices=await api('/particulier/facturen');if(invoices.items.length)body.append(el('h3','Mijn plaatsingsfacturen'));
  for(const inv of invoices.items){const a=el('article');a.append(el('p',`${inv.invoice_no}: €${Number(inv.total).toFixed(2)} · ${inv.status}`),btn('Factuur downloaden',async()=>{const d=await api(`/particulier/facturen/${inv.id}/pdf`);const bytes=Uint8Array.from(atob(d.pdf_base64),c=>c.charCodeAt(0)),url=URL.createObjectURL(new Blob([bytes],{type:'application/pdf'})),download=el('a');download.href=url;download.download=d.filename;download.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}));if(inv.tikkie_url&&inv.status==='open')a.append(link('Betaal via de factuurlink',inv.tikkie_url));body.append(a);}
  const messages=await api('/particulier/aanvragen');body.append(el('h3','Reacties op mijn woning'));if(!messages.length)body.append(el('p','Nog geen reacties.'));for(const m of messages){const a=el('article');a.append(el('strong',m.name),el('p',m.message),el('p',`${m.email} · ${m.phone||''}`),btn('Gelezen',async()=>{await api(`/particulier/aanvragen/${m.id}`,{action:'read'});await render();}));body.append(a);}
 }
 async function edit(row){
  body.replaceChildren();const form=el('form'),fields={},grid=el('div');grid.className='rvaz-private-fields';let files=[];
  form.append(el('p','Bied een koopwoning, huurwoning of kamer aan. Voeg je woninggegevens en foto’s toe, sla het concept op en dien daarna je woning in. Aanpassingen vereisen opnieuw beoordeling en verlengen de betaalde periode niet.'));
  for(const [k,label]of Object.entries({transactie:'Huur of koop',title:'Titel',description:'Omschrijving',adres:'Adres',postcode:'Postcode',plaats:'Plaats',prijs:'Vraagprijs / huurprijs per maand',woningtype:'Woningtype (woning, appartement of kamer)',woonoppervlak:'Woonoppervlakte',energielabel:'Energielabel',bouwjaar:'Bouwjaar',kamers:'Kamers',slaapkamers:'Slaapkamers',badkamers:'Badkamers',perceel:'Perceel',tuin:'Tuin',garage:'Garage',aanvaarding:'Aanvaarding',borg:'Borg bij verhuur',contractduur:'Huurperiode / contractduur',inkomenseisen:'Inkomenseisen bij verhuur'})){const l=el('label',label),i=el(k==='description'?'textarea':k==='transactie'?'select':'input');if(k==='transactie')for(const value of ['Koop','Huur']){const option=el('option',value==='Koop'?'Te koop':'Te huur');option.value=value;i.append(option);}i.setAttribute('aria-label',label);i.value=row[k]||(k==='transactie'?'Koop':'');fields[k]=i;if(k==='description')l.className='rvaz-private-wide';l.append(i);grid.append(l);}
  form.append(grid);
  form.append(el('h3','Foto’s van je woning'),el('p','Selecteer één of meerdere foto’s (JPG, PNG, WebP of GIF). Ze worden bij het opslaan toegevoegd. Minstens één foto is nodig voor beoordeling.'));
  const label=el('label','Foto’s toevoegen'),input=el('input'),selection=el('p');input.type='file';input.multiple=true;input.accept='image/jpeg,image/png,image/webp,image/gif';input.setAttribute('aria-label','Foto’s toevoegen');input.onchange=()=>{files=Array.from(input.files);selection.textContent=files.length?`${files.length} geselecteerd: ${files.map(f=>f.name).join(', ')}`:'';};label.append(input);form.append(label,selection);
  for(const [index,p]of (row.photos||[]).entries()){const a=el('article'),img=el('img');img.src=p.url;img.alt=`Woningfoto ${index+1}`;img.style.maxWidth='180px';a.append(img,el('p',index===0?'Hoofdfoto':`Foto ${index+1}`));
   if(index>0)a.append(btn('Als hoofdfoto',async()=>{const ids=[p.id,...row.photos.filter(x=>x.id!==p.id).map(x=>x.id)];await edit(await api(`/particulier/woningen/${row.id}/galerij`,{photo_ids:ids}));}));
   a.append(btn('Foto verwijderen',async()=>{const ids=row.photos.filter(x=>x.id!==p.id).map(x=>x.id);await edit(await api(`/particulier/woningen/${row.id}/galerij`,{photo_ids:ids}));}));form.append(a);
  }
  const save=el('button','Woning en foto’s opslaan');save.type='submit';form.append(save);form.onsubmit=async e=>{e.preventDefault();save.disabled=true;input.disabled=true;error.textContent='';let saved=false;
   try{const data={publication_status:'draft'};for(const[k,v]of Object.entries(fields))data[k]=v.value;row=await api(`/particulier/woningen${row.id?'/'+row.id:''}`,data);saved=true;
    for(const [index,file]of files.entries()){selection.textContent=`Foto ${index+1} van ${files.length} uploaden…`;const f=new FormData();f.append('photo',file);const r=await fetch(cfg.api+`/particulier/woningen/${row.id}/fotos`,{method:'POST',credentials:'same-origin',headers:{'X-WP-Nonce':cfg.nonce},body:f});const d=await r.json();if(!r.ok)throw Error(d.message||'Foto uploaden is niet gelukt.');row=d;}
   }catch(e){error.textContent=e.message;}finally{save.disabled=false;input.disabled=false;if(saved)await edit(row);}
  };body.append(form,btn('Terug naar mijn woning en indienen',render));
 }

 render().catch(e=>{error.textContent=e.message;body.append(btn('Opnieuw proberen',render));});
})();
