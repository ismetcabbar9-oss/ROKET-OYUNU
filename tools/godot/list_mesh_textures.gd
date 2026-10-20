extends SceneTree
## Geliştirme aracı: assets/models/props altındaki pişmiş ağların kullandığı doku yollarını yazdırır.


func _initialize() -> void:
	var root: String = "res://assets/models/props"
	for dir: String in DirAccess.get_directories_at(root):
		for f: String in DirAccess.get_files_at(root + "/" + dir):
			if not f.ends_with("_mesh.res"):
				continue
			var mesh: Mesh = load(root + "/" + dir + "/" + f) as Mesh
			for s: int in mesh.get_surface_count():
				var mat: BaseMaterial3D = mesh.surface_get_material(s) as BaseMaterial3D
				if mat == null:
					continue
				for tex: Texture2D in [mat.albedo_texture, mat.normal_texture, mat.metallic_texture, mat.roughness_texture, mat.emission_texture, mat.ao_texture]:
					if tex != null:
						print("TEX ", tex.resource_path)
	quit()
