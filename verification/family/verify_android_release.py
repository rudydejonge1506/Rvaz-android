"""Verify the signed release on Android; never dismiss an RVAZ crash dialog."""
import pathlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET

out = pathlib.Path('evidence')
out.mkdir(exist_ok=True)
package = 'nl.regiovoorneaanzee.rvaz_android'

def adb(*args, check=True):
    return subprocess.run(['adb', *args], check=check, capture_output=True, text=True, timeout=40).stdout

def snapshot(name):
    adb('shell', 'uiautomator', 'dump', '/sdcard/rvaz-screen.xml')
    adb('pull', '/sdcard/rvaz-screen.xml', str(out / (name + '.xml')))
    adb('shell', 'screencap', '-p', '/sdcard/rvaz-screen.png')
    adb('pull', '/sdcard/rvaz-screen.png', str(out / (name + '.png')))
    xml = (out / (name + '.xml')).read_text()
    return xml, ET.fromstring(xml)

def text(root):
    return '\n'.join(n.get('text', '') + '\n' + n.get('content-desc', '') for n in root.iter('node'))

def tap(node):
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.get('bounds', '')))
    adb('shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))

def find(root, label):
    return next((n for n in root.iter('node') if n.get('text', '') == label or n.get('content-desc', '').split('\n')[0] == label), None)

def dismiss_launcher_anr(root):
    title = next((n for n in root.iter('node') if n.get('resource-id') == 'android:id/alertTitle'), None)
    if title is None:
        return False
    value = title.get('text', '')
    if "isn't responding" in value:
        assert value.startswith('Quickstep'), 'Application ANR must fail the release check: ' + value
        close = next(n for n in root.iter('node') if n.get('resource-id') == 'android:id/aerr_close')
        tap(close)
        print('Dismissed the emulator Quickstep launcher ANR only.', flush=True)
        adb('shell', 'am', 'start', '-W', '-n', package + '/.MainActivity')
        return True
    return False

try:
    adb('shell', 'pm', 'grant', package, 'android.permission.POST_NOTIFICATIONS')
    adb('shell', 'am', 'start', '-W', '-n', package + '/.MainActivity')
    retried = False
    for attempt in range(8):
        time.sleep(10)
        xml, root = snapshot('news-attempt-' + str(attempt))
        if dismiss_launcher_anr(root):
            continue
        value = text(root)
        if 'Uitgelicht nieuws:' in value:
            print('Live headline is rendered in the signed Android release.', flush=True)
            snapshot('news-home')
            break
        if 'Nieuws laden is niet gelukt' in value:
            retry = find(root, 'Opnieuw proberen')
            assert not retried and retry is not None, 'Live news failed after retry'
            tap(retry)
            retried = True
    else:
        raise AssertionError('No rendered live headline after the startup checks')

    agenda = find(root, 'Agenda')
    assert agenda is not None, 'Native agenda navigation is missing'
    tap(agenda)
    for attempt in range(6):
        time.sleep(5)
        xml, root = snapshot('agenda-attempt-' + str(attempt))
        value = text(root)
        if 'aankomende evenementen' in value:
            assert 'Evenement aanmelden' in value
            snapshot('agenda-new-layout')
            print('Native agenda dates and submission controls rendered.', flush=True)
            break
    else:
        raise AssertionError('Native agenda did not load')
    news = find(root, 'Nieuws')
    assert news is not None
    tap(news)
    time.sleep(3)
    xml, root = snapshot('news-for-places')
    places = find(root, 'Plaatsen')
    assert places is not None, 'Place directory navigation is missing'
    tap(places)
    time.sleep(2)
    xml, root = snapshot('places-directory')
    assert 'Nieuws per plaats' in text(root)
    rockanje = find(root, 'Rockanje')
    assert rockanje is not None
    tap(rockanje)
    for attempt in range(8):
        time.sleep(5)
        xml, root = snapshot('rockanje-attempt-' + str(attempt))
        if 'Uitgelicht nieuws:' in text(root):
            assert 'Nieuws uit Rockanje' in text(root)
            snapshot('rockanje-news')
            print('Real Rockanje archive rendered in the shared newsroom layout.', flush=True)
            break
    else:
        raise AssertionError('Place archive did not render')
    adb('shell', 'input', 'keyevent', '4')
    time.sleep(2)
    xml, root = snapshot('directory-after-rockanje')
    news = find(root, 'Nieuws')
    assert news is not None
    tap(news)
    time.sleep(2)
    xml, root = snapshot('news-after-places')

    account = find(root, 'Account')
    assert account is not None, 'Permanent account menu is missing'
    tap(account)
    time.sleep(3)
    xml, root = snapshot('account-categorized-menu')
    assert 'Account & menu' in text(root)
    group = find(root, 'Nieuws & plaatsen')
    assert group is not None
    tap(group)
    time.sleep(1)
    xml, root = snapshot('account-news-category')
    family = find(root, 'Familieberichten')
    assert family is not None, 'Family notices are missing from the account menu'
    tap(family)
    for attempt in range(6):
        time.sleep(10)
        xml, root = snapshot('family-attempt-' + str(attempt))
        assert not dismiss_launcher_anr(root), 'Unexpected launcher interruption during family navigation'
        assert not any(n.get('class') == 'android.webkit.WebView' for n in root.iter('node')), 'Family must use native widgets'
        if ('De momenten die ertoe doen' in text(root) and 'Bericht maken' in text(root)
                and ('Er zijn nog geen gepubliceerde familieberichten' in text(root)
                     or 'Lees familiebericht' in text(root))):
            print('Native family cards, filters and account actions rendered without a WebView.', flush=True)
            snapshot('family-page')
            break
    else:
        raise AssertionError('The family page did not load inside the app')

    create = find(root, 'Bericht maken')
    assert create is not None
    tap(create)
    time.sleep(3)
    xml, root = snapshot('family-account-required')
    assert not any(n.get('class') == 'android.webkit.WebView' for n in root.iter('node'))
    assert 'Inloggen' in text(root), 'Submission must open the existing native account login'
    assert 'Familieberichten' in text(root), 'Native account route must retain its app bar'
    assert find(root, 'Back') is not None or find(root, 'Terug') is not None, 'Native account route must have a visible back button'
    adb('shell', 'input', 'keyevent', '4')
    time.sleep(2)
    xml, root = snapshot('family-return')

    account = find(root, 'Account')
    assert account is not None
    tap(account)
    time.sleep(2)
    xml, root = snapshot('all-options-menu')
    search = next((n for n in root.iter('node') if n.get('class') == 'android.widget.EditText'), None)
    assert search is not None, 'The central account menu must be searchable'
    tap(search)
    adb('shell', 'input', 'text', 'vouchers')
    time.sleep(2)
    xml, root = snapshot('vouchers-menu')
    assert 'Vouchers & aanbiedingen' in text(root), 'Public vouchers are missing from the central menu'
    assert 'Mijn vouchers' in text(root), 'Claimed vouchers are missing from the central menu'
    print('The categorized Account menu exposes public and personal vouchers.', flush=True)
    assert adb('shell', 'pidof', package).strip(), 'RVAZ app process stopped'
    print('Signed release checks passed: live news, agenda, place archive, family page, vouchers and persistent navigation.', flush=True)
finally:
    (out / 'device.log').write_text(adb('logcat', '-d', check=False))
