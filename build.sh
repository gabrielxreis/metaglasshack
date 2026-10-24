#!/bin/zsh
# Compila o Wayfarer Mac e monta o .app em build/
set -e
cd "$(dirname "$0")"

# Leitor do iPhone pelo cabo (Python + pymobiledevice3), instalado uma vez
if [ ! -x tools/venv/bin/python ]; then
  echo "Instalando o leitor do iPhone (pymobiledevice3)..."
  python3 -m venv tools/venv
  tools/venv/bin/pip install -q -r tools/requirements.txt
fi
APP="build/Wayfarer Mac.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -parse-as-library \
  -target arm64-apple-macosx14.0 \
  -framework SwiftUI -framework CoreBluetooth -framework IOBluetooth \
  -framework CoreAudio -framework Photos -framework AVFoundation -framework ImageIO \
  Sources/*.swift -o "$APP/Contents/MacOS/WayfarerMac"

# Ícone
if [ ! -f build/AppIcon.icns ]; then
  swift tools/make_icon.swift build/icon_1024.png
  rm -rf build/AppIcon.iconset && mkdir build/AppIcon.iconset
  for s in 16 32 128 256 512; do
    sips -z $s $s build/icon_1024.png --out build/AppIcon.iconset/icon_${s}x${s}.png >/dev/null
    sips -z $((s*2)) $((s*2)) build/icon_1024.png --out build/AppIcon.iconset/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Wayfarer Mac</string>
  <key>CFBundleDisplayName</key><string>Wayfarer Mac</string>
  <key>CFBundleIdentifier</key><string>com.gabrielreis.wayfarermac</string>
  <key>CFBundleExecutable</key><string>WayfarerMac</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>Para encontrar, conectar e ler as informações dos seus óculos Meta.</string>
  <key>NSPhotoLibraryUsageDescription</key><string>Para encontrar as fotos e vídeos feitos pelos óculos e copiar pro Mac.</string>
</dict>
</plist>
PLIST

# Assinatura estável (mantém as permissões de Fotos e Bluetooth entre builds); cai pra ad-hoc se não houver certificado
ID=$(security find-identity -v -p codesigning | awk '/[0-9]\)/{print $2; exit}')
codesign --force --deep --sign "${ID:--}" "$APP"
echo "OK: $APP"
