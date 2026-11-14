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
            manifest.write_text(text)
            print("Configured AndroidManifest.xml permissions.")

def configure_sdk_versions():
    gradle_kts = Path("android/app/build.gradle.kts")
    if gradle_kts.exists():
        gt = gradle_kts.read_text()
        gt = gt.replace("minSdk = flutter.minSdkVersion", "minSdk = 21")
        gt = gt.replace("targetSdk = flutter.targetSdkVersion", "targetSdk = 34")
        gradle_kts.write_text(gt)
        print("Configured build.gradle.kts SDK versions (minSdk=21, targetSdk=34).")

    gradle_groovy = Path("android/app/build.gradle")
    if gradle_groovy.exists():
        gt = gradle_groovy.read_text()
        gt = gt.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 21")
        gt = gt.replace("targetSdkVersion flutter.targetSdkVersion", "targetSdkVersion 34")
        gradle_groovy.write_text(gt)
        print("Configured build.gradle SDK versions (minSdk=21, targetSdk=34).")

def configure_signing():
    keystore_b64 = os.environ.get("KEYSTORE_BASE64", "").strip()
    store_password = os.environ.get("KEYSTORE_PASSWORD", "").strip()
    key_alias = os.environ.get("KEY_ALIAS", "").strip()
    key_password = os.environ.get("KEY_PASSWORD", "").strip()

    keystore_path = Path("android/app/release.keystore")
    keystore_path.parent.mkdir(parents=True, exist_ok=True)

    if keystore_b64:
        keystore_path.write_bytes(base64.b64decode(keystore_b64))
        print("Extracted release.keystore from environment secrets.")
    else:
        print("Generating standalone release keystore with keytool...")
        store_password = "hunor_release_pass"
        key_alias = "hunor"
        key_password = "hunor_release_pass"
        import subprocess
        cmd = [
            "keytool", "-genkeypair", "-v",
            "-keystore", str(keystore_path),
            "-alias", key_alias,
            "-keyalg", "RSA",
            "-keysize", "2048",
            "-validity", "10000",
            "-storepass", store_password,
            "-keypass", key_password,
            "-dname", "CN=HUNOR, OU=USAR, O=HUNOR, L=Budapest, C=HU"
        ]
        subprocess.run(cmd, check=True)
        print("Generated self-signed release.keystore.")

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
