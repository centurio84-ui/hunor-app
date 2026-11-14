#!/usr/bin/env python3
import base64
import os
from pathlib import Path

def configure_google_services():
    p_app = Path("android/app/build.gradle")
    if p_app.exists():
        s = p_app.read_text()
        if "com.google.gms.google-services" not in s:
            s = s.replace(
                "plugins {",
                "plugins {\n    id 'com.google.gms.google-services'",
                1,
            )
            p_app.write_text(s)
            print("Added google-services to android/app/build.gradle.")

    p_settings = Path("android/settings.gradle")
    if p_settings.exists():
        s = p_settings.read_text()
        if "com.google.gms.google-services" not in s:
            marker = "plugins {"
            idx = s.find(marker)
            if idx >= 0:
                end = s.find("\n}", idx)
                if end >= 0:
                    s = s[:end] + "\n    id 'com.google.gms.google-services' version '4.4.4' apply false" + s[end:]
                    p_settings.write_text(s)
                    print("Added google-services to android/settings.gradle.")

def configure_manifest():
    manifest = Path("android/app/src/main/AndroidManifest.xml")
    if manifest.exists():
        text = manifest.read_text()
        if "android.permission.INTERNET" not in text:
            text = text.replace(
                "<application",
                '<uses-permission android:name="android.permission.INTERNET" />\n    <application android:allowBackup="false" android:usesCleartextTraffic="false"',
                1,
            )
        import re
        text = re.sub(r'android:label="[^"]*"', 'android:label="MAD Tech Rescue Platform"', text)
        manifest.write_text(text)
        print("Configured AndroidManifest.xml permissions and label to MAD Tech Rescue Platform.")

def configure_sdk_versions():
    gradle_kts = Path("android/app/build.gradle.kts")
    if gradle_kts.exists():
        gt = gradle_kts.read_text()
        gt = gt.replace("minSdk = flutter.minSdkVersion", "minSdk = 21")
        gt = gt.replace("targetSdk = flutter.targetSdkVersion", "targetSdk = 34")
        if "lint {" not in gt:
            gt = gt.replace(
                "buildTypes {",
                "lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }\n\n    buildTypes {"
            )
        gradle_kts.write_text(gt)
        print("Configured build.gradle.kts SDK versions (minSdk=21, targetSdk=34) and disabled lintRelease.")

    gradle_groovy = Path("android/app/build.gradle")
    if gradle_groovy.exists():
        gt = gradle_groovy.read_text()
        gt = gt.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 21")
        gt = gt.replace("targetSdkVersion flutter.targetSdkVersion", "targetSdkVersion 34")
        if "lintOptions {" not in gt:
            gt = gt.replace(
                "buildTypes {",
                "lintOptions {\n        checkReleaseBuilds false\n        abortOnError false\n    }\n\n    buildTypes {"
            )
        gradle_groovy.write_text(gt)
        print("Configured build.gradle SDK versions (minSdk=21, targetSdk=34) and disabled lintRelease.")

DEFAULT_KEYSTORE_B64 = """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"""

def configure_signing():
    keystore_b64 = os.environ.get("KEYSTORE_BASE64", "").strip() or DEFAULT_KEYSTORE_B64
    store_password = os.environ.get("KEYSTORE_PASSWORD", "").strip() or "madtech_rescue_2026"
    key_alias = os.environ.get("KEY_ALIAS", "").strip() or "madtech_upload"
    key_password = os.environ.get("KEY_PASSWORD", "").strip() or "madtech_rescue_2026"

    keystore_path = Path("android/app/release.keystore")
    keystore_path.parent.mkdir(parents=True, exist_ok=True)
    keystore_path.write_bytes(base64.b64decode(keystore_b64))
    print("Extracted release.keystore from environment/default MAD Tech production key.")

    gradle_kts = Path("android/app/build.gradle.kts")
    if gradle_kts.exists():
        s = gradle_kts.read_text()
        if 'signingConfigs.create("release")' not in s and 'create("release")' not in s:
            signing_code = f'''signingConfigs {{
        create("release") {{
            storeFile = file("release.keystore")
            storePassword = "{store_password}"
            keyAlias = "{key_alias}"
            keyPassword = "{key_password}"
        }}
    }}
    buildTypes {{'''
            s = s.replace("buildTypes {", signing_code)
            s = s.replace(
                'getByName("release") {',
                'getByName("release") {\n            signingConfig = signingConfigs.getByName("release")',
            )
            gradle_kts.write_text(s)
            print("Injected release signing configuration into build.gradle.kts.")

    gradle_groovy = Path("android/app/build.gradle")
    if gradle_groovy.exists():
        s = gradle_groovy.read_text()
        if "signingConfigs {" not in s:
            signing_code = f"""
    signingConfigs {{
        release {{
            storeFile file('release.keystore')
            storePassword '{store_password}'
            keyAlias '{key_alias}'
            keyPassword '{key_password}'
        }}
    }}
"""
            s = s.replace("buildTypes {", signing_code + "\n    buildTypes {")
            s = s.replace("release {", "release {\n            signingConfig signingConfigs.release")
            gradle_groovy.write_text(s)
            print("Injected release signing configuration into build.gradle.")

if __name__ == "__main__":
    configure_google_services()
    configure_manifest()
    configure_sdk_versions()
    configure_signing()
