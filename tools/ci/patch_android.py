#!/usr/bin/env python3
"""Patch the `flutter create` Android scaffold for Loop Sort.

* minSdk 24
* release signing from android/key.properties (falls back to debug signing)
* overlays tools/android_overlay (manifest, icons, res) on the scaffold
"""
import os, re, shutil, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
APP = os.path.join(ROOT, "android", "app")


def overlay():
    src = os.path.join(ROOT, "tools", "android_overlay")
    dst = os.path.join(APP, "src", "main")
    for base, _dirs, files in os.walk(src):
        rel = os.path.relpath(base, src)
        out = os.path.join(dst, rel) if rel != "." else dst
        os.makedirs(out, exist_ok=True)
        for f in files:
            shutil.copy2(os.path.join(base, f), os.path.join(out, f))


def patch_kts(path):
    s = open(path).read()
    if "keystoreProperties" in s:
        return
    s = s.replace("minSdk = flutter.minSdkVersion", "minSdk = 24")
    header = (
        "import java.io.FileInputStream\nimport java.util.Properties\n\n"
        "val keystoreProperties = Properties()\n"
        "val keystorePropertiesFile = rootProject.file(\"key.properties\")\n"
        "if (keystorePropertiesFile.exists()) {\n"
        "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
        "}\n\n"
    )
    s = header + s
    signing = (
        "    signingConfigs {\n"
        "        create(\"release\") {\n"
        "            if (keystorePropertiesFile.exists()) {\n"
        "                keyAlias = keystoreProperties[\"keyAlias\"] as String\n"
        "                keyPassword = keystoreProperties[\"keyPassword\"] as String\n"
        "                storeFile = file(keystoreProperties[\"storeFile\"] as String)\n"
        "                storePassword = keystoreProperties[\"storePassword\"] as String\n"
        "            }\n"
        "        }\n"
        "    }\n\n"
    )
    assert "    buildTypes {" in s, "buildTypes block not found"
    s = s.replace("    buildTypes {", signing + "    buildTypes {", 1)
    s, n = re.subn(
        r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
        'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
        s,
    )
    assert n >= 1, "release signingConfig line not found"
    open(path, "w").write(s)


def patch_groovy(path):
    s = open(path).read()
    if "keystoreProperties" in s:
        return
    s = s.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 24")
    s = s.replace("minSdk = flutter.minSdkVersion", "minSdk = 24")
    header = (
        "def keystoreProperties = new Properties()\n"
        "def keystorePropertiesFile = rootProject.file('key.properties')\n"
        "if (keystorePropertiesFile.exists()) {\n"
        "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
        "}\n\n"
    )
    s = header + s
    signing = (
        "    signingConfigs {\n"
        "        release {\n"
        "            if (keystorePropertiesFile.exists()) {\n"
        "                keyAlias keystoreProperties['keyAlias']\n"
        "                keyPassword keystoreProperties['keyPassword']\n"
        "                storeFile file(keystoreProperties['storeFile'])\n"
        "                storePassword keystoreProperties['storePassword']\n"
        "            }\n"
        "        }\n"
        "    }\n\n"
    )
    assert "    buildTypes {" in s
    s = s.replace("    buildTypes {", signing + "    buildTypes {", 1)
    s = s.replace("signingConfig signingConfigs.debug", "signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug")
    open(path, "w").write(s)


def main():
    overlay()
    kts = os.path.join(APP, "build.gradle.kts")
    groovy = os.path.join(APP, "build.gradle")
    if os.path.exists(kts):
        patch_kts(kts)
        print("patched", kts)
    elif os.path.exists(groovy):
        patch_groovy(groovy)
        print("patched", groovy)
    else:
        sys.exit("no app build.gradle found")


if __name__ == "__main__":
    main()
