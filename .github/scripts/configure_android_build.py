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
        gt = gt.replace("minSdk = flutter.minSdkVersion", "minSdk = 23")
        gt = gt.replace("targetSdk = flutter.targetSdkVersion", "targetSdk = 36")
        gradle_kts.write_text(gt)
        print("Configured build.gradle.kts SDK versions.")

    gradle_groovy = Path("android/app/build.gradle")
    if gradle_groovy.exists():
        gt = gradle_groovy.read_text()
        gt = gt.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 23")
        gt = gt.replace("targetSdkVersion flutter.targetSdkVersion", "targetSdkVersion 36")
        gradle_groovy.write_text(gt)
        print("Configured build.gradle SDK versions.")

def configure_signing():
    keystore_b64 = os.environ.get("KEYSTORE_BASE64", "").strip()
    store_password = os.environ.get("KEYSTORE_PASSWORD", "").strip()
    key_alias = os.environ.get("KEY_ALIAS", "").strip()
    key_password = os.environ.get("KEY_PASSWORD", "").strip()

    if not keystore_b64:
        print("Notice: No KEYSTORE_BASE64 provided. Release signing not configured.")
        return

    keystore_path = Path("android/app/release.keystore")
    keystore_path.parent.mkdir(parents=True, exist_ok=True)
    keystore_path.write_bytes(base64.b64decode(keystore_b64))

    props_content = f"""storePassword={store_password}
keyPassword={key_password}
keyAlias={key_alias}
storeFile=release.keystore
"""
    Path("android/key.properties").write_text(props_content)
    print("Wrote android/key.properties and android/app/release.keystore.")

    gradle_kts = Path("android/app/build.gradle.kts")
    if gradle_kts.exists():
        s = gradle_kts.read_text()
        if "import java.util.Properties" not in s:
            s = "import java.util.Properties\nimport java.io.FileInputStream\n" + s
        if 'signingConfigs.create("release")' not in s and 'create("release")' not in s:
            signing_code = '''signingConfigs {
        create("release") {
            val keyProps = Properties()
            val keyPropsFile = rootProject.file("key.properties")
            if (keyPropsFile.exists()) {
                keyProps.load(FileInputStream(keyPropsFile))
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }
    buildTypes {'''
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
            signing_code = """
    signingConfigs {
        release {
            def keyProps = new Properties()
            def keyPropsFile = rootProject.file("key.properties")
            if (keyPropsFile.exists()) {
                keyProps.load(new FileInputStream(keyPropsFile))
                storeFile file(keyProps['storeFile'])
                storePassword keyProps['storePassword']
                keyAlias keyProps['keyAlias']
                keyPassword keyProps['keyPassword']
            }
        }
    }
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
