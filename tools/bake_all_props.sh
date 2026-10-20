#!/usr/bin/env bash
# Tüm sahne nesnelerini Sketchfab'den indirip mobil için pişirir (tekrar üretilebilirlik).
# Gerekenler: SKETCHFAB_API_TOKEN (.env veya ortam), Godot 4.7 (GODOT değişkeni), Python 3 + Pillow.
# Ham glTF dosyaları depoda tutulmaz (yalnızca dokular + pişmiş ağlar); bu betik onları yeniden üretir.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
P=res://assets/models/props

fetch() {  # uid isim doku_boyutu
  [ -d "tools/downloads/$2" ] || python3 tools/sketchfab_fetch.py download "$1" "$2"
  python3 tools/process_model.py "tools/downloads/$2" "assets/models/props/$2" --max-texture "$3"
}
bake() { "$GODOT" --headless --path . -s res://tools/godot/bake_prop.gd -- "$@"; }

fetch 64f7d287f5274029bc29755a9839ebbf hangar 1024
fetch 371eb5dc09a9448aa932b957100f86c8 mil_buildings 1024
fetch 84f215391662453680e646649d42b264 control_tower 1024
fetch 730724d01c8446f9801147e66ae67ac8 radars 1024
fetch 5ac257aee23e47e0a0f91a4e07a40692 fuel_tank 1024
fetch b5994d5a6a2648e59cf86ea1951bacaf sandbag_wall 512
fetch afaab6285c484c36aab250e06727d471 concrete_barrier 512
fetch bd85a8005ff0403cab2f1e9845016b8f fence 1024
fetch bda39e79dbfa4976b1791b6b1f58259c watchtower 1024
fetch 5c26a86ff20c4df689b5fbd760337845 container 1024
fetch f953c51a5dbc4a15949f4dcc0905c4e8 ural_truck 1024
fetch fac4178dc3db4eb9abf7f45425125e1e humvee 1024
fetch 2d44b333f56c4faaab1bd2007868cc37 street_light 512
fetch b6f6b255971d4b91bb708e406671535a rock_eroded 1024
fetch 62da7c177a6241eebe94c4eba6fc81b7 rock_base 1024
fetch 631b5e0c67da4be68a16fb7955f1652f checkpoint 1024
fetch 08a4f422bc634033b8023d53beaf8242 warehouse 1024
fetch e6e105d35b3f486292c42ffa52f363c0 warehouses_row 1024
fetch a3cb343f3bf8486c8a0482df5b753c38 launcher_truck 1024
fetch e9f9830ac06c4193b79043d9327a7a69 bunker 1024
"$GODOT" --headless --path . --import

bake $P/hangar/model.gltf hangar 30 z --hide=ceilinglamp,electricbox,barrel,Walllamp --collision
bake $P/mil_buildings/model.gltf bld_office 22 x "--keep=BUILDING 2_1" --collision
bake $P/mil_buildings/model.gltf bld_small 7.5 x "--keep=building 1_0" --collision
bake $P/mil_buildings/model.gltf bld_garage 15 x --keep=garage_2 --collision
bake $P/mil_buildings/model.gltf bld_checkpost 6.5 x --keep=checkpost_3 --collision
bake $P/mil_buildings/model.gltf bld_long 12 x --keep=Cube_4/ --collision
bake $P/mil_buildings/model.gltf bld_booth 5 z --keep=Cube_001_5 --collision
bake $P/control_tower/model.gltf control_tower 24 y --collision --tris=4000
bake $P/radars/model.gltf radar 8 max --keep=Cylinder041 --collision --color=0.33,0.36,0.27
bake $P/fuel_tank/model.gltf fuel_tank 9 max --collision
bake $P/sandbag_wall/model.gltf sandbag_wall 2.6 max --collision
bake $P/concrete_barrier/model.gltf concrete_barrier 3.2 max --keep=Barrel_orange --collision
bake $P/fence/model.gltf fence_panel 2.8 y --keep=Cylinder_007_4 --tris=160
bake $P/watchtower/model.gltf watchtower 9 y --collision
bake $P/container/model.gltf container 12.2 max --collision
bake $P/ural_truck/model.gltf ural_truck 7.4 max --collision --tris=4000
bake $P/humvee/model.gltf humvee 4.7 max --collision
bake $P/street_light/model.gltf street_light 8 y
bake $P/rock_eroded/model.gltf rock_eroded 6 max --collision --layer=1 --tris=450
bake $P/rock_base/model.gltf rock_base 5 max --collision --layer=1 --tris=450
bake $P/checkpoint/model.gltf checkpoint 4.5 max --collision
bake $P/warehouse/model.gltf warehouse 13 y --collision
bake $P/warehouses_row/model.gltf warehouses_row 48 max --collision
bake $P/launcher_truck/model.gltf launcher_truck 10.5 z --hide=Object_2 --yaw=180 --tris=5000
bake $P/bunker/model.gltf bunker 14 x --collision --tris=4000
echo "Bitti. Ham glTF'leri silmek için: tools/prune_prop_sources.sh"
