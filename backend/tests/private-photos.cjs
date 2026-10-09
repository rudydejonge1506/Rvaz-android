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
  await page.addScriptTag({path:'backend/rvaz-wonen-native-api/private-website.js'});
  await page.getByRole('button',{name:'Nieuwe woning'}).click();
  const input=page.getByLabel('Foto’s toevoegen',{exact:true});
  assert.equal(await input.getAttribute('multiple'),'','photo picker available before first save');
  await input.setInputFiles([{name:'voorzijde.png',mimeType:'image/png',buffer:Buffer.from('test')},{name:'tuin.png',mimeType:'image/png',buffer:Buffer.from('test')}]);
  await page.getByLabel('Titel',{exact:true}).fill('Mijn verkoopwoning');
  await page.getByRole('button',{name:'Woning en foto’s opslaan'}).click();
  await page.getByText('Hoofdfoto',{exact:true}).waitFor();
  assert.equal(uploads,2,'both selected files uploaded');
  assert.equal(home.title,'Mijn verkoopwoning');
  await page.getByRole('button',{name:'Als hoofdfoto'}).click();
  await page.waitForFunction(()=>document.querySelector('article img')?.src.endsWith('photo2.png'));
  assert.equal(home.photos[0].id,2,'chosen photo moves to cover');
  await page.getByRole('button',{name:'Foto verwijderen'}).last().click();
  await page.waitForFunction(()=>document.querySelectorAll('article img').length===1);
  assert.equal(home.photos.length,1,'photo removal persisted');
  console.log('PASS: private photo picker before save, multiple uploads, saved fields, cover selection and removal');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
