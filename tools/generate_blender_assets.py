"""Generate original, low-poly Evergrove props using Blender's Python API."""
import bpy
import math
import random
import json
import struct
import sys
from pathlib import Path
from mathutils import Vector

GAME = "--game-assets" in sys.argv
OUT = Path("assets/models/generated" if GAME else "blender-output")
OUT.mkdir(parents=True, exist_ok=True)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, rgb, seed):
    rng = random.Random(seed)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.95
    img = bpy.data.images.new(name + "_pixels", width=128, height=128, alpha=False)
    pixels = []
    for y in range(128):
        for x in range(128):
            shade = 0.96 + 0.06*rng.random() + 0.025*math.sin(x*.25+y*.14)
            if name in ("Wood", "Roof"):
                shade += .025*math.sin(x*1.7+math.sin(y*.15))
                if y % 32 < 3: shade *= .88
            if name.startswith("Leaf"):
                shade += .035*math.sin(x*.31)*math.sin(y*.26)+.025*math.cos((x+y)*.53)
            pixels.extend([min(1, c*shade) for c in rgb] + [1])
    img.pixels = pixels
    img.pack()
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat

def paint(obj, mat, name):
    obj.name = name
    obj.data.materials.append(mat)
    return obj

def box(name, loc, size, mat, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    paint(obj, mat, name)
    bevel=obj.modifiers.new("Soft handcrafted edges", "BEVEL")
    bevel.width=min(.035, min(size)*.16)
    bevel.segments=2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj

def cone(name, loc, r1, r2, depth, mat, vertices=7):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc)
    return paint(bpy.context.object, mat, name)

def rock(name, loc, size, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=loc)
    obj = bpy.context.object
    obj.scale = size
    return paint(obj, mat, name)

def srgb(hex_color):
    def linear(v): return v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4
    return tuple(linear(int(hex_color[i:i+2],16)/255) for i in (0,2,4))

def house(roof_color=(.48,.16,.12), wall_color=(.81,.66,.43)):
    wall=material("Plaster", wall_color, 1)
    wood=material("Wood", (.29,.15,.075), 2)
    roof=material("Roof", roof_color, 3)
    glass=material("Glass", (.24,.54,.58), 4)
    stone=material("Stone", (.46,.43,.38), 5)
    box("Foundation", (0,0,.13), (3.2,2.5,.26), stone)
    box("Walls", (0,0,1.13), (3,2.3,1.8), wall)
    # Roof slopes descend toward the front and back.
    for side in (-1,1):
        box("Roof slope", (0,side*.67,2.38), (3.45,1.69,.14), roof, (math.radians(-side*37),0,0))
    # Fill both triangular gables beneath the roof.
    for x in (-1.49,1.49):
        verts=[(x,-1.14,2.02),(x,1.14,2.02),(x,0,2.87)]
        mesh=bpy.data.meshes.new("Gable")
        mesh.from_pydata(verts,[],[(0,1,2) if x>0 else (2,1,0)])
        mesh.update()
        uv=mesh.uv_layers.new()
        for i,loop in enumerate(mesh.loops):
            uv.data[i].uv=[(0,0),(1,0),(.5,1)][loop.vertex_index]
        obj=bpy.data.objects.new("Gable",mesh)
        bpy.context.collection.objects.link(obj)
        paint(obj,wall,"Gable")
    for x in (-1.43,1.43):
        for y in (-1.09,1.09):
            box("Corner beam",(x,y,1.17),(.14,.14,1.86),wood)
    for z in (.27,1.98):
        box("Front beam",(0,-1.17,z),(3.03,.12,.14),wood)
    box("Door",(0,-1.2,.87),(.76,.12,1.22),wood)
    box("Doorstep",(0,-1.38,.1),(.93,.46,.20),stone)
    for x in (-.99,.99):
        box("Window frame",(x,-1.2,1.35),(.65,.13,.72),wood)
        box("Window",(x,-1.28,1.35),(.49,.045,.56),glass)
        box("Mullion",(x,-1.31,1.35),(.065,.045,.56),wood)
        box("Sill",(x,-1.32,1.06),(.72,.22,.09),wood)
    box("Chimney",(.95,.45,2.72),(.38,.42,1.0),stone)
    box("Chimney cap",(.95,.45,3.2),(.49,.52,.13),stone)

def tree(fruit=False):
    bark=material("Wood",(.35,.19,.09), 6)
    leaf1=material("Leaf",(.22,.42,.14), 7)
    leaf2=material("LeafLight",(.39,.57,.19), 8)
    cone("Trunk",(0,0,.85),.25,.14,1.7,bark,vertices=12)
    for loc,size,mat in [
        ((0,0,1.95),(.9,.78,.8),leaf1),
        ((-.42,-.12,1.65),(.64,.64,.58),leaf2),
        ((.43,.18,1.85),(.67,.56,.63),leaf1),
        ((.03,.02,2.49),(.62,.58,.64),leaf2)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1, location=loc)
        obj=bpy.context.object
        obj.scale=size
        for v in obj.data.vertices:
            p=v.co
            p *= 1+.045*math.sin(p.x*8+p.z*5)*math.cos(p.y*7)
        for poly in obj.data.polygons: poly.use_smooth=True
        paint(obj,mat,"Canopy")
    if fruit:
        apple=material("Apple",(.72,.22,.08),14)
        for loc in [(-.72,-.57,1.7),(.58,-.52,1.8),(.82,.18,1.86)]:
            rock("Fruit",loc,(.15,.15,.16),apple)
            cone("Fruit stem",(loc[0],loc[1],loc[2]+.15),.018,.013,.075,bark,vertices=8)

def pine():
    bark=material("Wood",(.35,.19,.09),16)
    cone("Trunk",(0,0,1),.33,.20,2,bark,vertices=12)
    for i, color in enumerate(["50785c","628567","769672"]):
        leaf=material("Needles"+str(i),srgb(color),20+i)
        obj=cone("Needles",(0,0,1.9+i*.76),1.45-i*.305,.075,2,leaf,vertices=24)
        for poly in obj.data.polygons:
            if len(poly.vertices)==4: poly.use_smooth=True

def character_part(kind):
    mat=material("Neutral",(.7,.7,.7),40)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=12,radius=.5)
    obj=bpy.context.object
    for vert in obj.data.vertices:
        x,y,z=vert.co
        if kind=="head":
            # Round forehead and cheeks, slightly narrower jaw.
            x *= 1+.17*z-.18*max(0,-z)*2
            y *= 1-.12*max(0,-z)*2
        elif kind=="torso":
            x *= 1+.24*z
            z=math.copysign(.5*(abs(z)*2)**.70,z)
        elif kind=="limb":
            z=math.copysign(.5*(abs(z)*2)**.72,z)
        elif kind=="shoe":
            z=max(-.31,z)
            y *= 1-.25*z
        elif kind=="hair":
            z=math.copysign(.5*(abs(z)*2)**.82,z)
            y *= 1+.07*math.cos(x*12)
        vert.co=(x,y,z)
    for axis in range(3):
        lo=min(v.co[axis] for v in obj.data.vertices)
        hi=max(v.co[axis] for v in obj.data.vertices)
        for v in obj.data.vertices: v.co[axis]=(v.co[axis]-(lo+hi)*.5)/(hi-lo)
    for poly in obj.data.polygons: poly.use_smooth=True
    paint(obj,mat,kind)

def bench():
    wood=material("Wood",(.56,.31,.13),9)
    dark=material("Support",(.23,.15,.10),10)
    for x in (-.69,.69):
        for y in (-.2,.2):
            box("Leg",(x,y,.235),(.14,.14,.47),dark)
        box("Back support",(x,.23,.67),(.12,.12,.69),dark)
    for y in (-.22,-.07,.08,.23):
        box("Seat slat",(0,y,.51),(1.72,.135,.10),wood)
    for z in (.79,1.01):
        box("Back slat",(0,.25,z),(1.72,.10,.18),wood)
    for x in (-.79,.79):
        box("Armrest",(x,0,.76),(.13,.56,.12),dark)
        box("Arm support",(x,-.19,.62),(.10,.10,.26),dark)

def export(name):
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes: o.select_set(True)
    if GAME and len(meshes)>1:
        bpy.context.view_layer.objects.active=meshes[0]
        bpy.ops.object.join()
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    path=OUT/(name+".glb")
    bpy.ops.export_scene.gltf(filepath=str(path.resolve()), export_format="GLB", use_selection=True)
    with path.open("rb") as f:
        magic, version, length=struct.unpack("<4sII",f.read(12))
        chunk_len, kind=struct.unpack("<I4s",f.read(8))
        assert magic==b"glTF" and version==2 and length==path.stat().st_size and kind==b"JSON"
        data=json.loads(f.read(chunk_len))
    assert data.get("meshes") and data.get("images"), "Missing mesh or texture"
    print(f"Validated {path}: {len(meshes)} objects, {len(data['images'])} textures")

def preview(name, target, distance):
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=64
    # Ubuntu Blender packages may be compiled without OpenImageDenoise.
    scene.cycles.use_denoising=False
    scene.render.resolution_x=640
    scene.render.resolution_y=480
    scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new("World")
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.58,.64,.73,1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value=.45
    ground=material("Ground",(.35,.42,.31),11)
    box("Preview ground",(0,0,-.075),(200,200,.1),ground)
    bpy.ops.object.camera_add(location=Vector(target)+Vector((4,-6,4.8)).normalized()*distance)
    cam=bpy.context.object
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat("-Z","Y").to_euler()
    cam.data.type="ORTHO"
    cam.data.ortho_scale=distance*.62
    scene.camera=cam
    bpy.ops.object.light_add(type="AREA",location=(1,-4,7))
    light=bpy.context.object
    light.data.energy=750
    light.data.shape="DISK"
    light.data.size=5
    light.rotation_euler=(Vector(target)-light.location).to_track_quat("-Z","Y").to_euler()
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath=str((OUT/(name+".png")).resolve())
    bpy.ops.render.render(write_still=True)

if GAME:
    palettes=[("628693","f3d1a0"),("946e57","e6cfa8"),("96778c","efd0b5"),("577453","f3da9e"),("b76349","efd2a2"),("597e80","f0d8ab"),("84905d","eac398")]
    for roof,wall in palettes:
        reset()
        house(srgb(roof),srgb(wall))
        export("house_"+roof)
    for name,build in [("tree",tree),("pine",pine),("fruit_tree",lambda:tree(True)),("bench",bench)]:
        reset()
        build()
        export(name)
    for kind in ("head","torso","limb","shoe","hair"):
        reset()
        character_part(kind)
        export("character_"+kind)
else:
    for name, build, target, distance in [
        ("house",house,(0,0,1.4),8),
        ("tree",tree,(0,0,1.45),5.8),
        ("bench",bench,(0,0,.55),4)]:
        reset()
        build()
        export(name)
        preview(name,target,distance)
