import base64
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from check_android_branding import configure as check_android
from configure_signing import configure as signing, property_value
from resolve_build import resolve, STAGING_URL
from verify_bundle_manifest import verify

ROOT = Path(__file__).resolve().parents[2]

class ReleaseTests(unittest.TestCase):
    def test_committed_android_identity_and_security(self):
        check_android(ROOT)

    def test_generated_template_activity_is_removed_without_touching_custom_code(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            shutil.copytree(ROOT/'android',root/'android')
            stub=root/'android/app/src/main/kotlin/hu/madtech/hunor_app/MainActivity.kt'
            stub.parent.mkdir(parents=True)
            stub.write_text('package hu.madtech.hunor_app\n\nimport io.flutter.embedding.android.FlutterActivity\n\nclass MainActivity : FlutterActivity()\n')
            check_android(root)
            self.assertFalse(stub.exists())
            stub.write_text('package hu.madtech.hunor_app\n// Custom native implementation\nclass MainActivity {}')
            with self.assertRaises(ValueError): check_android(root)
            self.assertTrue(stub.exists())

    def test_missing_secrets_fail_before_creating_files(self):
        with tempfile.TemporaryDirectory() as d,patch.dict(os.environ,{},clear=True):
            with self.assertRaises(SystemExit): signing(Path(d))
            self.assertFalse((Path(d)/'android/key.properties').exists())

    def test_properties_escape_special_characters(self):
        self.assertEqual(property_value('a\\b\nc'),r'a\\b\nc')
        self.assertEqual(property_value('x=y:z'),r'x\=y\:z')
        self.assertEqual(property_value('á'),r'\u00e1')
        self.assertEqual(property_value(' leading'),r'\ leading')

    def test_existing_secret_payload_is_preserved(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'android/app').mkdir(parents=True)
            fake={'ANDROID_KEYSTORE_BASE64':base64.b64encode(b'FICTITIOUS-TEST-ONLY').decode(),
                  'ANDROID_KEYSTORE_PASSWORD':'fake-test-password','ANDROID_KEY_ALIAS':'fake-test-alias','ANDROID_KEY_PASSWORD':'fake-test-password'}
            with patch.dict(os.environ,fake,clear=True): signing(root)
            self.assertEqual((root/'android/app/release.keystore').read_bytes(),b'FICTITIOUS-TEST-ONLY')
            self.assertIn('storeFile=release.keystore\n',(root/'android/key.properties').read_text())

    def test_staging_resolves_exact_approved_endpoint(self):
        result=resolve({'INPUT_TARGET_ENV':'staging','INPUT_BUILD_NUMBER':'10001','INPUT_VERSION_NAME':'1.0.0'})
        self.assertEqual(result['BUILD_API_URL'],STAGING_URL)
        self.assertEqual(result['BUILD_NUMBER'],'10001')
        with self.assertRaises(ValueError): resolve({'STAGING_API_URL':'https://wrong.example.invalid'})

    def test_production_has_no_staging_or_missing_url_fallback(self):
        for env in [{'INPUT_TARGET_ENV':'production'},{'INPUT_TARGET_ENV':'production','PRODUCTION_API_URL':STAGING_URL}]:
            with self.assertRaises(ValueError): resolve(env)
        self.assertEqual(resolve({'INPUT_TARGET_ENV':'production','PRODUCTION_API_URL':'https://api.example.invalid/v1'})['TARGET_ENV'],'production')

    def test_build_inputs_cannot_inject_shell_or_environment_lines(self):
        for env in [{'INPUT_BUILD_NUMBER':'1; echo no'},{'INPUT_VERSION_NAME':'1.0.0\nBAD=1'},{'INPUT_TARGET_ENV':'unknown'},{'INPUT_BUILD_NUMBER':'2100000001'}]:
            with self.assertRaises(ValueError): resolve(env)

    def manifest(self,package='hu.madtech.rescue',version='1.0.0'):
        return f'<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{package}" android:versionCode="10001" android:versionName="{version}"><application android:allowBackup="false" android:usesCleartextTraffic="false"><activity android:name="hu.madtech.rescue.MainActivity"/></application></manifest>'

    def test_actual_bundle_identity_and_version_required(self):
        self.assertEqual(verify(self.manifest(),'10001','1.0.0')['package_id'],'hu.madtech.rescue')
        for xml in [self.manifest(package='hu.hunor.app'),self.manifest(version='0.9.0'),self.manifest().replace('allowBackup="false"','allowBackup="true"'),self.manifest().replace('<application ','<application android:debuggable="true" ')]:
            with self.assertRaises(ValueError): verify(xml,'10001','1.0.0')

if __name__=='__main__': unittest.main()
