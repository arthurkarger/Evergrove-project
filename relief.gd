extends RefCounted
# Elliptical shelves in island coordinates. Each gate is a bearing in radians;
# its wide, shallow shoulder is part of the same mesh as the cliff.
const SHELVES := [
	[[Vector2(-11,-11),Vector2(21,15),.08,1.30],[Vector2(-15,-12),Vector2(11,8),-.25,2.09]],
	[[Vector2(18,-2),Vector2(13,26),-.13,2.45],[Vector2(19,-12),Vector2(8,12),.12,3.58]],
	[[Vector2(-13,-6),Vector2(22,14),.62,.40],[Vector2(-20,-12),Vector2(11,8),.45,1.40]],
	[[Vector2(13,-15),Vector2(21,12),-.16,3.05],[Vector2(18,-13),Vector2(11,7),-.25,3.84]]]
const SPRINGS := [Vector2(-20,-15),Vector2(16,-8),Vector2(-22,-14),Vector2(21,-13)]
const RISE := 3.6
const STEP := .5
const ORIGIN := Vector2(-44,-36)
const NX := 177
const NZ := 145
var layout: int
var mouth: Vector2
var source: Vector2
var route:=0.
var middle:=Vector2.ZERO
var pads: Array=[]
var pad_bins: Dictionary={}
var heights:=PackedFloat32Array()
var land_mesh: ArrayMesh
var falls: Array[Vector3]=[]

func _init(variant: int,lake: Vector2) -> void:
	layout=variant
	mouth=lake
	source=SPRINGS[layout]

func stream(t: float) -> Vector2:
	var bend: float=[3.3,-6.,-4.,4.7][layout]+route
	return source.lerp(mouth,t)+Vector2.DOWN*sin(t*PI)*(bend+1.6*sin(t*TAU+layout))

func channel(p: Vector2) -> float:
	var t:=clampf((p.x-source.x)/(mouth.x-source.x),0,1)
	var width:=1.16+.32*sin(t*PI)+.20*sin(t*TAU*2+layout)
	var pond:=((p-source)/Vector2(3.8,2.75)).length()*2.75-2.75
	var basin:=((p-middle)/Vector2(2.7,2.1)).length()*2.1-2.1
	return minf(basin,minf(pond,p.distance_to(stream(t))-width))

func boundary_depth(p: Vector2,layer: int) -> Vector2:
	var s: Array=SHELVES[layout][layer]
	var q: Vector2=(p-s[0]).rotated(-s[2])/s[1]
	var a:=q.angle()
	var edge:=1.+.095*sin(3*a+layout)+.048*cos(5*a-layer)
	var d: float=(edge-q.length())*minf(s[1].x,s[1].y)
	var angle:=absf(angle_difference(a,float(s[3])))
	var gate:=1.-smoothstep(.16,.47,angle)
	if layout==0:
		var crossing:=5.80 if layer==0 else 5.30
		gate=maxf(gate,1.-smoothstep(.16,.45,absf(angle_difference(a,crossing))))
	return Vector2(d,gate)

func ramp_point(layer: int,depth: float) -> Vector2:
	var s: Array=SHELVES[layout][layer]
	var a:=float(s[3])
	var edge:=1.+.095*sin(3*a+layout)+.048*cos(5*a-layer)
	return s[0]+(Vector2.from_angle(a)*(edge-depth/minf(s[1].x,s[1].y))*s[1]).rotated(s[2])

func side_shelf(p: Vector2,center: Vector2,size: Vector2,gate: float) -> float:
	var q:=(p-center)/size
	var a:=q.angle()
	var d:=(1.+.08*sin(3*a)-q.length())*minf(size.x,size.y)
	var width:=lerpf(.72,5.6,1.-smoothstep(.19,.50,absf(angle_difference(a,gate))))
	return RISE*smoothstep(-width,width,d)

func raw(p: Vector2) -> float:
	var h:=0.
	for layer in 2:
		var edge:=boundary_depth(p,layer)
		var width:=lerpf(.68,5.8 if layer==0 else 4.4,edge.y)
		h+=RISE*smoothstep(-width,width,edge.x)
	match layout:
		0: h=maxf(h,side_shelf(p,Vector2(4,-23),Vector2(10,5),-.5))
		2: h=maxf(h,side_shelf(p,Vector2(-23,8),Vector2(10,12),.55))
		3: h=maxf(h,side_shelf(p,Vector2(25,10),Vector2(7,9),2.0))
	return h

func pick_basin() -> void:
	var best:=INF
	for i in range(2,48):
		var p:=stream(i/50.)
		var score:=absf(raw(p)-RISE)+.12*absf(i/50.-.4)
		if score<best:
			best=score
			middle=p

func configure(saved: Dictionary,protected: Array,shore) -> void:
	if not saved.has("pads"):
		# Keep existing buildings and crops on stable foundations. Store these
		# decisions once so moving a building later cannot change the terrain.
		for bend in [0.,-6.,6.,-12.,12.]:
			route=bend
			pick_basin()
			var clear:=true
			for box: Rect2i in protected:
				for x in range(box.position.x-1,box.end.x+1):
					for z in range(box.position.y-1,box.end.y+1):
						if channel(Vector2(x,z))<1.4: clear=false
			if clear: break
		for box: Rect2i in protected:
			var h:=0.0
			var needs_pad:=false
			for x in range(box.position.x-1,box.end.x+1):
				for z in range(box.position.y-1,box.end.y+1):
					if absf(raw(Vector2(x,z))-h)>.01 or channel(Vector2(x,z))<1.4: needs_pad=true
			if needs_pad: pads.append([box.position.x,box.position.y,box.size.x,box.size.y,h])
		saved["pads"]=pads
		saved["bend"]=route
	else:
		pads=saved.pads
		route=float(saved.get("bend",0.))
		pick_basin()
	for pad in pads:
		var bounds:=Rect2i(int(pad[0]),int(pad[1]),int(pad[2]),int(pad[3])).grow(4)
		var lo:=Vector2i((Vector2(bounds.position)/8.).floor())
		var hi:=Vector2i((Vector2(bounds.end)/8.).floor())
		for z in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				var cell:=Vector2i(x,z)
				if not pad_bins.has(cell): pad_bins[cell]=[]
				pad_bins[cell].append(pad)
	heights.resize(NX*NZ)
	for z in NZ:
		for x in NX:
			var p:=ORIGIN+Vector2(x,z)*STEP
			var h:=raw(p)*smoothstep(1.4,5.4,shore.coast(p))
			for pad in pad_bins.get(Vector2i((p/8.).floor()),[]):
				var d:=pad_distance(p,pad)
				h=lerpf(float(pad[4]),h,smoothstep(.85,3.,d))
			heights[z*NX+x]=h

func pad_distance(p: Vector2,pad: Array) -> float:
	var center:=Vector2(pad[0],pad[1])+(Vector2(pad[2],pad[3])-Vector2.ONE)*.5
	return ((p-center).abs()-Vector2(pad[2],pad[3])*.5).max(Vector2.ZERO).length()

func water_distance(p: Vector2) -> float:
	var d:=channel(p)
	for pad in pad_bins.get(Vector2i((p/8.).floor()),[]):
		d=maxf(d,1.65-pad_distance(p,pad))
	return d

func height(p: Vector2) -> float:
	if heights.is_empty(): return 0.
	var uv:=(p-ORIGIN)/STEP
	var x:=floori(uv.x)
	var z:=floori(uv.y)
	if x<0 or x>=NX-1 or z<0 or z>=NZ-1: return 0.
	var i:=z*NX+x
	var u:=uv.x-x
	var v:=uv.y-z
	if u+v<=1.: return heights[i]+u*(heights[i+1]-heights[i])+v*(heights[i+NX]-heights[i])
	return heights[i+NX+1]+(1.-u)*(heights[i+NX]-heights[i+NX+1])+(1.-v)*(heights[i+1]-heights[i+NX+1])

func flat(p: Vector2) -> bool:
	var h:=height(p)
	for offset in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(-.5,.5),Vector2(.5,.5)]:
		if absf(height(p+offset)-h)>.045: return false
	return true

func build(v,material: Material) -> void:
	var pos:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uv:=PackedVector2Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	var wet:=PackedInt32Array()
	# Flat 2-unit blocks share two triangles; cliff lips and ramps retain
	# the full half-unit resolution for rendering, picking and physics.
	var coarse: Dictionary={}
	for z in range(0,NZ-1,4):
		for x in range(0,NX-1,4):
			var h:=heights[z*NX+x]
			var flat_block:=true
			for dz in range(maxi(0,z-1),mini(z+6,NZ)):
				for dx in range(maxi(0,x-1),mini(x+6,NX)):
					if absf(heights[dz*NX+dx]-h)>.00001:
						flat_block=false
						break
				if not flat_block: break
			if flat_block: coarse[Vector2i(x/4,z/4)]=true
	var tint:=Color(v.landscape.MAPS[v.landscape.id][2])
	for z in NZ:
		for x in NX:
			var p:=ORIGIN+Vector2(x,z)*STEP
			var i:=z*NX+x
			pos.append(Vector3(p.x,heights[i],p.y))
			normals.append(Vector3(heights[z*NX+maxi(0,x-1)]-heights[z*NX+mini(NX-1,x+1)],2*STEP,heights[maxi(0,z-1)*NX+x]-heights[mini(NZ-1,z+1)*NX+x]).normalized())
			uv.append((Vector2(x,z)*STEP+Vector2.ONE*.5)/Vector2(89,73))
			colors.append(tint)
			if z==NZ-1 or x==NX-1: continue
			if not coarse.has(Vector2i(x/4,z/4)):
				indices.append_array(PackedInt32Array([i,i+1,i+NX,i+1,i+NX+1,i+NX]))
			elif x%4==0 and z%4==0:
				indices.append_array(PackedInt32Array([i,i+4,i+4*NX,i+4,i+4*NX+4,i+4*NX]))
			if heights[i]+heights[i+1]+heights[i+NX]+heights[i+NX+1]>.001 and v.shoreline.inland(p)<2.:
				wet.append_array(PackedInt32Array([i,i+1,i+NX,i+1,i+NX+1,i+NX]))
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=pos
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	land_mesh=ArrayMesh.new()
	land_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var land:=MeshInstance3D.new()
	land.mesh=land_mesh
	land.material_override=material
	v.add_child(land)
	var collider:=CollisionShape3D.new()
	collider.shape=land_mesh.create_trimesh_shape()
	v.terrain.add_child(collider)
	if not wet.is_empty():
		var remap: Dictionary={}
		var water_pos:=PackedVector3Array()
		var water_normals:=PackedVector3Array()
		for i in wet.size():
			var index:=wet[i]
			if not remap.has(index):
				remap[index]=water_pos.size()
				water_pos.append(pos[index])
				water_normals.append(normals[index])
			wet[i]=remap[index]
		arrays[Mesh.ARRAY_INDEX]=wet
		arrays[Mesh.ARRAY_VERTEX]=water_pos
		arrays[Mesh.ARRAY_NORMAL]=water_normals
		arrays[Mesh.ARRAY_COLOR]=null
		arrays[Mesh.ARRAY_TEX_UV]=null
		var water:=MeshInstance3D.new()
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		water.mesh=mesh
		water.position.y=.09
		water.layers=2
		water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		v.add_child(water)
		v.water_surfaces.append(water)
		water.material_override=v.lake_material
	# Locate the downstream foot of each physical drop on this river.
	for tier in [2,1]:
		var previous:=height(source)
		for i in range(1,151):
			var p:=stream(i/150.)
			var h:=height(p)
			if previous>(tier-1)*RISE+.25 and h<=(tier-1)*RISE+.25 and water_distance(p)<0:
				falls.append(Vector3(p.x,h+.13,p.y))
				break
			previous=h
	var foam:=ShaderMaterial.new()
	foam.shader=preload("res://shaders/cascade_pool.gdshader")
	for foot in falls:
		var pool:=MeshInstance3D.new()
		var sheet:=PlaneMesh.new()
		sheet.size=Vector2(1.9,1.7)
		pool.mesh=sheet
		pool.material_override=foam
		pool.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pos2:=Vector2(foot.x+signf(mouth.x-source.x)*.65,foot.z)
		pool.position=Vector3(pos2.x,height(pos2)+.118,pos2.y)
		v.add_child(pool)
		var spray:=GPUParticles3D.new()
		spray.position=foot
		spray.lifetime=.66
		spray.preprocess=.4
		var motion:=ParticleProcessMaterial.new()
		motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
		motion.emission_box_extents=Vector3(.26,.03,.67)
		motion.direction=Vector3(signf(mouth.x-source.x)*.45,1,0)
		motion.spread=32
		motion.initial_velocity_min=1.
		motion.initial_velocity_max=2.2
		motion.gravity=Vector3(0,-4.8,0)
		spray.process_material=motion
		var drop:=SphereMesh.new()
		drop.radial_segments=5
		drop.rings=2
		drop.radius=.07
		drop.height=.09
		var white:=StandardMaterial3D.new()
		white.albedo_color=Color("cceee6")
		drop.material=white
		spray.draw_pass_1=drop
		spray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		v.add_child(spray)
		v.cascade_spray.append(spray)
