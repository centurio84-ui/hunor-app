import json
import os
from pathlib import Path
import xml.etree.ElementTree as ET

ANDROID = '{http://schemas.android.com/apk/res/android}'

def verify(xml, number, version):
    manifest = ET.fromstring(xml)
    if manifest.get('package') != 'hu.madtech.rescue':
        raise ValueError('Final AAB package ID mismatch')
    if manifest.get(ANDROID+'versionCode') != number or manifest.get(ANDROID+'versionName') != version:
        raise ValueError('Final AAB version mismatch')
    app = manifest.find('application')
    if app.get(ANDROID+'debuggable', 'false') not in ('false','0'):
        raise ValueError('Debuggable release rejected')
    if app.get(ANDROID+'allowBackup') not in ('false','0') or app.get(ANDROID+'usesCleartextTraffic') not in ('false','0'):
        raise ValueError('Final AAB security attributes changed')
    if not any(a.get(ANDROID+'name') == 'hu.madtech.rescue.MainActivity' for a in app.findall('activity')):
        raise ValueError('Final launcher Activity mismatch')
    return {'package_id':manifest.get('package'), 'version_name':version, 'build_number':int(number)}

if __name__ == '__main__':
    root=Path('build/app/outputs/bundle/release')
    info=verify((root/'AndroidManifest.verified.xml').read_text(encoding='utf-8'),os.environ['BUILD_NUMBER'],os.environ['VERSION_NAME'])
    info.update({'display_name':'MADtech Rescue','play_name':'MADtech Rescue Platform','developer_brand':'MADtech',
                 'parent_brand':'MAD – Moldován András Division','product':'Rescue Platform','default_listing_language':'hu-HU',
                 'environment':os.environ['TARGET_ENV'],'commit_sha':os.environ['GITHUB_SHA'],
                 'reference_release_commit':'086caf4949841dd803f9d8319220e837e3d21da8'})
    (root/'BUILDINFO.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Final AAB identity, version and Android security attributes: OK')
