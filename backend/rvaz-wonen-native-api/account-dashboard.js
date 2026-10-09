(() => {
 'use strict';
 document.querySelectorAll('.rvaz-account-nav').forEach(nav => {
  if (nav.dataset.rvazOrganized) return;
  const links = Array.from(nav.children).filter(el => el.matches('a'));
  if (links.length < 7) return;
  nav.dataset.rvazOrganized = 'true';
  nav.classList.add('rvaz-account-organized');
  const groups = new Map(['Wonen', 'Mijn bijdragen', 'Zakelijk', 'Account', 'Meer mogelijkheden'].map(label => [label, []]));
  const main = [];
  links.forEach(link => {
   const label = link.textContent.trim().toLowerCase();
   if (/uitloggen|afmelden/.test(label)) groups.get('Account').push(link);
   else if (/dashboard|overzicht|mijn rvaz/.test(label) || /^\W*mijn wonen\s*$/.test(label)) main.push(link);
   else if (/woning|wonen|makelaar|zoekmelding|favoriet/.test(label)) groups.get('Wonen').push(link);
   else if (/bedrij|advertent|voucher|vacature|zakelijk|factu|abonnement/.test(label)) groups.get('Zakelijk').push(link);
   else if (/profiel|account|wachtwoord|instelling|melding|nieuwsbrief/.test(label)) groups.get('Account').push(link);
   else if (/bericht|reactie|evenement|agenda|foto|nieuws|bijdrag|inzend/.test(label)) groups.get('Mijn bijdragen').push(link);
   else groups.get('Meer mogelijkheden').push(link);
  });
  // Keep the original anchors, listeners, badges, hrefs and role visibility.
  links.forEach(link => link.remove());
  nav.querySelectorAll('.rvaz-nav-separator').forEach(el => el.remove());
  const heading = document.createElement('p');
  heading.className = 'rvaz-account-menu-heading';
  heading.textContent = 'Mijn RVAZ';
  nav.prepend(heading);
  main.forEach(link => nav.append(link));
  groups.forEach((items, label) => {
   if (!items.length) return;
   const section = document.createElement('details');
   const summary = document.createElement('summary');
   summary.textContent = label;
   section.append(summary);
   items.forEach(link => {
    section.append(link);
    if (link.classList.contains('is-active') || link.getAttribute('aria-current') === 'page') section.open = true;
   });
   nav.append(section);
  });
 });
})();
