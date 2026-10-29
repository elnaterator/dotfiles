"""Behavior checks using synthetic file bytes and controlled metadata."""
import csv
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'organize_photos.py'
spec = importlib.util.spec_from_file_location('photos', SCRIPT)
photos = importlib.util.module_from_spec(spec)
spec.loader.exec_module(photos)


class PhotoCopies(unittest.TestCase):
    def test_setup_check_without_photo_paths_or_writes(self):
        for ordering, installed, expected in [('capture', None, False), ('capture', '/tools/exiftool', True), ('name', None, True), ('modified', None, True)]:
            with self.subTest(ordering=ordering, installed=installed):
                output = io.StringIO()
                with patch('sys.argv', ['photos', '--check-dependencies', '--sort', ordering]), patch('sys.stdout', output), patch.object(photos.shutil, 'which', return_value=installed) as lookup, patch.object(photos, 'inventory') as inventory, patch.object(photos.Path, 'mkdir') as mkdir:
                    result = photos.main()
                status = json.loads(output.getvalue())
                self.assertEqual(status['ready'], expected)
                self.assertEqual(result, 0 if expected else 1)
                self.assertEqual(status['python_packages_required'], [])
                self.assertEqual(status['exiftool_required'], ordering == 'capture')
                inventory.assert_not_called()
                mkdir.assert_not_called()
                if ordering != 'capture':
                    lookup.assert_not_called()

    def test_filename_copy_needs_no_metadata_tool(self):
        self.put('one.JPG')
        output = self.root / 'filename-copies'
        with patch('sys.argv', ['photos', '--input', str(self.source), '--output', str(output), '--sort', 'name', '--copy']), patch.object(photos.shutil, 'which', return_value=None) as lookup, patch.object(photos, 'read_metadata') as metadata:
            self.assertEqual(photos.main(), 0)
        lookup.assert_not_called()
        metadata.assert_not_called()
        self.assertTrue((output / 'Organization_Records/verification_report.txt').read_text().startswith('PASS'))

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.source = self.root / 'source'
        self.source.mkdir()

    def put(self, name):
        p = self.source / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(('original:' + name).encode())
        return p

    def run_job(self, *options, metadata=None):
        output = self.root / ('out' + str(len(list(self.root.iterdir()))))
        args = ['photos', '--input', str(self.source), '--output', str(output), '--prefix', 'Wedding', *options]
        with patch('sys.argv', args), patch.object(photos.shutil, 'which', return_value='/test/exiftool'), patch.object(photos, 'read_metadata', return_value=metadata or {}):
            result = photos.main()
        return result, output

    def test_companion_copy_exclusions_and_repeated_basenames(self):
        originals = [self.put(n) for n in ['a/IMG.CR3', 'a/IMG.JPG', 'a/IMG.xmp', 'a/IMG.CR3.xmp', 'b/IMG.CR3']]
        for n in ['.DS_Store', '.hidden/no.JPG', 'notes.txt', 'orphan.xmp', 'clip.mov']:
            self.put(n)
        before = {p: p.read_bytes() for p in originals}
        result, out = self.run_job('--sort', 'name', '--copy')
        self.assertEqual(result, 0)
        copied = sorted(p.name for p in (out / 'Organized').iterdir())
        self.assertEqual(copied, ['Wedding_0001.CR3', 'Wedding_0001.CR3.xmp', 'Wedding_0001.JPG', 'Wedding_0001.xmp', 'Wedding_0002.CR3'])
        summary = json.loads((out / 'Organization_Records/summary.json').read_text())
        self.assertEqual(summary['photo_groups'], 2)
        self.assertEqual(len(summary['excluded_files']), 5)
        self.assertEqual(summary['unmatched_sidecars'], ['orphan.xmp'])
        with (out / 'Organization_Records/rename_manifest.csv').open() as f:
            for row in csv.DictReader(f):
                self.assertEqual((out / 'Organized' / row['proposed_name']).read_bytes(), before[self.source / row['original_path']])
                self.assertEqual(row['verification'], 'SHA-256 verified')
        self.assertEqual(before, {p: p.read_bytes() for p in originals})
        self.assertTrue((out / 'Organization_Records/verification_report.txt').read_text().startswith('PASS'))

    def test_missing_time_stops_and_fallback_is_explicit(self):
        self.put('one.JPG')
        result, out = self.run_job('--copy')
        self.assertEqual(result, 1)
        self.assertFalse((out / 'Organized').exists())
        self.assertEqual(json.loads((out / 'Organization_Records/summary.json').read_text())['missing_time_groups'], 1)
        result, out = self.run_job('--missing-time', 'modified', '--copy')
        self.assertEqual(result, 0)

    def test_recorded_time_date_folders_and_sidecar_inheritance(self):
        a, b = self.put('a.JPG'), self.put('b.JPG')
        self.put('a.xmp')
        meta = {a: {'EXIF:DateTimeOriginal': '2025:06:02 23:30:00-07:00'}, b: {'EXIF:DateTimeOriginal': '2025:06:03 01:00:00+02:00'}}
        result, out = self.run_job('--time-basis', 'recorded', '--naming', 'date', '--folders', 'date', '--copy', metadata=meta)
        self.assertEqual(result, 0)
        self.assertTrue((out / 'Organized/2025-06-02/2025-06-02_Wedding_0001.JPG').exists())
        self.assertTrue((out / 'Organized/2025-06-02/2025-06-02_Wedding_0001.xmp').exists())
        absolute_a, _ = photos.capture_time('2025:06:02 23:30:00-07:00')
        absolute_b, _ = photos.capture_time('2025:06:03 01:00:00+02:00')
        self.assertGreater(absolute_a, absolute_b)

    def test_conflict_and_original_name_collision_stop(self):
        a, b = self.put('IMG.CR3'), self.put('IMG.JPG')
        result, out = self.run_job('--time-basis', 'recorded', '--copy', metadata={a: {'EXIF:DateTimeOriginal': '2025:01:01 10:00:00'}, b: {'EXIF:DateTimeOriginal': '2025:01:01 11:00:00'}})
        self.assertEqual(result, 1)
        self.assertFalse((out / 'Organized').exists())
        self.put('other/IMG.JPG')
        result, out = self.run_job('--sort', 'name', '--naming', 'original', '--copy')
        self.assertEqual(result, 1)
        self.assertFalse((out / 'Organized').exists())

    def test_preview_video_opt_in_and_source_inventory(self):
        self.put('photo.JPG')
        self.put('clip.mov')
        result, out = self.run_job('--sort', 'name', '--include-video')
        self.assertEqual(result, 0)
        self.assertFalse((out / 'Organized').exists())
        summary = json.loads((out / 'Organization_Records/summary.json').read_text())
        self.assertEqual(summary['files'], 2)
        self.assertEqual(summary['photo_groups'], 1)
        self.assertEqual(summary['media_groups'], 2)


if __name__ == '__main__':
    unittest.main()
