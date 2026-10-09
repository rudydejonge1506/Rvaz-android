(() => {
 'use strict';
 const cfg = window.rvazReader, root = document.getElementById('rvaz-reader-root');
 if (!cfg || !root) return;
 const el=(tag,text)=>{const e=document.createElement(tag);if(text)e.textContent=text;return e;};
 const error=el('p'); root.append(error);
 const api=async(path,body)=>{const r=await fetch(cfg.api+path,{method:body?'POST':'GET',credentials:'same-origin',headers:{'Content-Type':'application/json','X-WP-Nonce':cfg.nonce},...(body?{body:JSON.stringify(body)}:{})});const d=await r.json();if(!r.ok)throw Error(d.message||'Ophalen is niet gelukt.');return d;};
 const act=(label,fn)=>{const b=el('button',label);b.type='button';b.onclick=async()=>{b.disabled=true;error.textContent='';try{await fn();}catch(e){error.textContent=e.message;}finally{b.disabled=false;}};return b;};
 const link=(title,url)=>{const a=el('a',title);try{const u=new URL(url,location.href);if(['http:','https:'].includes(u.protocol))a.href=u.href;}catch(_){}return a;};
 if(!cfg.nonce){root.append(link('Log in met je RVAZ-account om favorieten en zoekmeldingen te gebruiken.',cfg.login));return;}
 const content=el('div');root.append(content);
 async function render(){
  const [favorites,searches,notices,properties]=await Promise.all([api('/favorieten'),api('/zoekopdrachten'),api('/zoekmeldingen'),api('/woningen')]);content.replaceChildren();
  content.append(el('h3','Favoriete woningen'));
  if(!favorites.items.length)content.append(el('p','Je hebt nog geen favoriete woningen.'));
  for(const d of favorites.items){const row=el('article');row.append(link(d.title,d.url),act('Verwijderen',async()=>{await api('/favorieten',{woning_id:d.id,saved:false});await render();}));content.append(row);}
  content.append(el('h3','Woning bewaren'));
  const select=el('select');select.setAttribute('aria-label','Woning kiezen');for(const d of properties){const o=el('option',`${d.title} · ${d.plaats||''}`);o.value=d.id;select.append(o);}content.append(select,act('Bewaar favoriet',async()=>{if(!select.value)throw Error('Er zijn nog geen woningen beschikbaar.');await api('/favorieten',{woning_id:Number(select.value),saved:true});await render();}));
  content.append(el('h3','Zoekopdrachten'),el('p','Meldingen verschijnen hier en in de app voor nieuw passend aanbod. Maximaal 10 zoekopdrachten.'));
  for(const s of searches){const row=el('article',[s.plaats,s.transactie||'Koop en huur',s.woningtype,s.min_prijs===null?'':`vanaf €${s.min_prijs}`,s.max_prijs===null?'':`tot €${s.max_prijs}`,s.enabled?'Meldingen aan':'Meldingen uit'].filter(Boolean).join(' · '));row.append(act(s.enabled?'Pauzeren':'Hervatten',async()=>{await api('/zoekopdrachten',{...s,enabled:!s.enabled});await render();}),act('Verwijderen',async()=>{await api(`/zoekopdrachten/${s.id}/verwijderen`,{});await render();}));content.append(row);}
  const form=el('form'),fields={};for(const [key,label] of [['plaats','Plaats (exact)'],['min_prijs','Minimumprijs'],['max_prijs','Maximumprijs']]){const l=el('label',label),i=el('input');i.name=key;i.type=key==='plaats'?'text':'number';if(i.type==='number'){i.min='0';i.step='0.01';}fields[key]=i;l.append(i);form.append(l);}
  for(const [key,label,values] of [['transactie','Koop / huur',['','Koop','Huur']],['woningtype','Woningtype',['','Woning','Appartement','Kamer','Studio','Nieuwbouw','Bedrijfspand']]]){const l=el('label',label),s=el('select');for(const v of values){const o=el('option',v||'Alle');o.value=v;s.append(o);}fields[key]=s;l.append(s);form.append(l);}
  const enabled=el('input');enabled.type='checkbox';enabled.checked=true;const lab=el('label','Zoekmeldingen in app en website');lab.append(enabled);form.append(lab);
  const save=el('button','Zoekopdracht opslaan');save.type='submit';form.append(save);form.onsubmit=async e=>{e.preventDefault();save.disabled=true;error.textContent='';try{const b={enabled:enabled.checked};for(const [k,v]of Object.entries(fields))b[k]=v.value;await api('/zoekopdrachten',b);await render();}catch(e){error.textContent=e.message;}finally{save.disabled=false;}};content.append(form);
  content.append(el('h3','Zoekmeldingen'));if(!notices.length)content.append(el('p','Nog geen nieuw passend aanbod.'));
  for(const n of notices){const row=el('article');row.append(link(`${n.read?'':'Nieuw: '}${n.title}`,n.url));content.append(row);}if(notices.some(n=>!n.read))content.append(act('Alles gelezen',async()=>{await api('/zoekmeldingen',{confirm:true});await render();}));
 }
 render().catch(e=>{error.textContent=e.message;root.append(act('Opnieuw proberen',render));});
})();
