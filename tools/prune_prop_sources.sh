#!/usr/bin/env bash
# Pişirme sonrası: sahne nesnelerinin ham glTF/.bin dosyalarını ve hiçbir pişmiş ağın kullanmadığı
# dokuları siler (depo ve tablette içe aktarma süresi küçülür). Füzeler glTF'i doğrudan kullanır, dokunulmaz.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
used=$(mktemp)
"$GODOT" --headless --path . -s res://tools/godot/list_mesh_textures.gd 2>/dev/null | grep '^TEX ' | sed 's#^TEX res://##' | sort -u > "$used"
for f in assets/models/props/*/textures/*; do
  case "$f" in *.import) continue;; esac
  grep -qxF "$f" "$used" || { rm -f "$f" "$f.import"; echo "silindi: $f"; }
done
rm -f assets/models/props/*/model.gltf assets/models/props/*/model.gltf.import assets/models/props/*/*.bin
rm -f "$used"
