@tool
extends RefCounted
## RELIEF (PARALLAX OCCLUSION MAPPING) — a material of `tiles.glb` may carry `extras.mb_relief` (MarchingBlocks writes it
## since 30 October 2026): {"format": "marchingblocks-relief", "version": 1, "height": "relief/<material>_height.png",
## "depth": 0.04}. glTF has no height channel: the height map travels NEXT TO the .glb, in the .mbset folder.
##
## The tiles are drawn TRIPLANAR by default (`MarchingBlocksWorld.triplanar`), and Godot's own parallax
## (`heightmap_deep_parallax`) does not work with triplanar. So a relief material, triplanar on, is drawn by this
## plugin's shader (`SHADER`): the same three world projections and the same repeat as Godot's triplanar, each one
## marched through the height map (8 layers face on, 32 at a grazing angle), then albedo, normal and ORM read at the
## parallaxed UV and blended. Triplanar off: Godot's StandardMaterial3D relief on the file's UVs.
## OFF in a project: Project Settings → `marchingblocks/relief/enabled` (true by default).

const FORMAT := "marchingblocks-relief"
const VERSION := 1
const SETTING := "marchingblocks/relief/enabled"
const LAYERS := Vector2i(8, 32)


## Whether this project draws the relief.
static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, true))


## {material name: {"height": path relative to the .mbset, "depth": float}} for every relief material of a `tiles.glb`,
## read in its glTF JSON chunk (as `mb_animation.gd`). {} when the file cannot be read.
static func of_glb(glb_path: String) -> Dictionary:
	if not FileAccess.file_exists(glb_path):
		return {}
	var bytes := FileAccess.get_file_as_bytes(glb_path)
	if bytes.size() < 20 or bytes.decode_u32(0) != 0x46546C67 or bytes.decode_u32(16) != 0x4E4F534A:
		return {}
	var length := bytes.decode_u32(12)
	var json = JSON.parse_string(bytes.slice(20, 20 + length).get_string_from_utf8())
	var out := {}
	if not json is Dictionary or not json.get("materials") is Array:
		return out
	for m in json["materials"]:
		if not m is Dictionary or not m.get("extras") is Dictionary:
			continue
		var r := read((m["extras"] as Dictionary).get("mb_relief"))
		if not r.is_empty():
			out[str(m.get("name", ""))] = r
	return out


## The relief of a material's "extras" meta (Godot's importer keeps glTF extras there), {} without.
static func of_material(m: Material) -> Dictionary:
	if m == null or not m.has_meta("extras"):
		return {}
	var e: Variant = m.get_meta("extras")
	return read((e as Dictionary).get("mb_relief")) if e is Dictionary else {}


## A valid relief entry, or {} (another format, a newer version, no height).
static func read(v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {}
	var d: Dictionary = v
	if str(d.get("format", "")) != FORMAT or int(d.get("version", 0)) > VERSION or str(d.get("height", "")) == "":
		return {}
	return {"height": str(d["height"]), "depth": maxf(0.0, float(d.get("depth", 0.04)))}


## Marks every relief material of the library: meta "mb_relief" = {"texture": Texture2D, "depth": float}. The height
## image is read in the .mbset folder (`base`). Returns how many materials have a relief.
static func mark(library: MeshLibrary, glb: String) -> int:
	var by_name := of_glb(glb)
	var base := glb.get_base_dir()
	var marked := {}
	for id in library.get_item_list():
		var mesh := library.get_item_mesh(id)
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			if not m is StandardMaterial3D or marked.has(m):
				continue
			var r: Dictionary = by_name.get(m.resource_name, {})
			if r.is_empty():
				r = of_material(m)
			if r.is_empty() or not (m as StandardMaterial3D).normal_enabled:
				continue
			var tex := _texture(base.path_join(r["height"]))
			if tex == null:
				push_warning("MarchingBlocks: the height map %s of « %s » is missing — no relief" % [r["height"], m.resource_name])
				continue
			m.set_meta("mb_relief", {"texture": tex, "depth": r["depth"]})
			marked[m] = true
	return marked.size()


static var _textures := {}


static func _texture(path: String) -> Texture2D:
	if _textures.has(path) and is_instance_valid(_textures[path]):
		return _textures[path]
	var tex: Texture2D = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_textures[path] = tex
	return tex


## Godot's own relief on the material's UVs (triplanar off), or none.
static func set_uv_relief(m: StandardMaterial3D, on: bool) -> void:
	var r: Dictionary = m.get_meta("mb_relief", {})
	var active := on and not r.is_empty()
	m.heightmap_enabled = active
	m.heightmap_texture = r.get("texture") if active else null
	if active:
		m.heightmap_scale = float(r["depth"]) * 100.0
		m.heightmap_deep_parallax = true
		m.heightmap_min_layers = LAYERS.x
		m.heightmap_max_layers = LAYERS.y


## The TRIPLANAR relief material of a still one (made once, kept as its meta "mb_relief_material"), at `uv_scale`
## (1 / (repeat × cell), as Godot's triplanar `uv1_scale`). Its meta "mb_still" is the still material.
static func triplanar_material(still: StandardMaterial3D, uv_scale: float) -> ShaderMaterial:
	var sm: ShaderMaterial = still.get_meta("mb_relief_material") if still.has_meta("mb_relief_material") else null
	if sm == null:
		sm = ShaderMaterial.new()
		sm.shader = shader()
		sm.resource_name = still.resource_name
		sm.set_meta("mb_still", still)
		still.set_meta("mb_relief_material", sm)
		var r: Dictionary = still.get_meta("mb_relief")
		sm.set_shader_parameter("albedo", still.albedo_color)
		sm.set_shader_parameter("texture_albedo", still.albedo_texture)
		sm.set_shader_parameter("has_albedo", still.albedo_texture != null)
		sm.set_shader_parameter("texture_normal", still.normal_texture)
		sm.set_shader_parameter("normal_scale", still.normal_scale)
		sm.set_shader_parameter("roughness", still.roughness)
		sm.set_shader_parameter("metallic", still.metallic)
		sm.set_shader_parameter("texture_roughness", still.roughness_texture)
		sm.set_shader_parameter("has_roughness", still.roughness_texture != null)
		sm.set_shader_parameter("roughness_channel", _channel(still.roughness_texture_channel))
		sm.set_shader_parameter("texture_metallic", still.metallic_texture)
		sm.set_shader_parameter("has_metallic", still.metallic_texture != null)
		sm.set_shader_parameter("metallic_channel", _channel(still.metallic_texture_channel))
		var ao := still.ao_enabled and still.ao_texture != null
		sm.set_shader_parameter("texture_ao", still.ao_texture)
		sm.set_shader_parameter("has_ao", ao)
		sm.set_shader_parameter("ao_channel", _channel(still.ao_texture_channel))
		sm.set_shader_parameter("ao_light_affect", still.ao_light_affect)
		var glow := still.emission_enabled
		sm.set_shader_parameter("emission", still.emission * still.emission_energy_multiplier if glow else Color.BLACK)
		sm.set_shader_parameter("texture_emission", still.emission_texture)
		sm.set_shader_parameter("has_emission", glow and still.emission_texture != null)
		sm.set_shader_parameter("texture_height", r["texture"])
		sm.set_shader_parameter("depth_scale", float(r["depth"]))
		sm.set_shader_parameter("min_layers", LAYERS.x)
		sm.set_shader_parameter("max_layers", LAYERS.y)
	sm.set_shader_parameter("uv_scale", uv_scale)
	return sm


static func _channel(c: int) -> Vector4:
	match c:
		BaseMaterial3D.TEXTURE_CHANNEL_RED:
			return Vector4(1, 0, 0, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
			return Vector4(0, 1, 0, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
			return Vector4(0, 0, 1, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:
			return Vector4(0, 0, 0, 1)
	return Vector4(0.299, 0.587, 0.114, 0)


static var _shader: Shader


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader


## The three projections are Godot's triplanar ones (world position × uv_scale, y flipped): +Z face pos.xy, ±Y pos.xz,
## ±X pos.zy with x mirrored, each weighted by |normal|^4. For each projection: T = d(world)/du, V = d(world)/dv, the
## view in (T, V, N) marches the height map (white = high), the albedo, normal (OpenGL convention: +Y is UP the image,
## i.e. -V) and ORM are read at the hit. The normal is laid on the GEOMETRIC normal (curved tiles stay curved).
const SHADER := """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo = false;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale = 1.0;
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform sampler2D texture_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool has_roughness = false;
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool has_metallic = false;
uniform vec4 metallic_channel = vec4(0.0, 0.0, 1.0, 0.0);
uniform sampler2D texture_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool has_ao = false;
uniform vec4 ao_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float ao_light_affect = 0.0;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D texture_emission : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform bool has_emission = false;
uniform sampler2D texture_height : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float depth_scale = 0.04;
uniform float uv_scale = 1.0;
uniform int min_layers = 8;
uniform int max_layers = 32;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// The UV hit by the view ray in the height map (tangent-space view `v`, z towards the eye).
vec2 march(vec2 uv, vec3 v, vec2 dx, vec2 dy) {
	float n = mix(float(max_layers), float(min_layers), clamp(abs(v.z), 0.0, 1.0));
	float layer = 1.0 / n;
	vec2 step_uv = (v.xy / max(v.z, 0.05)) * depth_scale / n;
	vec2 cur = uv;
	float depth = 1.0 - textureGrad(texture_height, cur, dx, dy).r;
	float level = 0.0;
	for (int i = 0; i < 64; i++) {
		if (level >= depth || float(i) >= n) {
			break;
		}
		cur -= step_uv;
		depth = 1.0 - textureGrad(texture_height, cur, dx, dy).r;
		level += layer;
	}
	vec2 prev = cur + step_uv;
	float after = depth - level;
	float before = (1.0 - textureGrad(texture_height, prev, dx, dy).r) - level + layer;
	float w = after / (after - before + 1e-5);
	return mix(cur, prev, clamp(w, 0.0, 1.0));
}

float channel(vec4 c, vec4 mask) {
	return dot(c, mask);
}

void fragment() {
	vec3 nrm = normalize(w_nrm);
	vec3 wgt = pow(abs(nrm), vec3(4.0));
	wgt /= max(wgt.x + wgt.y + wgt.z, 1e-5);
	vec3 p = w_pos * uv_scale * vec3(1.0, -1.0, 1.0);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - w_pos);
	vec2 uvs[3] = vec2[3](p.zy * vec2(-1.0, 1.0), p.xz, p.xy);
	// d(world)/du and d(world)/dv of each projection (world y is flipped in p).
	vec3 tu[3] = vec3[3](vec3(0.0, 0.0, -1.0), vec3(1.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0));
	vec3 tv[3] = vec3[3](vec3(0.0, -1.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0, -1.0, 0.0));
	vec3 ax[3] = vec3[3](vec3(sign(nrm.x), 0.0, 0.0), vec3(0.0, sign(nrm.y), 0.0), vec3(0.0, 0.0, sign(nrm.z)));
	float ws[3] = float[3](wgt.x, wgt.y, wgt.z);
	vec4 col = vec4(0.0);
	vec3 n_out = vec3(0.0);
	float r_out = 0.0;
	float m_out = 0.0;
	float ao_out = 0.0;
	vec3 e_out = vec3(0.0);
	for (int k = 0; k < 3; k++) {
		vec2 uv = uvs[k];
		vec2 dx = dFdx(uv);
		vec2 dy = dFdy(uv);
		if (ws[k] < 0.01) {
			continue;
		}
		vec3 v = vec3(dot(eye, tu[k]), dot(eye, tv[k]), dot(eye, ax[k]));
		vec2 hit = v.z > 0.0 ? march(uv, v, dx, dy) : uv;
		vec4 a = has_albedo ? textureGrad(texture_albedo, hit, dx, dy) : vec4(1.0);
		col += a * ws[k];
		// Godot's normal maps may be compressed to two channels: z is rebuilt, as Godot does for NORMAL_MAP.
		vec3 tn = vec3(textureGrad(texture_normal, hit, dx, dy).xy * 2.0 - 1.0, 0.0);
		tn.z = sqrt(max(0.0, 1.0 - dot(tn.xy, tn.xy)));
		tn.xy *= normal_scale;
		n_out += normalize(nrm * max(tn.z, 0.05) + tu[k] * tn.x - tv[k] * tn.y) * ws[k];
		r_out += (has_roughness ? channel(textureGrad(texture_roughness, hit, dx, dy), roughness_channel) * roughness : roughness) * ws[k];
		m_out += (has_metallic ? channel(textureGrad(texture_metallic, hit, dx, dy), metallic_channel) * metallic : metallic) * ws[k];
		ao_out += (has_ao ? channel(textureGrad(texture_ao, hit, dx, dy), ao_channel) : 1.0) * ws[k];
		e_out += (has_emission ? textureGrad(texture_emission, hit, dx, dy).rgb : vec3(1.0)) * ws[k];
	}
	ALBEDO = albedo.rgb * col.rgb;
	ROUGHNESS = r_out;
	METALLIC = m_out;
	AO = ao_out;
	AO_LIGHT_AFFECT = ao_light_affect;
	EMISSION = emission.rgb * e_out;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n_out), 0.0)).xyz);
}
"""
