#!/usr/bin/env python3
"""Build the simulator app directly when Xcode's destination discovery is unavailable."""
import os
from pathlib import Path
import plistlib
import subprocess

root = Path(__file__).resolve().parents[1]
out = root / 'work' / 'simulator-build'
app = out / 'CatchFive.app'
app.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, DEVELOPER_DIR=os.environ.get('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer'))
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], env=env, text=True).strip()
base = ['xcrun', 'swiftc', '-sdk', sdk, '-target', 'arm64-apple-ios17.0-simulator', '-swift-version', '6', '-I', str(out), '-L', str(out)]

def run(args):
    subprocess.run(args, env=env, cwd=root, check=True)

for module in ['CatchFive', 'CatchFiveUI']:
    sources = sorted(str(p) for p in (root / 'Sources' / module).rglob('*.swift'))
    run(base + ['-emit-library', '-static', '-emit-module', '-module-name', module,
                '-emit-module-path', str(out / (module + '.swiftmodule')),
                '-o', str(out / ('lib' + module + '.a'))] + sources)
run(base + ['-module-name', 'CatchFiveApp', '-parse-as-library', str(root / 'App' / 'CatchFiveApp.swift'),
            '-lCatchFiveUI', '-lCatchFive', '-o', str(app / 'CatchFive')])
info = dict(CFBundleIdentifier='com.cardgame.catchfive', CFBundleName='CatchFive',
            CFBundleDisplayName='Catch 5', CFBundleExecutable='CatchFive', CFBundlePackageType='APPL',
            CFBundleShortVersionString='1.0', CFBundleVersion='1', MinimumOSVersion='17.0',
            LSRequiresIPhoneOS=True, UIDeviceFamily=[1, 2], UILaunchScreen={}, UIUserInterfaceStyle='Dark',
            LSApplicationCategoryType='public.app-category.card-games', UIRequiresFullScreen=True,
            UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait'])
# The icon the simulator shows on the home screen, scaled from the App Store master.
icon = root / 'App' / 'Assets.xcassets' / 'AppIcon.appiconset' / 'icon-1024.png'
if icon.exists():
    for scale, pixels in (('@2x', 120), ('@3x', 180)):
        subprocess.run(['sips', '-z', str(pixels), str(pixels), str(icon), '--out', str(app / f'AppIcon60x60{scale}.png')],
                       check=True, capture_output=True)
    info['CFBundleIcons'] = {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['AppIcon60x60'], 'CFBundleIconName': 'AppIcon'}}
explainer = root / 'App' / 'Explainer'
if explainer.exists():
    target = app / 'Explainer'
    target.mkdir(exist_ok=True)
    for page in explainer.glob('*.dc.html'):
        (target / page.name).write_bytes(page.read_bytes())
privacy = root / 'App' / 'PrivacyInfo.xcprivacy'
if privacy.exists():
    (app / 'PrivacyInfo.xcprivacy').write_bytes(privacy.read_bytes())
with (app / 'Info.plist').open('wb') as file:
    plistlib.dump(info, file)
run(['codesign', '--force', '--sign', '-', str(app)])
print(app)
