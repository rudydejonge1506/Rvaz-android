(function () {
  function replaceWeekblad() {
    var nav = document.querySelector('.mainnav .navlinks');
    if (!nav) return;
    var link = Array.from(nav.querySelectorAll('a')).find(function (a) {
      return new URL(a.href, window.location.href).pathname.replace(/\/$/, '') === '/weekblad';
    });
    if (!link) return;
    var icon = document.createElement('span');
    icon.className = 'dashicons dashicons-admin-home';
    icon.setAttribute('aria-hidden', 'true');
    link.replaceChildren(icon, document.createTextNode('WONEN'));
    link.href = '/wonen/';
    link.setAttribute('aria-label', 'Wonen');
    link.removeAttribute('aria-current');
    if (window.location.pathname.replace(/\/$/, '') === '/wonen') link.setAttribute('aria-current', 'page');
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', replaceWeekblad, { once: true });
  else replaceWeekblad();
})();
