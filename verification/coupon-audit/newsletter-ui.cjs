const {chromium}=require('playwright');
const fs=require('node:fs');const assert=require('node:assert/strict');
(async()=>{const browser=await chromium.launch();try{const page=await browser.newPage();await page.route('**/*',route=>route.abort());
 for(const kind of ['broker','regular']){const html=fs.readFileSync(`/tmp/rvaz-newsletter-${kind}.html`,'utf8');
  for(const width of [360,1000]){await page.setViewportSize({width,height:900});await page.setContent(html);assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'newsletter has no horizontal overflow');
   const links=await page.locator('a').evaluateAll(nodes=>nodes.map(a=>({text:a.textContent,url:a.getAttribute('href')})));assert.ok(links.some(a=>a.url.includes('/wonen-voor-makelaars/')));
   if(kind==='broker'){assert.equal(await page.getByText('MAKELAAR',{exact:true}).count(),1);assert.ok(await page.getByRole('link',{name:'Aanmelden als makelaar'}).isVisible());assert.equal(await page.locator('ol > li').count(),4);}
   else assert.equal(await page.getByRole('heading',{name:'Wonen op Voorne',exact:true}).count(),1);
   await page.screenshot({path:`/tmp/rvaz-newsletter-${kind}-${width}.png`,fullPage:true});
  }console.log(`PASS: ${kind} actual email render on desktop and mobile, links and no overflow`);
 }
 // Existing broker website form uses the same transaction visibility rule.
 await page.setContent('<form><label>Koop / huur<select name="transactie"><option>Koop</option><option>Huur</option></select></label><label>Borg<input name="borg" value="650"></label><label>Contractduur<input name="contractduur"></label><label>Inkomen<textarea name="inkomenseisen"></textarea></label><label>Prijsconditie<select name="prijstype"><option>k.k.</option></select></label></form>');
 await page.addStyleTag({content:'[data-rvaz-housing-hidden]{display:none!important}'});await page.addScriptTag({path:'website/rvaz-wonen-account-fix/housing-fields.js'});
 assert.equal(await page.getByLabel('Borg').isVisible(),false);await page.locator('select[name=transactie]').selectOption('Huur');assert.equal(await page.getByLabel('Borg').isVisible(),true);assert.equal(await page.getByLabel('Prijsconditie').isVisible(),false);await page.locator('select[name=transactie]').selectOption('Koop');assert.equal(await page.getByLabel('Borg').isVisible(),false);assert.equal(await page.getByLabel('Borg').inputValue(),'650');
 console.log('PASS: broker website rental visibility and retained values');
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exit(1);});
