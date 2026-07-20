#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="TaskManager"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

echo "==> Compilando (release)..."
swift build -c release

echo "==> Montando ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.miguel.taskmanager</string>
    <key>CFBundleName</key>
    <string>Gerenciador de Tarefas</string>
    <key>CFBundleDisplayName</key>
    <string>Gerenciador de Tarefas</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Uso pessoal</string>
</dict>
</plist>
PLIST

echo "==> Assinando (ad-hoc)..."
codesign --force --deep -s - "${APP_BUNDLE}"

echo "==> Pronto: $(pwd)/${APP_BUNDLE}"
echo "Abra com: open ${APP_BUNDLE}"
