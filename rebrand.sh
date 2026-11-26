#!/usr/bin/env bash
# Baut aus dem Modrinth-App-Quellcode (GPL-3.0) den Chunkline Launcher.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$1"

# 1) Name und Kennung
sed -i 's/"productName": "Modrinth App"/"productName": "Chunkline Launcher"/; s/"mainBinaryName": "Modrinth App"/"mainBinaryName": "Chunkline Launcher"/; s/"identifier": "ModrinthApp"/"identifier": "ChunklineLauncher"/; s/"title": "Modrinth App"/"title": "Chunkline Launcher"/' apps/app/tauri.conf.json
sed -i 's/"title": "Modrinth App"/"title": "Chunkline Launcher"/' apps/app/tauri.macos.conf.json
sed -i 's/Modrinth App/Chunkline Launcher/g' apps/app/nsis/hooks.nsi apps/app/Cargo.toml

# 2) Sichtbare Texte
find apps/app-frontend/src -type f \( -name '*.json' -o -name '*.vue' -o -name '*.ts' -o -name '*.js' \) -exec sed -i 's/Modrinth App/Chunkline Launcher/g' {} +

# 3) Farben: Modrinth-Gruen -> Chunkline-Bernstein
sed -i 's/#1bd96a/#f0a64a/g; s/#4d9227/#c97a14/g' packages/assets/styles/variables.scss

# 4) Logo ersetzen (Modrinth-Logos duerfen nicht verwendet werden)
cp "$HERE/chunkline-logo.svg" packages/assets/branding/logo.svg
find packages/assets -iname '*modrinth*.svg' -not -path '*/external/*' -exec cp "$HERE/chunkline-logo.svg" {} \;

# 5) Werbung abschalten
perl -0pi -e 's/state\.shown && \(state\.visibility_holds == 0 \|\| state\.consent_overlay_shown\)/false/' apps/app/src/api/ads.rs
if grep -q 'state.shown && (state.visibility_holds' apps/app/src/api/ads.rs; then
  echo "FEHLER: Werbung konnte nicht abgeschaltet werden" >&2; exit 1
fi
# 6) Sprache: alle Sprachen bleiben, beim ersten Start wird die Systemsprache des PCs uebernommen
sed -i "s#^import i18n, { setLocale } from '@/i18n.config'#&\nimport { LOCALES } from '@modrinth/ui'#" apps/app-frontend/src/App.vue
REPL="$HERE/locale-startup.txt" perl -0pi -e 'BEGIN{ local $/; open F, "<", $ENV{REPL}; $r = <F>; close F } s/\t\/\/ Initialize locale from saved settings\n\tif \(locale\) \{\n\t\tawait traceStartupStep\(\x27Apply startup locale\x27, \(\) => setLocale\(locale\)\)\n\t\}\n/$r/' apps/app-frontend/src/App.vue
if ! grep -q chunkline_locale_initialized apps/app-frontend/src/App.vue; then
  echo "FEHLER: Systemsprache-Erkennung konnte nicht eingebaut werden" >&2; exit 1
fi
perl -0pi -e 's/(content: LanguageSettings,\n)\t\tbadge: commonMessages\.beta,\n/$1/' apps/app-frontend/src/features/settings/app-settings-modal/index.vue

echo "Umbau fertig."
