#!/usr/bin/env python3
"""Verify the actual app, ZIP, mounted DMG, architecture slices and signatures."""
import argparse
import hashlib
import plistlib
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--universal', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
outputs = root / 'temp/outputs'
app = outputs / 'TashAir.app'

def run(*command):
    return subprocess.check_output(command, text=True, stderr=subprocess.STDOUT).strip()

def verify_app(bundle):
    info = plistlib.loads((bundle / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleShortVersionString'] == '0.1.0'
    assert info['LSMinimumSystemVersion'] == '14.0'
    assert info['CFBundleIdentifier'] == 'uz.tashair.desktop'
    extension = bundle / 'Contents/PlugIns/TashAirWidgets.appex'
    widget = plistlib.loads((extension / 'Contents/Info.plist').read_bytes())
    assert widget['CFBundleShortVersionString'] == info['CFBundleShortVersionString']
    assert widget['CFBundleIdentifier'] == 'uz.tashair.desktop.widgets'
    assert (extension / 'Contents/Resources/Metadata.appintents').exists()
    for language in ['ru', 'uz']:
        assert (extension / f'Contents/Resources/{language}.lproj/Localizable.strings').exists()
    for binary in [bundle / 'Contents/MacOS/TashAir', extension / 'Contents/MacOS/TashAirWidgets']:
        architectures = set(run('lipo', '-archs', str(binary)).split())
        if args.universal:
            assert {'arm64', 'x86_64'} <= architectures, architectures
        dependencies = run('otool', '-L', str(binary))
        assert all('/Users/' not in line for line in dependencies.splitlines() if line.startswith('\t'))
        build = run('xcrun', 'vtool', '-show-build', str(binary))
        assert all(line.split()[-1] == '14.0' for line in build.splitlines() if line.strip().startswith('minos '))
    run('codesign', '--verify', '--deep', '--strict', str(bundle))
    assert (bundle / 'Contents/Resources/TashAir.icns').stat().st_size > 0
    assert (bundle / 'Contents/Resources/LICENSE').read_bytes() == (root / 'LICENSE').read_bytes()

def tree_hash(bundle):
    return {str(p.relative_to(bundle)): hashlib.sha256(p.read_bytes()).hexdigest() for p in bundle.rglob('*') if p.is_file()}

verify_app(app)
with tempfile.TemporaryDirectory(prefix='tashair-zip-') as temp:
    run('ditto', '-x', '-k', str(outputs / 'TashAir-macOS.zip'), temp)
    assert tree_hash(Path(temp) / 'TashAir.app') == tree_hash(app)
with tempfile.TemporaryDirectory(prefix='tashair-dmg-') as temp:
    mount = Path(temp) / 'mount'
    run('hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', str(mount), str(outputs / 'TashAir.dmg'))
    try:
        verify_app(mount / 'TashAir.app')
        assert (mount / 'Applications').is_symlink()
        assert tree_hash(mount / 'TashAir.app') == tree_hash(app)
    finally:
        run('hdiutil', 'detach', str(mount))
for line in (outputs / 'SHA256SUMS').read_text().splitlines():
    digest, name = line.split(maxsplit=1)
    assert hashlib.sha256((outputs / name.strip()).read_bytes()).hexdigest() == digest
print('Verified app, widget metadata, signatures, ZIP, DMG and SHA256SUMS' + (' · arm64 + x86_64' if args.universal else ''))
