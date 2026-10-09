(function () {
  'use strict';
  function addAppDownloads() {
    var rail = document.querySelector('.site-rail');
    if (!rail || rail.querySelector('.rvaz-sidebar-app')) return;
    var section = document.createElement('section');
    section.className = 'rail-block rvaz-sidebar-app';
    section.setAttribute('aria-label', 'Download de RVAZ-app');
    var title = document.createElement('h2'); title.textContent = 'Download de RVAZ-app';
    var intro = document.createElement('p'); intro.textContent = 'Lokaal nieuws, 112 en activiteiten op je telefoon.';
    var buttons = document.createElement('div'); buttons.className = 'rvaz-sidebar-app-buttons';
    var stores = [
      {label: 'iPhone / iPad', note: 'App Store', url: 'https://apps.apple.com/app/regio-voorne-aan-zee/id6817375521', icon: 'M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.79 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.53 4.1zM12.03 7.25C11.88 5.02 13.69 3.18 15.77 3c.29 2.58-2.34 4.5-3.74 4.25z'},
      {label: 'Android', note: 'Testversie', url: '/test-de-rvaz-app/', icon: 'M3.6 2.4c-.38.4-.6 1.02-.6 1.8v15.6c0 .78.22 1.4.6 1.8l.08.07L12.42 12 3.68 2.33l-.08.07zm11.73 6.37L5.06 2.93l8.1 8.1 2.17-2.26zm3.61 2.05-2.39-1.36-2.52 2.54 2.52 2.54 2.4-1.36c.68-.39.68-1.97-.01-2.36zm-13.88 10.25 10.27-5.84-2.17-2.26-8.1 8.1z'}
    ];
    stores.forEach(function (store) {
      var link = document.createElement('a'); link.className = 'rvaz-sidebar-store'; link.href = store.url;
      link.setAttribute('aria-label', store.label + ' — ' + store.note);
      if (store.url.indexOf('https://') === 0) { link.target = '_blank'; link.rel = 'noopener'; }
      var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg'); svg.setAttribute('viewBox', '0 0 24 24'); svg.setAttribute('aria-hidden', 'true'); svg.setAttribute('focusable', 'false');
      var path = document.createElementNS('http://www.w3.org/2000/svg', 'path'); path.setAttribute('fill', 'currentColor'); path.setAttribute('d', store.icon); svg.appendChild(path);
      var copy = document.createElement('span'); var name = document.createElement('strong'); name.textContent = store.label; var note = document.createElement('small'); note.textContent = store.note; copy.append(name, note);
      link.append(svg, copy); buttons.appendChild(link);
    });
    section.append(title, intro, buttons); rail.prepend(section);
    var style = document.createElement('style');
    style.textContent = '.site-rail .rvaz-sidebar-app{padding:20px;background:#fff;border:1px solid #dfe7ee;border-radius:14px}.rvaz-sidebar-app h2{font-size:19px;line-height:1.3;margin:0 0 8px;color:#203253}.rvaz-sidebar-app p{font-size:13px;line-height:1.5;color:#617087;margin:0 0 16px}.rvaz-sidebar-app-buttons{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.rvaz-sidebar-store{display:flex;align-items:center;justify-content:center;gap:8px;padding:13px 8px;min-height:65px;border-radius:9px;text-decoration:none;background:#203253;color:#fff!important}.rvaz-sidebar-store:hover{background:#008ac8}.rvaz-sidebar-store:focus-visible{outline:3px solid #008ac8;outline-offset:3px}.rvaz-sidebar-store svg{width:27px;height:27px;flex:none}.rvaz-sidebar-store strong{display:block;font-size:12px;line-height:1.3}.rvaz-sidebar-store small{display:block;font-size:11px;line-height:1.5;opacity:.85}@media(max-width:360px){.rvaz-sidebar-app-buttons{grid-template-columns:1fr}}';
    document.head.appendChild(style);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', addAppDownloads, {once:true});
  else addAppDownloads();
})();
