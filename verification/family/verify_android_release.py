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

    family = find(root, 'Familie')
    assert family is not None, 'Permanent family navigation is missing'
    tap(family)
    for attempt in range(6):
        time.sleep(10)
        xml, root = snapshot('family-attempt-' + str(attempt))
        assert not dismiss_launcher_anr(root), 'Unexpected launcher interruption during family navigation'
        assert not any(n.get('class') == 'android.webkit.WebView' for n in root.iter('node')), 'Family must use native widgets'
        if 'De momenten die ertoe doen' in text(root) and 'Bericht maken' in text(root):
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
    adb('shell', 'input', 'keyevent', '4')
    time.sleep(2)
    xml, root = snapshot('family-return')

    menu = find(root, 'Menu')
    assert menu is not None, 'Native menu button is missing'
    tap(menu)
    width, height = map(int, re.findall(r'(\d+)x(\d+)', adb('shell', 'wm', 'size'))[0])
    for attempt in range(5):
        time.sleep(2)
        xml, root = snapshot('menu-attempt-' + str(attempt))
        if find(root, 'Vouchers') is not None:
            print('Vouchers is available in the native menu.', flush=True)
            snapshot('vouchers-menu')
            break
        adb('shell', 'input', 'swipe', str(width // 3), str(height * 3 // 4), str(width // 3), str(height // 3), '400')
    else:
        raise AssertionError('Vouchers is missing from the menu')
    assert adb('shell', 'pidof', package).strip(), 'RVAZ app process stopped'
    print('Signed release checks passed: live news, family page, vouchers and persistent navigation.', flush=True)
finally:
    (out / 'device.log').write_text(adb('logcat', '-d', check=False))
