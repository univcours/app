#!/usr/bin/env python3
"""Prepare a Play release preset from the tested Godot/Poing installation.

No private keystore or credential is read or written by this script.
"""
import argparse
from pathlib import Path

PACKAGE = "com.novagrid.cosmicpuzzle"
LIVE_APP = "ca-app-pub-7945572016731367~1688423435"
TEST_APP = "ca-app-pub-3940256099942544~3347511713"

def replace_one(text, before, after):
    if text.count(before) != 1:
        raise ValueError("Unexpected export template setting: " + before)
    return text.replace(before, after, 1)

def prepare(project, version):
    project = Path(project)
    if not (1 <= version <= 2100000000):
        raise ValueError("Invalid Google Play versionCode")
    for needed in ["project.godot", "addons/admob/plugin.cfg", "ads/AdMobRuntime.gd"]:
        if not (project/needed).is_file():
            raise FileNotFoundError("Missing release dependency: " + needed)
    runtime=(project/"ads/AdMobRuntime.gd").read_text(encoding="utf-8")
    for text in [LIVE_APP,"3815893327","2422920606","production_release"]:
        if text not in runtime:
            raise ValueError("Owned AdMob configuration not complete")
    presets=project/"export_presets.cfg"
    content=presets.read_text(encoding="utf-8")
    if "[preset.1]" not in content or "[preset.2]" in content:
        raise ValueError("Need the installed test preset and no release collision")
    base=content.split("[preset.1]",1)[0].strip()
    if '[preset.0.options]' not in base:
        raise ValueError("Missing original Android export template")
    release=base.replace("[preset.0.options]","[preset.2.options]").replace(
        "[preset.0]","[preset.2]")
    rules=[
        ('name="Android Preview"','name="Android Play Release"'),
        ('gradle_build/use_gradle_build=false','gradle_build/use_gradle_build=true'),
        ('gradle_build/export_format=0','gradle_build/export_format=1'),
        ('gradle_build/target_sdk=""','gradle_build/target_sdk="36"'),
        ('version/code=4','version/code='+str(version)),
        ('version/name="0.4.0-cosmic-preview"','version/name="1.1.0-cosmic"'),
        ('package/unique_name="com.novagrid.cosmicpuzzle.godotpreview"',
            'package/unique_name="'+PACKAGE+'"'),
        ('package/name="NovaGrid Godot Preview"','package/name="NovaGrid"'),
        ('package/signed=true','package/signed=false'),
        ('export_path="build/NovaGrid-Godot-Preview.apk"',
            'export_path="build/NovaGrid-Play-Unsigned.aab"'),
    ]
    for before,after in rules:
        release=replace_one(release,before,after)
    config=project/"project.godot"
    project_content=config.read_text(encoding="utf-8")
    if "[admob]" not in project_content or "[novagrid_ads]" not in project_content:
        raise ValueError("Godot AdMob settings not found")
    project_content=replace_one(project_content,
        'general/android/app_id="'+TEST_APP+'"',
        'general/android/app_id="'+LIVE_APP+'"')
    project_content=replace_one(project_content,
        'production_release=false','production_release=true')
    if TEST_APP in project_content:
        raise ValueError("Test AdMob ID in production configuration")
    presets.write_text(content+"\n"+release+"\n",encoding="utf-8")
    config.write_text(project_content,encoding="utf-8")
    print("NOVAGRID_PLAY_PREPARED package="+PACKAGE+
          " target=36 format=AAB code="+str(version)+
          " app_id=LIVE signed=false")

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--project",type=Path,required=True)
    parser.add_argument("--version-code",type=int,required=True)
    args=parser.parse_args()
    prepare(args.project.resolve(),args.version_code)
