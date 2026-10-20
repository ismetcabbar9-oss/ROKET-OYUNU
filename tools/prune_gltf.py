#!/usr/bin/env python3
"""glTF'ten belirli malzemeleri kullanan parçaları ve artık kullanılmayan doku/görüntüleri siler.

Örn. bir pakette aynı füzenin ikinci renk varyantı varsa yalnızca biri kalsın (doku belleği yarıya iner).
Kullanım: python3 tools/prune_gltf.py <model.gltf> <malzeme_adı> [malzeme_adı ...]
"""
import json
import sys
from pathlib import Path


def remap(items: list, keep: list[int]) -> tuple[list, dict[int, int]]:
    mapping = {old: new for new, old in enumerate(keep)}
    return [items[i] for i in keep], mapping


def main() -> None:
    path = Path(sys.argv[1])
    drop = set(sys.argv[2:])
    g = json.loads(path.read_text(encoding="utf-8"))
    mats = g["materials"]
    drop_idx = {i for i, m in enumerate(mats) if m.get("name") in drop}

    # Silinecek malzemeyi kullanan ilkelleri çıkar; tamamen boşalan ağları düğümlerden kopar
    for mesh in g["meshes"]:
        mesh["primitives"] = [p for p in mesh["primitives"] if p.get("material") not in drop_idx]
    empty = {i for i, m in enumerate(g["meshes"]) if not m["primitives"]}
    for node in g["nodes"]:
        if node.get("mesh") in empty:
            del node["mesh"]

    used_mesh = sorted({n["mesh"] for n in g["nodes"] if "mesh" in n})
    g["meshes"], mesh_map = remap(g["meshes"], used_mesh)
    for node in g["nodes"]:
        if "mesh" in node:
            node["mesh"] = mesh_map[node["mesh"]]

    used_mat = sorted({p["material"] for m in g["meshes"] for p in m["primitives"] if "material" in p})
    g["materials"], mat_map = remap(mats, used_mat)
    for m in g["meshes"]:
        for p in m["primitives"]:
            if "material" in p:
                p["material"] = mat_map[p["material"]]

    def texture_refs(obj: object) -> list[dict]:
        refs = []
        if isinstance(obj, dict):
            if "index" in obj and len(obj) <= 4 and ("texCoord" in obj or "scale" in obj or "strength" in obj or set(obj) <= {"index", "texCoord", "scale", "strength", "extensions"}):
                refs.append(obj)
            for v in obj.values():
                refs += texture_refs(v)
        elif isinstance(obj, list):
            for v in obj:
                refs += texture_refs(v)
        return refs

    refs = texture_refs(g["materials"])
    used_tex = sorted({r["index"] for r in refs})
    g["textures"], tex_map = remap(g["textures"], used_tex)
    for r in refs:
        r["index"] = tex_map[r["index"]]
    used_img = sorted({t["source"] for t in g["textures"]})
    removed = [g["images"][i]["uri"] for i in range(len(g["images"])) if i not in used_img]
    g["images"], img_map = remap(g["images"], used_img)
    for t in g["textures"]:
        t["source"] = img_map[t["source"]]

    path.write_text(json.dumps(g), encoding="utf-8")
    for uri in removed:
        f = path.parent / uri
        if f.exists():
            f.unlink()
    print(f"{len(drop_idx)} malzeme, {len(empty)} ağ, {len(removed)} doku silindi")


if __name__ == "__main__":
    main()
