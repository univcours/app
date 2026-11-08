"""Safety tests for official Play release preset generation."""
import importlib.util
import tempfile
import unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("playprep",HERE.parent/"scripts/prepare_play_release.py")
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class PlayReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        source=(HERE.parent/"export_presets.cfg").read_text(encoding="utf-8")
        second=source.replace("[preset.0.options]","[preset.1.options]").replace(
            "[preset.0]","[preset.1]")
        second=second.replace('name="Android Preview"','name="Android AdMob Test"')
        (self.root/"export_presets.cfg").write_text(source+"\n"+second,encoding="utf-8")
        (self.root/"project.godot").write_text(
            '[application]\nconfig/name="NovaGrid"\n'
            '[admob]\ngeneral/android/app_id="ca-app-pub-3940256099942544~3347511713"\n'
            '[novagrid_ads]\nproduction_release=false\n',encoding="utf-8")
        (self.root/"addons/admob").mkdir(parents=True)
        (self.root/"addons/admob/plugin.cfg").write_text("[plugin]\n")
        (self.root/"ads").mkdir()
        (self.root/"ads/AdMobRuntime.gd").write_text(
            (HERE.parent/"ads/AdMobRuntime.gd.txt").read_text(encoding="utf-8"),
            encoding="utf-8")

    def test_play_settings(self):
        module.prepare(self.root,2000111)
        release=(self.root/"export_presets.cfg").read_text().split("[preset.2]")[1]
        for token in [
            'name="Android Play Release"','package/unique_name="com.novagrid.cosmicpuzzle"',
            'gradle_build/target_sdk="36"','gradle_build/export_format=1',
            'gradle_build/use_gradle_build=true','version/code=2000111',
            'package/signed=false','keystore/release=""',
        ]:
            self.assertIn(token,release)
        self.assertNotIn("godotpreview",release)
        cfg=(self.root/"project.godot").read_text()
        self.assertIn(module.LIVE_APP,cfg)
        self.assertIn("production_release=true",cfg)
        self.assertNotIn(module.TEST_APP,cfg)
    def test_no_overwrite(self):
        module.prepare(self.root,2000111)
        before=(self.root/"export_presets.cfg").read_bytes()
        with self.assertRaises(ValueError):
            module.prepare(self.root,2000112)
        self.assertEqual(before,(self.root/"export_presets.cfg").read_bytes())
    def test_bad_versions(self):
        before=(self.root/"export_presets.cfg").read_bytes()
        for version in [-3,0,2100000001]:
            with self.assertRaises(ValueError):
                module.prepare(self.root,version)
        self.assertEqual(before,(self.root/"export_presets.cfg").read_bytes())
    def test_requires_plugin(self):
        (self.root/"addons/admob/plugin.cfg").unlink()
        with self.assertRaises(FileNotFoundError):
            module.prepare(self.root,2000111)

if __name__=="__main__": unittest.main(verbosity=2)
