const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch();
 try{
  const page=await browser.newPage();let home=null,uploads=0;
  await page.route('https://rvaz.test/**',async route=>{
   const path=new URL(route.request().url()).pathname;let data=[];
   if(path==='/'){await route.fulfill({contentType:'text/html',body:'<div id="rvaz-private-root"></div><script>window.rvazPrivate={nonce:"test",api:"https://rvaz.test/api",admin:false}</script>'});return;}
   if(path==='/api/particulier/woningen'){
    if(route.request().method()==='POST'){home={...route.request().postDataJSON(),id:12,photos:[]};data=home;}else data=home?[home]:[];
   }else if(path.endsWith('/fotos')){uploads++;home.photos.push({id:uploads,url:`https://rvaz.test/photo${uploads}.png`});data=home;}
   else if(path.endsWith('/galerij')){const ids=route.request().postDataJSON().photo_ids;home.photos=ids.map(id=>home.photos.find(p=>p.id===id));data=home;}
   else if(path.endsWith('/facturen'))data={items:[]};
   await route.fulfill({contentType:'application/json',body:JSON.stringify(data)});
  });
  await page.goto('https://rvaz.test/');
  await page.addStyleTag({path:'website/rvaz-wonen-account-fix/private-website.css'});
  await page.addScriptTag({path:'website/rvaz-wonen-account-fix/private-website.js'});
  await page.getByRole('button',{name:'Nieuwe woning'}).click();
  await page.getByLabel('Huur of koop',{exact:true}).selectOption('Huur');
  await page.getByLabel('Woningtype (woning, appartement of kamer)',{exact:true}).fill('Kamer');
  await page.getByLabel('Borg bij verhuur',{exact:true}).fill('650');
  for(const width of [1000,360]){
   await page.setViewportSize({width,height:900});
   const boxes=await page.locator('.rvaz-private-fields > label').evaluateAll(labels=>labels.map(l=>{const r=l.getBoundingClientRect(),i=l.querySelector('input,textarea,select').getBoundingClientRect();return {x:r.x,y:r.y,right:r.right,bottom:r.bottom,inputTop:i.top,inputRight:i.right};}));
   for(const b of boxes){assert.ok(b.inputTop>b.y+15,'label sits above input');assert.ok(b.right<=width&&b.inputRight<=width,'no horizontal overflow');}
   for(let a=0;a<boxes.length;a++)for(let b=a+1;b<boxes.length;b++){const x=boxes[a],y=boxes[b];assert.ok(x.right<=y.x||y.right<=x.x||x.bottom<=y.y||y.bottom<=x.y,'fields do not overlap');}
   if(width===360)assert.ok(boxes.every(b=>Math.abs(b.x-boxes[0].x)<1),'mobile uses one field column');
  }
  await page.screenshot({path:'/tmp/rvaz-private-form-mobile.png',fullPage:true});
  await page.setViewportSize({width:1000,height:900});
  await page.screenshot({path:'/tmp/rvaz-private-form-desktop.png',fullPage:true});
  console.log('PASS: private account form desktop/mobile labels, spacing and no overflow');
  const input=page.getByLabel('Foto’s toevoegen',{exact:true});
  assert.equal(await input.getAttribute('multiple'),'','photo picker available before first save');
  await input.setInputFiles([{name:'voorzijde.png',mimeType:'image/png',buffer:Buffer.from('test')},{name:'tuin.png',mimeType:'image/png',buffer:Buffer.from('test')}]);
  await page.getByLabel('Titel',{exact:true}).fill('Mijn verkoopwoning');
  await page.getByRole('button',{name:'Woning en foto’s opslaan'}).click();
  await page.getByText('Hoofdfoto',{exact:true}).waitFor();
  assert.equal(uploads,2,'both selected files uploaded');
  assert.equal(home.title,'Mijn verkoopwoning');
  assert.equal(home.transactie,'Huur');
  assert.equal(home.woningtype,'Kamer');
  assert.equal(home.borg,'650');
  await page.getByRole('button',{name:'Als hoofdfoto'}).click();
  await page.waitForFunction(()=>document.querySelector('article img')?.src.endsWith('photo2.png'));
  assert.equal(home.photos[0].id,2,'chosen photo moves to cover');
  await page.getByRole('button',{name:'Foto verwijderen'}).last().click();
  await page.waitForFunction(()=>document.querySelectorAll('article img').length===1);
  assert.equal(home.photos.length,1,'photo removal persisted');
  console.log('PASS: private photo picker before save, multiple uploads, saved fields, cover selection and removal');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
