const { chromium } = require('playwright');
const fs = require('node:fs');
const assert = require('node:assert/strict');
(async () => {
 const browser = await chromium.launch();
 try {
  const page = await browser.newPage();
  const labels = ['Overzicht','Mijn Wonen','Mijn berichten','Evenementen','Foto insturen','Mijn bedrijf','Advertenties','Facturen','Profiel','Wachtwoord','Nieuwsbrief','Beheer','Uitloggen'];
  await page.setContent(`<style>*{box-sizing:border-box}body{margin:0}.rvaz-account-grid{display:grid;grid-template-columns:235px minmax(0,1fr)}.rvaz-account-nav a{display:flex;padding:11px;color:#28475e}.rvaz-account-nav{border:1px solid #ddd}.rvaz-account-content{min-width:0}@media(max-width:700px){.rvaz-account-grid{grid-template-columns:1fr}.rvaz-account-nav{display:flex;overflow:auto}.rvaz-account-nav a{white-space:nowrap}}</style><div class="rvaz-account-grid"><nav class="rvaz-account-nav">${labels.map((label,i)=>`<a href="?section=${i}" ${label==='Facturen'?'class="is-active" aria-current="page"':''}><span class="rvaz-nav-icon">•</span>${label}</a>`).join('')}<div class="rvaz-nav-separator"></div></nav><main class="rvaz-account-content"><h1>Mijn account</h1><form><input value="Onopgeslagen tekst"></form></main></div>`);
  await page.evaluate(() => { window.originalLinks = [...document.querySelectorAll('nav a')]; window.originalMain = document.querySelector('main').innerHTML; window.clicks = 0; originalLinks[0].addEventListener('click', e => { e.preventDefault(); clicks++; }); });
  await page.addStyleTag({path:'backend/rvaz-wonen-native-api/account-dashboard.css'});
  await page.addScriptTag({path:'backend/rvaz-wonen-native-api/account-dashboard.js'});
  assert.equal(await page.locator('nav a').count(),labels.length);
  assert.equal(await page.evaluate(() => originalLinks.every(link => link.isConnected)),true,'all original links retained');
  assert.equal(await page.evaluate(() => document.querySelector('main').innerHTML === originalMain),true,'account form untouched');
  assert.equal(await page.locator('details[open] summary').textContent(),'Zakelijk');
  assert.equal(await page.locator('nav > a').count(),2,'overview and Mijn Wonen remain directly accessible');
  await page.locator('nav > a').first().click();
  assert.equal(await page.evaluate(() => clicks),1,'original listeners retained');
  const account = page.locator('summary').filter({hasText:'Account'});
  await account.focus(); await page.keyboard.press('Enter');
  assert.equal(await page.locator('details[open]').count(),2,'keyboard opens account group');
  await page.addScriptTag({path:'backend/rvaz-wonen-native-api/account-dashboard.js'});
  assert.equal(await page.locator('nav a').count(),labels.length,'reinitialization does not duplicate links');
  await page.setViewportSize({width:375,height:812});
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),true,'mobile page has no horizontal overflow');
  console.log('PASS: dashboard links, permissions-preserving DOM, form, listeners, keyboard, active group, idempotency and mobile width');
 } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
