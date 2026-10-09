(function () {
  'use strict';
  function el(tag, className, text) {
    var n = document.createElement(tag);
    if (className) n.className = className;
    if (text !== undefined) n.textContent = text;
    return n;
  }
  function anchor(text, href, className) {
    var n = el('a', className, text); n.href = href; return n;
  }
  function safeUrl(value) {
    if (typeof value !== 'string' || !value.trim()) return '';
    try { var u = new URL(value, window.location.href); return /^(https?:)$/.test(u.protocol) ? u.href : ''; }
    catch (_) { return ''; }
  }
  function navigation() {
    var nav = document.querySelector('.mainnav .navlinks');
    if (!nav || nav.querySelector('[data-rvaz-wonen-nav]')) return;
    var old = Array.from(nav.querySelectorAll('a')).find(function (a) {
      return new URL(a.href, window.location.href).pathname.replace(/\/$/, '') === '/weekblad';
    });
    if (!old) return;
    var item = el('div', 'nav-item has-submenu rvaz-wonen-nav');
    item.setAttribute('data-rvaz-wonen-nav', '1');
    var link = anchor('', '/wonen/');
    var icon = el('span', 'dashicons dashicons-admin-home'); icon.setAttribute('aria-hidden', 'true');
    link.append(icon, document.createTextNode('WONEN'));
    if (window.location.pathname.replace(/\/$/, '') === '/wonen') link.setAttribute('aria-current', 'page');
    var toggle = el('button', 'rvaz-wonen-toggle', '▾');
    toggle.type = 'button'; toggle.setAttribute('aria-label', 'Wonen submenu'); toggle.setAttribute('aria-expanded', 'false'); toggle.setAttribute('aria-controls', 'rvaz-wonen-submenu');
    var sub = el('div', 'submenu'); sub.id = 'rvaz-wonen-submenu'; sub.setAttribute('aria-label', 'Wonen');
    sub.append(anchor('Woningen bekijken', '/wonen/'), anchor('Aanmelden als makelaar', '/wonen-voor-makelaars/'), anchor('Abonnementen & tarieven', '/wonen-tarieven/'), anchor('Inloggen voor makelaars', '/mijn-wonen/'));
    toggle.addEventListener('click', function () { var opened = item.classList.toggle('open'); toggle.setAttribute('aria-expanded', String(opened)); });
    item.addEventListener('keydown', function (e) { if (e.key === 'Escape') { item.classList.remove('open'); toggle.setAttribute('aria-expanded', 'false'); toggle.focus(); } });
    item.append(link, toggle, sub); old.replaceWith(item);
  }
  function price(d) {
    var raw = String(d.prijs || '').trim();
    if (!raw) return 'Prijs op aanvraag';
    var numeric = /^\d+(?:[.,]\d{1,2})?$/.test(raw) ? Number(raw.replace(',', '.')) : null;
    var label = numeric !== null ? new Intl.NumberFormat('nl-NL', { style: 'currency', currency: 'EUR', maximumFractionDigits: 2 }).format(numeric) : (raw.indexOf('€') >= 0 ? raw : '€ ' + raw);
    return label + (d.prijstype ? ' ' + d.prijstype : (String(d.transactie || '').toLowerCase() === 'huur' ? ' per maand' : ''));
  }
  function home() {
    var old = document.querySelector('.home-middle-grid .home-weekblad');
    if (!old) return;
    var section = el('section', 'home-wonen');
    var heading = el('div', 'section-head'); heading.append(el('h2', '', 'Uitgelichte woningen'), anchor('Alle woningen →', '/wonen/'));
    var cards = el('div', 'rvaz-home-woningen'); cards.setAttribute('aria-live', 'polite'); cards.append(el('p', 'rvaz-wonen-message', 'Woningaanbod laden…'));
    section.append(heading, cards); old.replaceWith(section);
    function message(text) { cards.replaceChildren(el('p', 'rvaz-wonen-message', text), anchor('Bekijk Wonen →', '/wonen/', 'rvaz-wonen-cta'), anchor('Inloggen voor makelaars', '/mijn-wonen/', 'rvaz-wonen-login')); }
    var controller = new AbortController(); var timer = window.setTimeout(function () { controller.abort(); }, 10000);
    fetch('/wp-json/rvaz-wonen/v1/woningen', { credentials: 'omit', signal: controller.signal }).then(function (r) { if (!r.ok) throw new Error('Woningaanbod niet beschikbaar'); return r.json(); }).then(function (data) {
      if (!Array.isArray(data)) throw new Error('Ongeldig woningaanbod');
      var rows = data.filter(function (d) { return safeUrl(d.url); }).slice(0, 3);
      if (!rows.length) { message('Binnenkort vind je hier koop- en huurwoningen op Voorne aan Zee.'); return; }
      cards.replaceChildren();
      rows.forEach(function (d) {
        var card = anchor('', safeUrl(d.url), 'rvaz-home-woning');
        var photo = safeUrl(d.image);
        if (photo) { var img = el('img'); img.src = photo; img.alt = ''; img.loading = 'lazy'; card.append(img); }
        else { var fallback = el('span', 'rvaz-woning-no-photo'); var icon = el('span', 'dashicons dashicons-admin-home'); icon.setAttribute('aria-hidden', 'true'); fallback.append(icon); card.append(fallback); }
        var copy = el('div', 'rvaz-home-woning-copy');
        copy.append(el('small', 'rvaz-woning-type', d.transactie || 'Woning'), el('h3', '', d.adres || d.title || 'Woning'), el('p', 'rvaz-woning-place', [d.postcode, d.plaats].filter(Boolean).join(' ')), el('strong', 'rvaz-woning-price', price(d)));
        var facts = []; if (d.woonoppervlak) facts.push(d.woonoppervlak + ' m²'); if (d.kamers) facts.push(d.kamers + ' kamers'); if (d.energielabel) facts.push('Label ' + d.energielabel);
        if (facts.length) copy.append(el('p', 'rvaz-woning-facts', facts.join(' · ')));
        card.append(copy); cards.append(card);
      });
    }).catch(function () { message('Het woningaanbod kan nu niet worden geladen. Bekijk Wonen voor het actuele aanbod.'); }).finally(function () { window.clearTimeout(timer); });
  }
  function init() {
    if (!document.getElementById('rvaz-wonen-site-style')) {
      var style = el('style'); style.id = 'rvaz-wonen-site-style';
      style.textContent = '.rvaz-wonen-nav{position:relative;display:flex;align-items:center}.rvaz-wonen-toggle{border:0;background:transparent;color:inherit;padding:12px 8px;cursor:pointer}.rvaz-wonen-toggle:focus-visible{outline:2px solid currentColor;outline-offset:2px}.rvaz-wonen-nav.open>.submenu,.rvaz-wonen-nav:focus-within>.submenu{display:block}.rvaz-home-woningen{display:grid;gap:12px}.rvaz-home-woning{display:grid;grid-template-columns:120px minmax(0,1fr);overflow:hidden;border:1px solid #dfe7ee;border-radius:12px;background:#fff;text-decoration:none;color:#203253}.rvaz-home-woning>img,.rvaz-woning-no-photo{width:120px;height:100%;min-height:140px;object-fit:cover;background:#edf6fb}.rvaz-woning-no-photo{display:flex;align-items:center;justify-content:center}.rvaz-woning-no-photo .dashicons{font-size:40px;width:40px;height:40px}.rvaz-home-woning-copy{padding:14px;min-width:0}.rvaz-home-woning h3{font-size:17px;margin:4px 0;overflow-wrap:anywhere}.rvaz-woning-type{font-weight:700;color:#008ac8}.rvaz-woning-place,.rvaz-woning-facts{font-size:12px;color:#617087;margin:5px 0}.rvaz-woning-price{display:block;font-size:16px}.rvaz-wonen-message{padding:24px;margin:0;background:#fff;border:1px solid #dfe7ee;border-radius:12px;line-height:1.6}.rvaz-wonen-cta{justify-self:start;background:#008ac8;color:#fff;padding:12px 18px;border-radius:8px;text-decoration:none;font-weight:700}.rvaz-wonen-login{font-size:13px}@media(max-width:900px){.rvaz-wonen-nav{flex-wrap:wrap}.rvaz-wonen-nav>.submenu{width:100%}.rvaz-wonen-nav>a{flex:1}}@media(max-width:420px){.rvaz-home-woning{grid-template-columns:95px minmax(0,1fr)}.rvaz-home-woning>img,.rvaz-woning-no-photo{width:95px}}';
      document.head.append(style);
    }
    navigation(); home();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
})();
