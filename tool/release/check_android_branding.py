"""Validate the regenerated Android shell without touching Dart/API/Google configs."""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

PACKAGE = 'hu.madtech.rescue'
ANDROID = '{http://schemas.android.com/apk/res/android}'

def configure(root: Path):
    gradle = root / 'android/app/build.gradle.kts'
    text = gradle.read_text(encoding='utf-8-sig')
    for key in ('namespace', 'applicationId'):
        if re.findall(r'\b' + key + r'\s*=\s*"([^"]+)"', text) != [PACKAGE]:
            raise ValueError(f'{key} must be exactly {PACKAGE}')
    if 'signingConfig = signingConfigs.getByName("debug")' in text:
        raise ValueError('Release must not use debug signing')
    manifest = ET.parse(root / 'android/app/src/main/AndroidManifest.xml').getroot()
    app = manifest.find('application')
    if app.get(ANDROID + 'allowBackup') != 'false' or app.get(ANDROID + 'usesCleartextTraffic') != 'false':
        raise ValueError('Android security settings changed')
    if app.get(ANDROID + 'label') != '@string/app_name':
        raise ValueError('Launcher label must use app_name')
    if app.find('activity').get(ANDROID + 'name') != PACKAGE + '.MainActivity':
        raise ValueError('Launcher activity package mismatch')
    if ET.parse(root / 'android/app/src/main/res/values/strings.xml').find("string[@name='app_name']").text != 'MADtech Rescue':
        raise ValueError('Launcher label mismatch')
    expected = root / 'android/app/src/main/kotlin/hu/madtech/rescue/MainActivity.kt'
    if not re.search(r'^package hu\.madtech\.rescue\s*$', expected.read_text(encoding='utf-8-sig'), re.M):
        raise ValueError('MainActivity package mismatch')
    # flutter create may add a second template Activity. Only remove that exact
    # generated stub; never overwrite an existing native implementation.
    for activity in (root / 'android/app/src/main').rglob('MainActivity.kt'):
        if activity == expected:
            continue
        relative = activity.relative_to(root).as_posix()
        allowed = {'android/app/src/main/kotlin/hu/madtech/hunor_app/MainActivity.kt',
                   'android/app/src/main/kotlin/hu/hunor/hunor_app/MainActivity.kt'}
        stub = activity.read_text(encoding='utf-8-sig')
        if relative not in allowed or not re.fullmatch(r'package [\w.]+\s+import io\.flutter\.embedding\.android\.FlutterActivity\s+class MainActivity\s*:\s*FlutterActivity\(\)\s*', stub):
            raise ValueError('Unexpected native Activity; refusing to delete it')
        activity.unlink()
    if len(list((root / 'android/app/src/main').rglob('MainActivity.kt'))) != 1:
        raise ValueError('Expected one MainActivity')
    print('Android package, namespace, Activity, label and security checks: OK')

if __name__ == '__main__':
    configure(Path(sys.argv[1] if len(sys.argv) > 1 else '.'))
