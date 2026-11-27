extends Node3D

const BlenderModels = preload("res://blender_models.gd")
const Starter = preload("res://starter_layout.gd")
var shoreline:=preload("res://shoreline.gd").new(-1,0)
var landscape: RefCounted
var world_grid = Starter.new_grid()
const WOOD := "906744"
const TRAIL := "d2b58e"

var meshes := {}
var batches := {}
var imported_groups: Dictionary = {}
var blender_batches: Array[MultiMeshInstance3D] = []
var imported_counts: Dictionary = {}
var grass_batches: Array[MultiMeshInstance3D] = []
var world_materials: Array[ShaderMaterial] = []
var scenic_material: StandardMaterial3D
var contact_batches: Array[MultiMeshInstance3D] = []
var contact_material: ShaderMaterial
var lantern_material: StandardMaterial3D
var foliage_batches: Array[MultiMeshInstance3D] = []
var foliage_material: ShaderMaterial
var surface_materials: Dictionary = {}
var lake_probe: ReflectionProbe
var water_surfaces: Array[MultiMeshInstance3D] = []
var water_simple: ShaderMaterial
var water_clear: ShaderMaterial
var bloom_material:=ShaderMaterial.new()
var wet_meshes: Dictionary={}
var wet_materials: Dictionary={}
var last_weather:=Vector3(-1,-1,-1)
var wind_materials: Array[ShaderMaterial] = []
var tree_meshes := {}
var shafts: Array[MultiMeshInstance3D] = []
var shaft_material:=ShaderMaterial.new()
var lake_material: ShaderMaterial
var probe_period := -1
var lamps: Array[OmniLight3D] = []
var quality_level := 2
var path_segments: Array = []
var house_centers: Array[Vector2] = []
var terrain := StaticBody3D.new()

func _ready() -> void:
	add_child(terrain)
	var crown := SphereMesh.new()
	crown.radial_segments = 12
	crown.rings = 6
	crown.height = 1
	crown.radius = 0.5
	var disc := CylinderMesh.new()
	disc.radial_segments = 32
	disc.height = 1
	var cone := CylinderMesh.new()
	cone.radial_segments = 12
	cone.top_radius = 0
	cone.height = 1
	var trunk := CylinderMesh.new()
	trunk.radial_segments = 10
	trunk.rings = 1
	trunk.top_radius = 0.37
	trunk.bottom_radius = 0.5
	trunk.height = 1
	meshes = {"box": BoxMesh.new(), "round": crown, "disc": disc, "pine": cone, "roof": PrismMesh.new(), "trunk": trunk, "ground": BoxMesh.new(), "water": disc, "shore": disc, "grass": grass_mesh(), "leaf": leaf_mesh(), "canopy": crown, "bark": trunk, "stone": crown, "path_box": BoxMesh.new(), "path_disc": disc, "roof_tiles": PrismMesh.new(), "wood": BoxMesh.new()}
	var contact_plane := PlaneMesh.new()
	contact_plane.size = Vector2.ONE
	meshes["contact"] = contact_plane
	meshes["flower_part"]=crown
	bloom_material.shader=preload("res://shaders/wind_flowers.gdshader")
	meshes["sunshaft"]=QuadMesh.new()
	shaft_material.shader=preload("res://shaders/sunshaft.gdshader")
	meshes["lantern_glass"] = BoxMesh.new()
	if landscape:
		shoreline=landscape.shoreline
		landscape.render(self)
	else:
		world_grid.bounds=shoreline.AREA
		build_paths()
		build_homes()
		build_lake()
		build_groves()
		garden_details()
		beautify_starter()
		plant_grass()
		build_lamps()
	wall(Vector3(0,-0.3,0),Vector3(94,0.6,78))
	world_grid.terrain_provider=shoreline.terrain_at
	shoreline.add_boundary(self)
	var plane:=PlaneMesh.new()
	plane.size=Vector2.ONE
	meshes["water"]=plane
	for z in range(-60,61,8):
		for x in range(-68,69,8):
			if shoreline.distance_at(Vector2(x,z))<8:
				piece("water",Vector3(x,0.052,z),Vector3(8,1,8),"79bec0")
	flush_batches()
	flush_imported()
	setup_lake_probe()

# Share primitive geometry and draw repeated scenery in spatial batches.
func piece(kind: String, position_3d: Vector3, size: Vector3, tint: String, angle := 0.0) -> void:
	var key := "%s:%d:%d" % [kind, floori(position_3d.x / 16), floori(position_3d.z / 16)]
	if not batches.has(key):
		batches[key] = []
	var basis := Basis(Vector3.UP, angle) * Basis.from_scale(size)
	batches[key].append([Transform3D(basis, position_3d), Color(tint)])

# Keep imported scenery spatially batched just like the procedural geometry.
func imported_model(name: String, pos: Vector3, size: Vector3) -> bool:
	var parts := BlenderModels.parts(name)
	if parts.is_empty():
		return false
	var key := "%s:%d:%d" % [name, floori(pos.x/16), floori(pos.z/16)]
	if not imported_groups.has(key):
		imported_groups[key] = {"name":name,"parts": parts, "transforms": []}
	imported_groups[key]["transforms"].append(Transform3D(Basis.from_scale(size), pos))
	imported_counts[name] = int(imported_counts.get(name, 0)) + 1
	return true

func flush_imported() -> void:
	for group in imported_groups.values():
		var transforms: Array = group["transforms"]
		for part in group["parts"]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = wind_mesh(part[0]) if group.name in ["tree","pine","fruit_tree"] else weather_mesh(part[0])
			mm.instance_count = transforms.size()
			var local: Transform3D = part[1]
			for i in transforms.size():
				var placement: Transform3D = transforms[i]
				mm.set_instance_transform(i, placement * local)
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = mm
			add_child(instance)
			blender_batches.append(instance)
	imported_groups.clear()

func weather_mesh(original: Mesh) -> Mesh:
	if wet_meshes.has(original): return wet_meshes[original]
	var mesh:=original.duplicate() as Mesh
	for i in mesh.get_surface_count():
		var original_mat:=original.surface_get_material(i) as StandardMaterial3D
		if not original_mat: continue
		if not wet_materials.has(original_mat): wet_materials[original_mat]=original_mat.duplicate()
		mesh.surface_set_material(i,wet_materials[original_mat])
	wet_meshes[original]=mesh
	return mesh

func wind_mesh(original: Mesh) -> Mesh:
	if tree_meshes.has(original): return tree_meshes[original]
	var mesh:=original.duplicate() as Mesh
	for i in mesh.get_surface_count():
		var paint:=mesh.surface_get_material(i) as StandardMaterial3D
		if paint==null or not (paint.resource_name.begins_with("Leaf") or paint.resource_name.begins_with("Needles")): continue
		var wind:=ShaderMaterial.new()
		wind.shader=preload("res://shaders/canopy.gdshader")
		wind.set_shader_parameter("paint",paint.albedo_texture)
		mesh.surface_set_material(i,wind)
		wind_materials.append(wind)
	tree_meshes[original]=mesh
	return mesh

func landscape_material(water: bool, refract := false) -> ShaderMaterial:
	var shader := Shader.new()
	if water:
		shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform int quality = 2;
#ifdef CLEAR_WATER
uniform sampler2D scenery : hint_screen_texture, repeat_disable, filter_linear;
#endif

uniform sampler2D shore_map : repeat_disable, filter_linear;
uniform vec4 sky_tint : source_color = vec4(0.55,0.72,0.82,1.0);
uniform float daylight = 1.0;
uniform float water_wind = 0.08;
uniform float water_rain = 0.0;
uniform float water_cloud = 0.0;
uniform vec3 bank_actor = vec3(0.0,0.0,0.0);
varying vec3 world_pos;
float ripple_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
vec2 rain_ring(vec2 p,float scale,float rate) {
	vec2 cell=floor(p*scale);
	vec2 local=fract(p*scale);
	vec2 center=vec2(ripple_hash(cell),ripple_hash(cell+vec2(17.3,29.1)))*0.30+0.35;
	float age=fract(TIME*rate+ripple_hash(cell+vec2(9.2,4.6)));
	vec2 q=local-center;
	float d=length(q);
	float wave=(d-age*0.42)*70.0;
	float envelope=(1.0-smoothstep(0.03,0.12,abs(d-age*0.42)))*sin(age*3.14159);
	return q/max(d,0.015)*sin(wave)*envelope;
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_pos.xz;
	vec2 banks = (texture(shore_map,p/vec2(100.,84.)+0.5).rg-0.5)*16.;
	float distance_to_land = -min(banks.x,banks.y);
	float ocean = step(banks.x,banks.y);
	// Signed shoreline: animate the waterline on both sides of the dry coast.
	float agitation=clamp(water_wind*0.75+water_rain*0.40,0.0,1.0);
	float surge = 0.10 + (0.43+agitation*0.52) * (0.5+0.5*sin(TIME*(1.45+agitation*0.85) + sin(p.x*0.19+p.y*0.13)*0.85));
	float runup = mix(0.035, surge, ocean);
	if (distance_to_land < -runup) discard;
	float depth = smoothstep(0.,5.0,max(0.0,distance_to_land));
	float shore = 1.0-depth;
	float t = TIME*(1.0+agitation*0.65);
	vec2 flow = normalize(vec2(0.83,0.56));
	float a = dot(p,flow)*2.5 - t*1.35;
	float b = dot(p,vec2(-0.46,0.89))*4.1 - t*0.83;
	float c = p.x*6.4 + p.y*2.2 - t*2.4;
	float wave_a = sin(a+0.65*sin(b*0.56));
	float wave_b = sin(b+0.50*sin(a*0.72));
	float wave_c = sin(c+wave_b);
	vec3 sand = mix(vec3(0.28,0.72,0.61),vec3(0.19,0.46,0.44),water_cloud*0.55);
	vec3 deep = mix(vec3(0.035,0.35,0.39),vec3(0.022,0.25,0.43),ocean);
	deep=mix(deep,vec3(0.10,0.20,0.25),water_cloud*0.48);
	vec3 water = mix(sand,deep,depth);
	float wash = distance_to_land - (0.17+0.09*sin(t*1.3+dot(p,vec2(.7,.43))));
	float crest = (1.0-smoothstep(0.035,0.14,abs(wash))) * (0.10+0.07*wave_b);
	float nx = 0.0;
	float nz = 0.0;
	if (quality>0) {
		crest += smoothstep(0.70,0.99,wave_a*0.65+wave_b*0.35)*0.075;
		nx = cos(a)*0.09;
		nz = cos(b)*0.075;
	}
	if (quality>=2) {
		float caustic = pow(1.0-abs(sin(a*1.5+wave_b*0.9)*sin(b*1.4+wave_a)),7.0);
		water += vec3(0.10,0.14,0.09)*caustic*(1.0-depth)*daylight;
		crest += smoothstep(0.82,1.0,wave_c*0.65+wave_a*0.35)*0.055;
		nx += cos(c)*0.035;
		nz += cos(b*1.7+wave_a)*0.04;
		float bank = shore + sin(a*0.7)*0.012;
		float foam = smoothstep(0.91,0.95,bank)*(1.0-smoothstep(0.97,1.0,bank));
		float foam_break = smoothstep(-0.30,0.65,sin(a*0.8+wave_b+t*0.25));
		crest += foam*foam_break*(0.10+0.07*daylight);
	}
	float amplitude=mix(0.75,1.85,agitation)*mix(0.75,1.0,ocean);
	nx*=amplitude;
	nz*=amplitude;
	if (quality>0 && water_rain>0.02) {
		vec2 ripple=rain_ring(p,1.4,1.1);
		if (quality>=2) { ripple+=rain_ring(p+vec2(0.41,0.73),2.1,1.6)*0.65; }
		nx+=ripple.x*water_rain*0.24;
		nz+=ripple.y*water_rain*0.24;
		crest+=length(ripple)*water_rain*0.028;
	}
	if (quality>0 && bank_actor.z>0.02) {
		vec2 q=p-bank_actor.xy;
		float d=length(q);
		float wake=sin(d*18.0-TIME*9.0)*exp(-d*1.5)*bank_actor.z;
		vec2 n=q/max(d,0.02)*wake*0.22;
		nx+=n.x;
		nz+=n.y;
		crest+=abs(wake)*0.022;
	}
	vec3 n_world = normalize(vec3(nx,1.0,nz));
	NORMAL = normalize(mat3(VIEW_MATRIX)*n_world);
	float fresnel = pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),3.0);
	water = mix(water,sky_tint.rgb, (0.09+fresnel*0.32)*(quality>=2?1.0:0.35));
		// A breaking crest follows the moving contour; a thin wash remains behind it.
	float front = distance_to_land + runup;
	float lace = 0.72 + 0.28*sin(p.x*13.0+p.y*9.0+wave_b*2.0);
	float breaker = (1.0-smoothstep(0.025,0.18+agitation*0.17,front))*ocean*lace;
	if (quality>=2) {
		float chop=smoothstep(0.89,0.99,wave_a*0.62+wave_b*0.25+wave_c*0.13);
		breaker+=chop*agitation*agitation*0.19*mix(0.45,1.0,ocean);
	}
	float backwash = (1.0-smoothstep(0.04,0.20,abs(front-0.52)))*ocean*0.22;
	float film = ocean*(1.0-smoothstep(-0.15,0.65,distance_to_land));
	water = mix(water,vec3(0.54,0.54,0.32),film*0.50);
	ALBEDO = mix(water + vec3(crest*0.78,crest,crest*0.94),vec3(0.93,0.98,0.93),clamp(breaker*0.84+backwash,0.0,1.0));
	ROUGHNESS = quality==3 ? 0.19+0.12*(1.0-wave_a)*0.5+agitation*0.15 : (quality==2?0.32+agitation*0.18:0.83);
	METALLIC = 0.0;
#ifdef CLEAR_WATER
	vec2 bend = (mat3(VIEW_MATRIX)*vec3(nx,0.,nz)).xy * (.006+.014*depth);
	vec3 riverbed = texture(scenery,clamp(SCREEN_UV+bend,vec2(.001),vec2(.999))).rgb;
	float opacity = clamp(mix(.42,.88,depth) + fresnel*.07 + breaker*.48,0.0,1.0);
	ALBEDO *= opacity;
	EMISSION = riverbed*(1.-opacity);
#endif
	SPECULAR = quality>=2 ? 0.48 : 0.0;
}
"""
	else:
		shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform int quality = 2;
uniform sampler2D shore_map : repeat_disable, filter_linear;
uniform float rain_wet=0.;
uniform float cloud_cover=0.;
uniform sampler2D art_grass : source_color, repeat_enable, filter_linear_mipmap;
uniform bool has_art_grass = false;
varying vec3 world_pos;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_pos.xz;
	float patch = sin(p.x * 0.54 + sin(p.y * 0.32)) * cos(p.y * 0.61);
	vec2 cell = floor(p * 2.4);
	vec2 f = fract(p * 2.4) - 0.5;
	float fleck = (1.0 - smoothstep(0.045, 0.13, length(f * vec2(0.85, 1.5)))) * step(0.79, hash(cell));
	float detail = hash(floor(p * 18.0)) - 0.5;
	float mottling = sin(p.x * 3.0 + sin(p.y * 2.0)) * cos(p.y * 2.8);
	float shade = 0.034 * patch;
	if (quality > 0) { shade += 0.021 * fleck; }
	if (quality > 1) { shade += 0.011 * detail + 0.009 * mottling; }
	if (quality == 3) { shade += 0.012 * sin(p.x * 7.0 + p.y * 5.0) * cos(p.y * 8.0); }
	vec3 grass_base = vec3(0.30, 0.59, 0.13);
	if (has_art_grass && quality > 0) {
		grass_base = mix(grass_base, texture(art_grass, p * 0.5).rgb, 0.38);
	}
	ALBEDO = grass_base * mix(vec3(1.),COLOR.rgb / vec3(.58,.71,.47),0.28) + vec3(shade, shade, shade * 0.55);
	vec2 bank=(texture(shore_map,p/vec2(100.,84.)+0.5).rg-0.5)*16.;
	float wet=min(bank.x,bank.y);
	float edge=min(bank.x-2.75,bank.y-0.85)+patch*0.22;
	vec3 beach=mix(vec3(.48,.34,.19),vec3(.91,.77,.50),smoothstep(-.45,1.20,wet));
	float tide=0.14+0.43*(0.5+0.5*sin(TIME*1.65+sin(p.x*0.19+p.y*0.13)*0.85));
	float damp=(1.0-smoothstep(tide+0.10,tide+0.65,bank.x))*step(bank.x,bank.y);
	beach*=mix(1.0,0.73,damp);
	ALBEDO=mix(beach*(1.+0.044*detail+0.023*patch),ALBEDO,smoothstep(-.55,.55,edge));
	float pool=0.;
	if(rain_wet>.01){
		float basin=sin(p.x*1.5+sin(p.y*.85))*cos(p.y*1.21+.7*sin(p.x*.81));
		pool=smoothstep(.79,.93,basin)*smoothstep(.1,.55,rain_wet)*smoothstep(.25,1.3,wet);
		float ring=sin(length(fract(p*1.6)-.5)*27.-TIME*8.);
		vec3 reflection=vec3(.28,.44,.46)*(1.+.08*ring);
		ALBEDO=mix(ALBEDO*(1.-.23*rain_wet),reflection,pool*.79);
	}
	if(cloud_cover>.015){
		float shade_cloud=.5+.5*sin(p.x*.16+TIME*.14+sin(p.y*.22))*cos(p.y*.11+TIME*.11);
		ALBEDO*=1.-cloud_cover*shade_cloud*.15;
	}
	ROUGHNESS=mix(.98,.21,pool);
	SPECULAR=.08+.40*pool;
}
"""
	var result := ShaderMaterial.new()
	if water and refract:
		shader.code=shader.code.replace("shader_type spatial;","shader_type spatial;\n#define CLEAR_WATER")
	result.shader = shader
	if not water:
		var grass := preload("res://art_assets.gd").surface("grass")
		if grass != null:
			result.set_shader_parameter("art_grass", grass)
			result.set_shader_parameter("has_art_grass", true)
	return result

func flush_batches() -> void:
	var material := StandardMaterial3D.new()
	scenic_material = material
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic_specular = 0.04
	var grain := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var shade := 0.96 + 0.025*sin(float(x)*0.73+sin(float(y)*0.24))*cos(float(y)*0.47) + 0.012*sin(float(x*7+y*13))
			grain.set_pixel(x,y,Color(shade,shade,shade))
	grain.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(grain)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	contact_material = make_contact_material()
	lantern_material = StandardMaterial3D.new()
	lantern_material.albedo_color = Color("ffd99b")
	lantern_material.roughness = 0.85
	lantern_material.emission_enabled = true
	lantern_material.emission = Color("ffbd65")
	lantern_material.emission_energy_multiplier = 0.0
	var tuft_material := grass_shader()
	var grass_material := landscape_material(false)
	water_simple=landscape_material(true)
	water_clear=landscape_material(true,true)
	var banks:=shoreline.texture()
	for mat in [grass_material,water_simple,water_clear]:
		mat.set_shader_parameter("shore_map",banks)
	lake_material=water_clear
	foliage_material = make_foliage_material()
	surface_materials = {"bark":make_surface_material(0),"stone":make_surface_material(1),"path_box":make_surface_material(2),"path_disc":make_surface_material(2),"roof_tiles":make_surface_material(3),"wood":make_surface_material(4)}
	world_materials = [grass_material,water_simple,water_clear,tuft_material]
	for key: String in batches:
		var items: Array = batches[key]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		var kind := key.get_slice(":", 0)
		batch.mesh = meshes[kind]
		batch.instance_count = items.size()
		for i in items.size():
			batch.set_instance_transform(i, items[i][0])
			batch.set_instance_color(i, items[i][1])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = batch
		instance.material_override = material
		if kind == "ground":
			instance.material_override = grass_material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif kind == "water":
			water_surfaces.append(instance)
			instance.material_override = lake_material
			instance.layers = 2
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif kind == "sunshaft":
			instance.material_override=shaft_material
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shafts.append(instance)
		elif kind == "lantern_glass":
			instance.material_override = lantern_material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif kind == "contact":
			instance.material_override = contact_material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			contact_batches.append(instance)
		elif kind=="flower_part":
			instance.material_override=bloom_material
		elif kind == "grass":
			instance.material_override = tuft_material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.extra_cull_margin = 0.35
			grass_batches.append(instance)
		elif kind in ["leaf","canopy"]:
			instance.material_override = foliage_material
			instance.extra_cull_margin = 0.6
			if kind=="leaf": foliage_batches.append(instance)
		elif surface_materials.has(kind):
			instance.material_override = surface_materials[kind]
		elif kind == "shore":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	batches.clear()

func wall(pos: Vector3, size: Vector3, angle := 0.0) -> void:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.position = pos
	collider.rotation.y = angle
	terrain.add_child(collider)
	if pos.y+size.y*0.5>0.1:
		var extent := Vector2(absf(cos(angle))*size.x+absf(sin(angle))*size.z,absf(sin(angle))*size.x+absf(cos(angle))*size.z)
		world_grid.reserve_box(Vector2(pos.x,pos.z),extent,"Construção ou obstáculo")

func path_between(a: Vector2, b: Vector2, width: float) -> void:
	path_segments.append([a,b,width])
	world_grid.reserve_line(a,b,width,"Caminho da vila")
	var mid := (a + b) / 2
	var line := b - a
	piece("path_box", Vector3(mid.x,0.014,mid.y), Vector3(width,0.02,line.length()), TRAIL, atan2(line.x,line.y))
	piece("path_disc", Vector3(b.x,0.019,b.y), Vector3(width,0.02,width), TRAIL)

func build_paths() -> void:
	piece("ground", Vector3(0,-0.32,0), Vector3(120,0.64,102), "91b579")
	wall(Vector3(0,-0.3,0), Vector3(70,0.6,56))
	var plaza := Vector2(0,2)
	world_grid.reserve_box(plaza,Vector2(12,9),"Praça pública")
	piece("path_disc", Vector3(0,0.038,2), Vector3(12,0.03,9), "d7bc96")
	# A loop links the cottages, orchard and lakeside picnic spot.
	var loop := PackedVector2Array([plaza, Vector2(-12,3), Vector2(-22,1), Vector2(-22,12), Vector2(-12,16), Vector2(3,15), Vector2(14,9), Vector2(16,1), Vector2(9,-1), plaza])
	for i in range(1,loop.size()):
		path_between(loop[i-1],loop[i],2.2)
	path_between(Vector2(-12,3),Vector2(-12,-4),2)
	path_between(plaza,Vector2(0,-9),2.7)
	path_between(Vector2(9,-1),Vector2(10,-6),2)
	path_between(Vector2(-22,1),Vector2(-24,-9),1.7)
	# Central shade tree on a low circular planter.
	piece("disc",Vector3(-2,0.14,1),Vector3(3,0.25,3),"ac9577")
	tree(-2,1,1.05,0)
	bench(-4.3,3.2)
	bench(14,6)

func build_homes() -> void:
	cottage(-7,19.45,"628693","f3d1a0")
	path_between(Vector2(-10,16),Vector2(-10,21.65),1.5)
	path_between(Vector2(-10,21.65),Vector2(-7,21.65),1.5)
	cottage(-24,-11,"946e57","e6cfa8")
	cottage(13,12.8,"96778c","efd0b5")
	cottage(-3,10,"577453","f3da9e")
	for i in 7:
		piece("box",Vector3(-4.5+i*0.5,2.1,12.1),Vector3(0.5,0.16,0.95),"eac889" if i%2==0 else "788c6a")
	path_between(Vector2(-3,14.4),Vector2(-3,12.1),1.8)
	path_between(Vector2(13,15.2),Vector2(16,15.2),1.7)
	path_between(Vector2(16,15.2),Vector2(16,9),1.7)
	cottage(-12,-6,"b76349","efd2a2")
	cottage(0,-11,"597e80","f0d8ab")
	cottage(10,-8,"84905d","eac398")
	for x in [-16,-8,6,14]:
		fence(Vector2(x,-8),Vector2(x,-3))
	fence(Vector2(-4,-13),Vector2(-4,-8))
	fence(Vector2(4,-13),Vector2(4,-8))
	for x in [-14,-10,-2,2,8,12]:
		var z := -3.8 if x < -5 else (-8.8 if x < 4 else -5.8)
		flowers(x,z,"edac69" if x < 4 else "e6b4af")

func cottage(x: float,z: float,roof: String,plaster: String) -> void:
	house_centers.append(Vector2(x,z))
	var center := Vector3(x,1.22,z)
	world_grid.reserve_box(Vector2(x,z),Vector2(5.2,4.2),"Edifício")
	contact_at(Vector2(x,z),Vector2(6.1,5.0),0.065)
	wall(center,Vector3(4.4,2.44,3.4))
	if imported_model("house_"+roof,Vector3(x,0,z),Vector3(4.4/3.0,1.20,3.4/2.3)):
		return
	piece("box",center,Vector3(4.4,2.44,3.4),plaster)
	piece("box",Vector3(x,0.19,z),Vector3(4.5,0.38,3.5),"988874")
	piece("roof_tiles",Vector3(x,3.13,z),Vector3(5.15,1.55,4.15),roof)
	# Rounded eaves and timber trim add a handcrafted silhouette.
	var trim := Color(roof).darkened(0.15).to_html(false)
	for dz in [-1.91,1.91]:
		piece("round",Vector3(x,2.40,z+dz),Vector3(5.06,0.26,0.35),trim)
	piece("round",Vector3(x,3.88,z),Vector3(4.87,0.23,0.32),roof)
	piece("box",Vector3(x,0.10,z+1.91),Vector3(1.45,0.20,0.48),"b8a28a")
	piece("box",Vector3(x+1.35,3.41,z-0.7),Vector3(0.46,1.65,0.52),"947c69")
	piece("wood",Vector3(x,0.85,z+1.74),Vector3(0.93,1.7,0.12),WOOD)
	piece("round",Vector3(x+0.29,0.77,z+1.83),Vector3(0.12,0.12,0.09),"e7bf77")
	for dx in [-1.42,1.42]:
		piece("box",Vector3(x+dx,1.4,z+1.72),Vector3(0.98,1.02,0.08),WOOD)
		piece("box",Vector3(x+dx,1.4,z+1.78),Vector3(0.76,0.8,0.06),"91c1bc")
		piece("box",Vector3(x+dx,1.4,z+1.82),Vector3(0.08,0.83,0.04),"f1dcb8")
		piece("box",Vector3(x+dx,0.88,z+1.87),Vector3(1.08,0.12,0.30),"a57a56")
		for j in 3:
			piece("round",Vector3(x+dx+(j-1)*0.25,1.02,z+1.96),Vector3(0.24,0.22,0.20),"719a54")
			piece("round",Vector3(x+dx+(j-1)*0.25,1.14,z+1.98),Vector3(0.16,0.12,0.16),["efbe78","e8a5a2","f1d9a5"][j])

func fence(a: Vector2,b: Vector2) -> void:
	var line := b-a
	var mid := (a+b)/2
	var angle := atan2(line.x,line.y)
	var count := ceili(line.length()/1.7)
	for i in range(count+1):
		var p := a.lerp(b,float(i)/count)
		piece("trunk",Vector3(p.x,0.49,p.y),Vector3(0.24,0.98,0.24),"997751")
		piece("round",Vector3(p.x,0.99,p.y),Vector3(0.26,0.20,0.26),"c49c70")
	for h in [0.34,0.71]:
		piece("box",Vector3(mid.x,h,mid.y),Vector3(0.13,0.14,line.length()),"bb9569",angle)
	wall(Vector3(mid.x,0.5,mid.y),Vector3(0.22,1,line.length()+0.2),angle)

func bench(x: float,z: float) -> void:
	contact_at(Vector2(x,z),Vector2(2.7,1.45),0.062)
	wall(Vector3(x,0.48,z),Vector3(2,0.96,0.65))
	if imported_model("bench",Vector3(x,0,z),Vector3(1.16,0.96,1.0)):
		return
	for dx in [-0.7,0.7]:
		piece("box",Vector3(x+dx,0.27,z),Vector3(0.21,0.54,0.58),WOOD)
	for j in 4:
		piece("box",Vector3(x,0.55,z-0.24+j*0.16),Vector3(2,0.14,0.14),"bb8a59")
	for j in 2:
		piece("box",Vector3(x,0.80+j*0.21,z-0.28),Vector3(2,0.17,0.12),"a77b52")
	for dx in [-0.83,0.83]:
		piece("round",Vector3(x+dx,0.71,z),Vector3(0.20,0.18,0.60),WOOD)

func build_lake() -> void:
	var x := 22.0
	var z := -7.0
	for ix in range(15,30):
		for iz in range(-16,3):
			if (Vector2(ix-x,iz-z)/Vector2(6.9,8.9)).length()<=1.0:
				world_grid.reserve_rect(Rect2i(ix,iz,1,1),"Lago e margem")
	for i in 7:
		var a := i*2.4
		var p := Vector3(x+4.9*cos(a),0.17,z+6.4*sin(a))
		piece("disc",p,Vector3(0.65,0.035,0.54),"719e65")
		if i%2==0:
			piece("round",p+Vector3.UP*0.08,Vector3(0.22,0.13,0.21),"f4d5b4")
	for p in [Vector2(17,-13),Vector2(27,-2),Vector2(27,-12),Vector2(21,2)]:
		for j in 5:
			piece("pine",Vector3(p.x+0.17*j,0.38,p.y+0.16*sin(j)),Vector3(0.21,0.76,0.2),"748e57")

func tree(x: float,z: float,s: float,kind: int) -> void:
	var base := Vector3(x,0,z)
	if posmod(roundi(x*3+z),7)==0:
		var key: String="sunshaft:%d:%d" % [floori(x/16),floori(z/16)]
		if not batches.has(key): batches[key]=[]
		var beam:=Basis(Vector3.BACK,-0.48)*Basis.from_scale(Vector3(0.85,3.6,1.0)*s)
		batches[key].append([Transform3D(beam,base+Vector3(-0.5,1.6,0)*s),Color.WHITE])
	world_grid.reserve_box(Vector2(x,z),Vector2(1.6,1.6)*s,"Árvore")
	contact_at(Vector2(x,z),Vector2(2.6,2.4)*s,0.058)
	wall(base+Vector3.UP*s,Vector3(0.65,2,0.65)*s)
	var model: String = ["tree","pine","fruit_tree"][kind]
	var model_scale := Vector3.ONE if kind==1 else Vector3(1.40,1.39,1.40)
	if imported_model(model,base,model_scale*s):
		return
	piece("bark",base+Vector3.UP*s,Vector3(0.72,2,0.72)*s,WOOD)
	piece("round",base+Vector3.UP*0.14*s,Vector3(0.95,0.29,0.85)*s,WOOD)
	if kind == 1:
		for i in 3:
			var w := 2.9-i*0.61
			piece("pine",base+Vector3.UP*(1.9+i*0.76)*s,Vector3(w,2,w)*s,["50785c","628567","769672"][i])
			piece("round",base+Vector3.UP*(1.15+i*0.76)*s,Vector3(w*0.86,0.48,w*0.86)*s,["50785c","628567","769672"][i])
	else:
		var dark := "4c823a" if kind == 0 else "65983e"
		var light := "8fba4e" if kind == 0 else "a9c65a"
		piece("canopy",base+Vector3(0,2.45,0)*s,Vector3(3.3,2.7,3)*s,dark)
		piece("canopy",base+Vector3(-0.75,2.7,0.19)*s,Vector3(2.12,1.92,2.02)*s,light)
		piece("canopy",base+Vector3(0.72,2.78,-0.17)*s,Vector3(2.20,2.10,2.10)*s,dark)
		piece("canopy",base+Vector3(-0.15,3.40,-0.12)*s,Vector3(2.45,1.95,2.28)*s,light)
		# Individual leaves follow a rounded crown rather than random floating spheres.
		for i in 32:
			var a := i*2.399963
			var band := (float(i)+0.5)/32.0
			var y := lerpf(-0.42,0.95,band)
			var r := sqrt(maxf(0.0,1.0-y*y))
			var off := Vector3(cos(a)*r*1.45,2.85+y*1.2,sin(a)*r*1.31)
			var tint := light if i%3!=0 else dark
			piece("leaf",base+off*s,Vector3(0.68,0.56,0.75)*s,tint,a+PI/2)
		if kind == 2:
			for offset in [Vector3(-0.7,2.6,1.15),Vector3(0.63,2.3,1.24),Vector3(1.34,2.65,0.15)]:
				piece("round",base+offset*s,Vector3.ONE*0.31*s,"d8815d")

func flowers(x: float,z: float,color: String) -> void:
	world_grid.reserve_box(Vector2(x,z),Vector2(1.0,1.0),"Canteiro")
	for i in 8:
		var p := Vector3(x+cos(i*2.4)*sqrt(i)*0.28,0,z+sin(i*2.4)*sqrt(i)*0.21)
		piece("flower_part",p+Vector3.UP*0.14,Vector3(0.31,0.28,0.25),"658b59")
		for j in 4:
			var angle := TAU*j/4.0
			piece("flower_part",p+Vector3(cos(angle)*0.09,0.29,sin(angle)*0.09),Vector3(0.15,0.10,0.15),color)
		piece("flower_part",p+Vector3.UP*0.33,Vector3(0.10,0.075,0.10),"e4b65d")

func build_groves() -> void:
	for i in range(-5,6):
		tree(i*5.6,-21+sin(i)*1.4,1.05+0.12*cos(i),posmod(i,2))
		tree(i*5.6,24+cos(i),0.92+0.13*sin(i),posmod(i+1,2))
	for i in range(-3,4):
		tree(-29+sin(i),i*5.6,1.04,posmod(i,2))
		tree(30+cos(i),i*5.6,0.95,posmod(i+1,2))
	for x in [-20,-25]:
		for z in [5,9,15]:
			tree(x,z,0.83,2)
	for p in [Vector2(-18,-12),Vector2(-9,11),Vector2(6,10),Vector2(19,16),Vector2(-6,-15)]:
		tree(p.x,p.y,0.95,0)
		flowers(p.x+1.2,p.y+0.9,"f1d99c")
	for p in [Vector2(17,-16),Vector2(25,3),Vector2(-26,-12),Vector2(-17,18),Vector2(20,13)]:
		for j in 2:
			var w := 1.6-j*0.65
			var pos := Vector3(p.x+j*1.1,w*0.24,p.y+j*0.55)
			contact_at(Vector2(pos.x,pos.z),Vector2(w*1.65,w*1.5),0.052)
			piece("stone",pos,Vector3(w,w*0.77,w*0.9),"93988a")
			wall(pos,Vector3(w*0.84,w*0.69,w*0.77))

# Small landscaping accents outside paths and doors; purely decorative.
func garden_details() -> void:
	for p in [Vector2(-18,-13),Vector2(-7,-17),Vector2(6,11),Vector2(19,17),Vector2(-26,-13),Vector2(-17,19),Vector2(26,4)]:
		world_grid.reserve_box(p+Vector2(0.56,0),Vector2(1.8,0.9),"Arbustos")
		for j in 3:
			var center := Vector3(p.x+j*0.56,0.27,p.y+sin(j*1.8)*0.34)
			piece("round",center,Vector3(0.77,0.62,0.72),["719954","83a862","658b4f"][j])
			if j==1:
				piece("round",center+Vector3(0.04,0.26,0.18),Vector3(0.18,0.13,0.18),"edb4a0")

# Starter-only scenery. Keep collision and cell reservations together.
func beautify_starter() -> void:
	# Floral plaza edging leaves the central route and arrival point clear.
	for p in [Vector2(-5,-1),Vector2(5,-1),Vector2(-5,5),Vector2(5,5)]:
		piece("disc",Vector3(p.x,0.09,p.y),Vector3(1.6,0.14,1.2),"bda98a")
		flowers(p.x,p.y,"f5df9a")
	# Wooden storefront planters, with door and route left untouched.
	for x in [-5.0,-1.0]:
		piece("wood",Vector3(x,0.17,12.15),Vector3(0.86,0.34,0.55),"a77d52")
		for j in 3:
			piece("round",Vector3(x+(j-1)*0.23,0.43,12.15),Vector3(0.30,0.32,0.30),"6d9f55")
			piece("round",Vector3(x+(j-1)*0.23,0.59,12.15),Vector3(0.18,0.13,0.18),"f1c981")
		world_grid.reserve_box(Vector2(x,12.15),Vector2(0.9,0.6),"Vasos da loja")
	# Lakeside planting islands; avoid the main walk and the water itself.
	for p in [Vector2(15,-10),Vector2(15,-12),Vector2(19,3),Vector2(23,3)]:
		if world_grid.reason(Rect2i(world_grid.world_to_cell(p),Vector2i.ONE))=="":
			flowers(p.x,p.y,"eac0a1")
	# Residential garden borders and orchard flower patches.
	for p in [Vector2(-18,-5),Vector2(-16,-5),Vector2(6,-4),Vector2(8,-4),Vector2(-21,7),Vector2(-23,13)]:
		if world_grid.reason(Rect2i(world_grid.world_to_cell(p),Vector2i.ONE))=="":
			flowers(p.x,p.y,"d2d6a2")

# Five curved, tapered blades per tuft, shared across all the patches.
func grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var angle := i*2.39996
		var outward := Vector3(cos(angle),0,sin(angle))
		var across := Vector3(-sin(angle),0,cos(angle))
		var base := outward*0.13
		var mid := base + outward*0.17 + Vector3.UP*(0.44+0.07*(i%3))
		var tip := base + outward*0.36 + Vector3.UP*(0.77+0.09*(i%3))
		var a := base-across*0.09
		var b := base+across*0.09
		var c := mid-across*0.055
		var d := mid+across*0.055
		for v in [a,b,c,b,d,c,c,d,tip]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()

func grass_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform int quality = 2;
uniform float air=.08;
varying float height;
varying vec3 tint;
void vertex() {
	height = VERTEX.y;
	tint = COLOR.rgb;
	vec3 p = MODEL_MATRIX[3].xyz;
	float wind = sin(TIME * 1.45 + p.x * 0.55 + p.z * 0.71);
	if (quality > 0) {
		VERTEX.x += wind * height * height * (.13+.43*air);
		VERTEX.z += cos(TIME * 1.1 + p.z * 0.64) * height * height * 0.08;
	}
}
void fragment() {
	ALBEDO = tint * mix(vec3(0.62,0.74,0.58),vec3(1.23,1.19,0.84),clamp(height,0.0,1.0));
	BACKLIGHT = ALBEDO * 0.28 * smoothstep(0.2,0.8,height);
	AO = mix(0.64,1.0,clamp(height*1.7,0.0,1.0));
	ROUGHNESS=.96;
	SPECULAR=0.;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func clear_for_grass(p: Vector2) -> bool:
	if shoreline.terrain_at(p)!="grass": return false
	if landscape and world_grid.reserved.has(Vector2i(p.round())): return false
	if Rect2(-5,16,11,7).has_point(p) or Rect2(2,3.5,7,6).has_point(p):
		return false
	if ((p-Vector2(22,-7))/Vector2(6.7,8.8)).length() < 1.04:
		return false
	if ((p-Vector2(0,2))/Vector2(6.4,4.8)).length() < 1.0:
		return false
	for segment in path_segments:
		var nearest := Geometry2D.get_closest_point_to_segment(p,segment[0],segment[1])
		if p.distance_to(nearest) < float(segment[2])*0.5+0.55:
			return false
	for h in house_centers:
		if absf(p.x-h.x)<3.1 and absf(p.y-h.y)<2.8:
			return false
	return true

func plant_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 60621
	var patches := [Vector2(-18,-14),Vector2(-8,-17),Vector2(6,-15),Vector2(14,-17),
		Vector2(-26,-4),Vector2(-16,9),Vector2(-24,17),Vector2(-12,20),
		Vector2(9,12),Vector2(21,16),Vector2(28,6),Vector2(13,2),
		Vector2(-6,5),Vector2(4,-5),Vector2(-17,-3),Vector2(18,3)]
	for center in patches:
		for i in 105:
			var angle := rng.randf_range(0.0,TAU)
			var radius := sqrt(rng.randf())*2.65
			var p: Vector2 = center+Vector2(cos(angle),sin(angle))*radius
			if not clear_for_grass(p): continue
			var h := rng.randf_range(0.16,0.42)
			var w := rng.randf_range(0.28,0.58)
			piece("grass",Vector3(p.x,0.005,p.y),Vector3(w,h,w),["508331","7caf36","b2d44c","659f32"][rng.randi_range(0,3)],angle)

# Warm village lanterns; visuals stay on every preset, light emitters are optional.
func build_lamps() -> void:
	for p in [Vector2(-5,3),Vector2(5,3),Vector2(-11,1),Vector2(-22,3),Vector2(-21,12),Vector2(14,7),Vector2(12,-1),Vector2(1,-8)]:
		var base := Vector3(p.x,0,p.y)
		world_grid.reserve_box(p,Vector2(0.5,0.5),"Poste")
		piece("trunk",base+Vector3.UP*0.85,Vector3(0.16,1.70,0.16),"534a41")
		piece("disc",base+Vector3.UP*0.10,Vector3(0.39,0.20,0.39),"534a41")
		piece("lantern_glass",base+Vector3.UP*1.77,Vector3(0.29,0.33,0.29),"e4bf79")
		piece("pine",base+Vector3.UP*2.02,Vector3(0.43,0.28,0.43),"51483e")
		var lamp := OmniLight3D.new()
		lamp.position = base+Vector3.UP*1.65
		lamp.light_color = Color("ffc789")
		lamp.light_energy = 0.0
		lamp.omni_range = 5.0
		lamp.omni_attenuation = 1.8
		lamp.shadow_enabled = false
		add_child(lamp)
		lamps.append(lamp)

func set_quality(level: int) -> void:
	quality_level = clampi(level,0,3)
	lake_material=water_clear if quality_level>=2 else water_simple
	for water in water_surfaces: water.material_override=lake_material
	for shaft in shafts: shaft.visible=quality_level==3
	for mat in wind_materials: mat.set_shader_parameter("quality",quality_level)
	for batch in blender_batches:
		batch.lod_bias=[0.45,0.70,1.0,1.45][quality_level]
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality_level>=2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var density := [0.0,0.25,0.55,1.0]
	for batch in contact_batches: batch.visible = quality_level>=1
	for batch in foliage_batches:
		batch.multimesh.visible_instance_count = roundi(batch.multimesh.instance_count*[0.0,0.25,0.65,1.0][quality_level])
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality_level==3 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if foliage_material != null: foliage_material.set_shader_parameter("quality",quality_level)
	for mat in surface_materials.values(): mat.set_shader_parameter("quality",quality_level)
	if lake_probe != null: lake_probe.visible = quality_level>=2
	for batch in grass_batches:
		batch.visibility_range_end=[20.,27.,36.,48.][quality_level]
		batch.multimesh.visible_instance_count = roundi(batch.multimesh.instance_count*float(density[quality_level]))
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality_level==3 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mat in world_materials:
		mat.set_shader_parameter("quality",quality_level)
	if scenic_material != null:
		scenic_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if quality_level>=2 else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for i in lamps.size():
		lamps[i].visible = quality_level==3 or (quality_level==2 and i%2==0)

func update_lamps(daylight: float) -> void:
	var energy := (1.0-daylight)*0.9
	if lantern_material != null:
		lantern_material.emission_energy_multiplier = (1.0-daylight)*(1.5 if quality_level==3 else 0.65)
	for lamp in lamps:
		lamp.light_energy = energy

# Leaves use a simple folded silhouette, not alpha-heavy billboards.
func leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(0,0.32,-0.32)
	var b := Vector3(-0.39,0.04,0.03)
	var c := Vector3(0,-0.20,0.58)
	var d := Vector3(0.39,0.04,0.03)
	var ridge := Vector3(0,0.16,0.06)
	for v in [a,b,ridge,b,c,ridge,c,d,ridge,d,a,ridge]:
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func make_foliage_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform int quality = 2;
uniform float air=.08;
varying vec3 tint;
varying vec3 local_pos;
void vertex() {
	tint = COLOR.rgb;
	local_pos = VERTEX;
	vec3 p = MODEL_MATRIX[3].xyz;
	if (quality>0) {
		float breeze = sin(TIME*1.12+p.x*0.39+p.z*0.24);
		float gust = sin(TIME*0.57+p.z*0.68);
		VERTEX.x += (breeze*0.033+gust*0.022)*(0.5+VERTEX.y)*(1.+air*3.);
		VERTEX.z += gust*0.025;
	}
}
void fragment() {
	float shade = 0.80+0.27*clamp(local_pos.y+0.5,0.0,1.0);
	if (quality>=2) {
		float vein = 1.0-smoothstep(0.015,0.055,abs(local_pos.x));
		shade += vein*0.055;
		shade += sin(local_pos.z*19.0+abs(local_pos.x)*12.0)*0.025;
	}
	ALBEDO = tint*shade;
	AO = mix(0.72,1.0,clamp(local_pos.y+0.5,0.0,1.0));
	ROUGHNESS = 0.78;
	SPECULAR = 0.15;
	BACKLIGHT = tint*(quality>=2?0.09:0.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func make_surface_material(kind: int) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float rain_wet=0.;
uniform int surface_kind = 0;
uniform int quality = 2;
varying vec3 tint;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){
	tint=COLOR.rgb;
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
	vec3 p=world_pos;
	float shade=1.0;
	float n=0.0;
	if(quality>0){
		if(surface_kind==0 || surface_kind==4){
			float grain=sin(p.x*29.0+p.z*23.0+noise2(vec2(p.x*5.0,p.y*2.0))*5.0);
			n=grain*0.07+noise2(vec2(p.x*15.0+p.z*13.0,p.y*3.0))*0.12-0.06;
		}else if(surface_kind==3){
			vec2 tile=vec2(p.x*2.8,p.z*3.1+p.y*1.3);
			tile.x+=0.5*mod(floor(tile.y),2.0);
			vec2 f=fract(tile);
			n=0.07*hash(floor(tile))-0.035-0.13*(1.0-smoothstep(0.02,0.11,min(f.x,f.y)));
		}else{
			n=(noise2(p.xz*4.0+p.y*2.0)-0.5)*0.15;
			if(quality>=2) n+=(noise2(p.xz*22.0+p.y*14.0)-0.5)*0.08;
		}
		shade+=n;
	}
	ALBEDO=tint*shade*(1.-.23*rain_wet);
	AO = quality>0 ? clamp(0.95+n*1.5,0.72,1.0) : 1.0;
	ROUGHNESS=mix(surface_kind==3?0.83:0.94,.42,rain_wet);
	SPECULAR=0.08;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("surface_kind",kind)
	return mat

func setup_lake_probe() -> void:
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()=="gl_compatibility": return
	lake_probe=ReflectionProbe.new()
	lake_probe.position=Vector3(22,1.25,-7)
	if landscape:
		var bank: Vector2=shoreline.lake
		lake_probe.position=Vector3(bank.x,1.25,bank.y)
	lake_probe.size=Vector3(21,12,25)
	lake_probe.intensity=0.65
	lake_probe.max_distance=36.0
	lake_probe.cull_mask=1
	lake_probe.reflection_mask=2
	lake_probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED
	lake_probe.update_mode=ReflectionProbe.UPDATE_ONCE
	lake_probe.box_projection=false
	lake_probe.enable_shadows=false
	add_child(lake_probe)

func update_water_light(sky_color: Color, day: float, phase: float) -> void:
	var elevation:=sin(phase*TAU)
	shaft_material.set_shader_parameter("strength",smoothstep(0.0,0.24,elevation)*(1.0-smoothstep(0.33,0.70,elevation))*0.105)
	for mat in [water_simple,water_clear]:
		if mat:
			mat.set_shader_parameter("sky_tint",sky_color)
			mat.set_shader_parameter("daylight",day)
	if lake_probe != null and quality_level>=2:
		# Refresh captured surroundings a few times per day, not six renders per frame.
		var period := floori(phase*8.0)
		if period!=probe_period:
			probe_period=period
			lake_probe.position.y=1.25+float(period%2)*0.002

# Local soft ambient contact shadows compatible with the Mobile renderer.
func contact_at(pos: Vector2, size: Vector2, height: float) -> void:
	piece("contact",Vector3(pos.x,height,pos.y),Vector3(size.x,1.0,size.y),"ffffff")

func make_contact_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.25;
void fragment(){
	vec2 p=(UV-0.5)*2.0;
	float radius=length(p);
	ALBEDO=vec3(0.10,0.13,0.075);
	ALPHA=(1.0-smoothstep(0.22,1.0,radius))*strength;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader=shader
	return mat

func update_weather(levels: Vector3) -> void:
	if last_weather.distance_squared_to(levels)<0.000025: return
	last_weather=levels
	for mat in [water_simple,water_clear]:
		mat.set_shader_parameter("water_rain",levels.x)
		mat.set_shader_parameter("water_wind",levels.y)
		mat.set_shader_parameter("water_cloud",levels.z)
	world_materials[0].set_shader_parameter("rain_wet",levels.x)
	world_materials[0].set_shader_parameter("cloud_cover",levels.z)
	world_materials[3].set_shader_parameter("air",levels.y)
	bloom_material.set_shader_parameter("air",levels.y)
	foliage_material.set_shader_parameter("air",levels.y)
	for mat in wind_materials: mat.set_shader_parameter("air",levels.y)
	for mat in surface_materials.values(): mat.set_shader_parameter("rain_wet",levels.x)
	for original: StandardMaterial3D in wet_materials:
		var wet: StandardMaterial3D=wet_materials[original]
		wet.roughness=original.roughness*(1.-.46*levels.x)
		wet.albedo_color=original.albedo_color.darkened(.13*levels.x)

func update_contact_light(daylight: float) -> void:
	if contact_material != null:
		contact_material.set_shader_parameter("strength",lerpf(0.18,0.33,daylight)*(1.0 if quality_level>=2 else 0.65))

func update_bank_ripple(pos: Vector3,moving: float) -> void:
	var point:=Vector2(pos.x,pos.z)
	var strength:=clampf(moving,0.0,1.0)*(1.0-smoothstep(0.2,1.6,absf(shoreline.distance_at(point))))
	for mat in [water_simple,water_clear]:
		if mat: mat.set_shader_parameter("bank_actor",Vector3(point.x,point.y,strength))
